# Rationale

This document explains the design decisions behind the Dual-Mode Token Standard. All content is based on the official ERC specification.

---

## Core Philosophy

**"Privacy is a mode, not a separate token."**

Traditional approach:
```
Token A (public) + Token B (private wrapper) = 2 assets
```

This standard:
```
Token C (public mode ↔ private mode) = 1 asset
```

---

## Key Advantages

### 1. Unified Liquidity
- DEXs only need one trading pair
- No fragmentation between "public version" and "private version"
- Full liquidity available regardless of current mode

### 2. Bidirectional Flexibility
- Users can freely switch: `public → private → public → private`
- Unlike wrappers (require unwrapping to access public features)
- Unlike protocol-level (often irreversible)

### 3. Capital Efficiency
- Can convert to public mode for DeFi, back to private for holdings
- No need to maintain separate balances in both forms
- Mode conversion is internal (no external token transfers)

### 4. Simplified User Experience
- Single token address to track
- No "wrapping" concept to understand
- Mode switching feels like a native feature, not a workaround

### 5. Immediate Deployability
- Application-layer standard (no protocol changes)
- Can be deployed today on any EVM chain
- No coordination with core developers required

### 6. Regulatory Adaptability
- Transparent mode satisfies compliance requirements
- Privacy mode available when legally permitted
- Can respond to changing jurisdictional rules by adjusting mode usage

---

## Comparison with Alternatives

| Architecture | Liquidity | Capital Efficiency | User Complexity | Deployment | Reversibility |
|--------------|-----------|-------------------|-----------------|------------|---------------|
| Wrapper-based | Fragmented | Low (locked) | High (2 tokens) | Easy | ✅ Yes |
| Protocol-level | Unified | High | Low | Hard (years) | ❌ Usually no |
| **This Standard** | **Unified** | **High** | **Low (1 token)** | **Easy** | **✅ Yes** |

---

## Use Cases

### Business
- **Transparent mode**: Public accounting, investor reporting, compliance audits
- **Privacy mode**: Employee payroll, supplier payments, competitive strategy

### DAO
- **Transparent mode**: Treasury operations, public grant distributions
- **Privacy mode**: Anonymous voting, confidential negotiations

### Individual
- **Transparent mode**: DeFi participation (trading, lending, staking)
- **Privacy mode**: Personal savings, private transactions

### Regulatory Compliance
- Can comply with "right to privacy" in permissive jurisdictions
- Can satisfy "transparency requirements" in restrictive jurisdictions
- Single token adapts to different regulatory environments

---

## Critical Design Decisions

### BURN_ADDRESS Requirement for toPublic

**Problem**: When converting privacy-to-transparent, the ZK circuit enforces value conservation:

```
input_amount = output_amount
```

But we need to "convert" value from privacy mode to public mode. The circuit doesn't know that the contract will create public balance, so we must ensure the converted value doesn't remain spendable in privacy mode.

**Solution**: Force the first output to an unspendable address (BURN_ADDRESS):

```
Input:  Note A (100)
Output: Note B → BURN_ADDRESS (50)  ← Provably unspendable
        Note C → User (50, change)  ← Remains private

Contract: Creates 50 public balance for user
```

**This ensures**:
- ✅ Circuit value conservation: 100 = 50 + 50
- ✅ Security: Note B can never be spent (no private key exists)
- ✅ Supply invariant: totalSupply unchanged, just redistributed between modes

**Alternative**: A custom circuit could directly output `conversionAmount` without creating a BURN_ADDRESS note. This is more efficient but requires circuit development and trusted setup. The BURN_ADDRESS approach allows reuse of standard transfer circuits.

---

### totalPrivacySupply Tracking

**Why track separately?**

Implementations cannot compute `totalPrivacySupply` by summing unspent commitments because:
- Commitment values are encrypted (only hash is on-chain)
- Traversing the entire Merkle tree is computationally infeasible

**Solution**: Track by increment/decrement:
- `toPrivacy`: `totalPrivacySupply += amount`
- `toPublic`: `totalPrivacySupply -= amount`
- `mint`: `totalPrivacySupply += amount`
- Privacy transfers: No change (value stays in privacy mode)

**Supply invariant maintained**:
```solidity
totalSupply() = ERC20.balanceOf(all addresses) + totalPrivacySupply
```

---

### totalSupply() Semantics

**Decision**: Include both public and privacy supply

```solidity
function totalSupply() public view returns (uint256) {
    return publicSupply + totalPrivacySupply;
}
```

**Rationale**:
- Reflects actual token existence
- Mode conversion doesn't change total supply
- Maintains ERC-20 compatibility (total supply is meaningful)

**Why this matters**: During mode conversion, `totalSupply()` remains constant while `publicSupply` and `totalPrivacySupply` change inversely.

---

## Implementation Recommendations

### Why Dual-Layer Merkle Tree?

**Problem**: A single-layer Merkle tree supporting billions of commitments requires depth ~36 levels (to achieve 2³⁶ ≈ 68 billion capacity), creating severe performance bottlenecks:

- **Slow proof generation**: 3-4 seconds per transaction
- **Large circuits**: ~50,000 constraints (computational overhead)
- **Poor scalability**: Every transaction pays the cost of deep tree verification
- **Impractical for everyday use**: Multi-second delays harm user experience

**Solution**: The dual-layer architecture partitions the tree into two components:

1. **Active Subtree** (RECOMMENDED 16 levels, 65,536 capacity):
   - Stores recent commitments
   - Handles >99% of all transactions
   - Proof generation: 2-3 seconds (**2-3x faster** than single-tree equivalent)
   - Circuit constraints: ~30,000 (**-40% reduction**)
   - Optimized for frequent, low-latency operations

2. **Root Tree** (RECOMMENDED 20 levels, 1,048,576 subtrees):
   - Archives finalized subtree roots as they fill
   - Total system capacity: 2¹⁶ × 2²⁰ = **68.7 billion notes**
   - Used only for spending old notes (infrequent operation)
   - At 10 TPS: capacity lasts **200+ years**

**Rollover Mechanism**: When the active subtree reaches capacity (65,536 commitments), the current `activeSubtreeRoot` is archived into the root tree, and the active subtree resets to empty. Users can still spend old notes using finalized tree proofs (slower but practical).

**Performance Comparison**:

| Metric | Single Tree (36 levels) | Dual-Layer (Active) | Improvement |
|--------|------------------------|-------------------|-------------|
| Proof generation time | 3-4 seconds | 2-3 seconds | **2-3x faster** |
| Circuit constraints | ~50,000 | ~30,000 | **-40%** |
| Merkle proof depth | 36 siblings | 16 siblings | **-55% verification steps** |
| Total capacity | 68B notes | 68B notes | Equivalent |

**Trade-off**: Introduces three proof types (`0: active, 1: finalized, 2: rollover`) in exchange for dramatic performance improvements. This architecture has been proven in production privacy protocols and represents current best practice for scalable privacy on Ethereum.

**Important Note on Gas Costs**: On-chain gas costs remain similar (~300-400K per transaction) for both architectures, as zk-SNARK proof verification dominates (80-85% of gas). The dual-layer design optimizes **off-chain performance** (proof generation speed, client synchronization efficiency) rather than on-chain execution costs.

**Alternative Considered**: Sparse Merkle Trees (SMT) with on-chain frontier node storage were rejected due to prohibitively high storage costs and minimal performance benefits over circuit-verified Merkle proofs.

---

## Security Considerations Summary

### Supply Conservation
```solidity
// Mode conversion maintains invariant
publicSupply_before + privacySupply_before =
publicSupply_after + privacySupply_after
```

### Double-Spend Prevention
- Nullifier tracking prevents commitment reuse
- Each commitment can only be spent once
- Nullifiers are permanent (never deleted)

### Mode Conversion Integrity
- BURN_ADDRESS check ensures outputs can't be spent in both modes
- Contract MUST verify `recipientX == BURN_ADDRESS_X`
- Prevents double-spending across modes

---

## What This Standard Does NOT Solve

**Out of scope** (intentionally):
- ❌ Cross-chain privacy coordination
- ❌ Regulatory compliance frameworks
- ❌ Key management solutions
- ❌ Auditability backdoors
- ❌ Adding privacy to existing deployed tokens (use wrapper standards)

**In scope**:
- ✅ Single-token privacy/transparency switching
- ✅ Unified liquidity
- ✅ Deploy-today solution
- ✅ Full ERC-20 compatibility

---

## Terminology Evolution

**Early design** (wrapper-thinking):
- "deposit/withdraw"
- "privacy pool"
- "wrap/unwrap"

**Current standard** (dual-mode thinking):
- "toPrivacy/toPublic"
- "privacy mode"
- "mode conversion"

This terminology better reflects the core concept: **privacy is a mode, not a separate asset**.

---

For complete technical details, see [ERC_DRAFT.md](../ERC_DRAFT.md).
