# Rationale: Why Dual-Mode Token Standard?

This document explains the design decisions behind the Dual-Mode Token Standard.

---

## Core Philosophy

**"Privacy is a mode, not a separate token."**

This philosophy drives our entire design:
- **One token** - not two separate assets
- **Mode switching** - not wrapping/unwrapping
- **Unified liquidity** - not fragmented pools
- **Reversible privacy** - not one-way burns

---

## Problem Statement

### Current Landscape

**Option 1: Wrapper-Based Privacy (e.g., Tornado Cash style)**

```
Token A (public) → deposit → Token B (in pool) → withdraw → Token A
```

**Problems:**
- ❌ Two separate token addresses
- ❌ DEXs need separate liquidity pools for Token A and Token B
- ❌ Capital inefficiency: can't use Token A while holding privacy balance
- ❌ User complexity: managing two different balances
- ❌ Liquidity fragmentation: splits ecosystem

**Option 2: Protocol-Level Privacy (e.g., Zcash)**

```
Blockchain natively supports private transactions
```

**Problems:**
- ❌ Requires consensus fork (multi-year timeline)
- ❌ Often irreversible (can't go back to transparent)
- ❌ Not applicable to existing tokens
- ❌ Hard to deploy incrementally

### The Gap

Neither solution provides:
- ✅ Deploy-today privacy for existing tokens
- ✅ Reversible mode switching
- ✅ Unified liquidity
- ✅ Full ERC-20 compatibility

---

## Our Solution: Integrated Dual-Mode

### Core Concept

```
Same Token → convert mode → Same Token → convert mode → Same Token
  (Public)                    (Private)                  (Public)
```

**Key Insight:** Privacy and transparency are **modes of operation**, not separate assets.

### Design Principles

#### 1. Single Token Contract

**Decision:** One contract, one address, one `totalSupply()`

**Rationale:**
- Liquidity remains unified (same DEX pool)
- User holds same asset in both modes
- No fragmentation of ecosystem

**Trade-off:** More complex implementation vs. simpler user experience
**Choice:** User experience wins

#### 2. `totalSupply()` Semantics

**Decision:** `totalSupply() = publicSupply + privacySupply`

**Rationale:**
- Reflects actual token existence
- Supply conservation is transparent
- Mode conversion doesn't change total supply

**Alternative considered:** `totalSupply()` = public only
- **Rejected:** Would hide privacy supply, breaking transparency

#### 3. Mode Conversion Mechanism

**Decision:** Burn-and-mint pattern

**toPrivacy:**
```solidity
_burn(msg.sender, amount);        // Decrease public
_privacyMint(amount, ...);        // Increase privacy
// totalSupply unchanged
```

**Rationale:**
- Leverages standard ERC-20 functions
- Clear supply tracking
- Events emit proper Transfer(from, address(0), amount)

**Trade-off:** Uses "mint/burn" internally (implementation detail) vs. perfect terminology
**Choice:** Standard compatibility wins (see MINT_BURN_TERMINOLOGY_ANALYSIS.md)

#### 4. BURN_ADDRESS Requirement

**Decision:** toPublic MUST send first output to provably unspendable address

**Rationale:**
- Prevents double-spending attack
- Circuit doesn't know contract will mint public balance
- Must ensure privacy note can't be spent again

**Security Critical:** Without this, attacker could:
1. Call toPublic → receive public balance
2. Spend the privacy note again → double-spend

**Alternative considered:** Custom circuit that explicitly outputs conversion amount
- **Rejected:** Requires modifying privacy circuit, increases complexity

---

## Comparison with Alternatives

### vs. Wrapper-Based (e.g., ERC-8065)

| Aspect | Wrapper | Dual-Mode |
|--------|---------|-----------|
| Token addresses | 2 | 1 |
| Liquidity | Fragmented | ✅ Unified |
| Can wrap any token | ✅ Yes | No (need deployment) |
| Capital efficiency | Low | ✅ High |

**When to use wrapper:** Adding privacy to existing deployed tokens (e.g., DAI, USDC)
**When to use dual-mode:** New token deployments where privacy is core feature

### vs. Protocol-Level (e.g., EIP-7503, Zcash)

| Aspect | Protocol | Dual-Mode |
|--------|----------|-----------|
| Deployment | Years | ✅ Today |
| Requires fork | ✅ Yes | No |
| Anonymity set | Larger | Smaller |
| Reversibility | Often no | ✅ Yes |

**When to use protocol:** Maximum privacy, network-wide anonymity set
**When to use dual-mode:** Deploy-today privacy with reversible switching

---

## Key Design Decisions

### 1. Dual Merkle Tree Architecture

**Decision:** Separate Active and Finalized trees

**Rationale:**
- Active: pending commitments (can be reorganized)
- Finalized: settled commitments (immutable)
- Two-phase commit prevents front-running

**Trade-off:** Complexity vs. security
**Choice:** Security wins

### 2. Privacy Transfer Proof Types

**Decision:** Three proof types (Active, Finalized, Rollover)

**Rationale:**
- Active: Fast transfers (pending state)
- Finalized: Settled transfers (immutable)
- Rollover: Move Active → Finalized

**Alternative considered:** Single proof type
- **Rejected:** Doesn't prevent front-running attacks

### 3. Backward Compatibility Aliases

**Decision:** Keep `shield()` and `unshield()` as aliases

**Rationale:**
- Helps migration from wrapper-thinking
- Existing tools may use these names
- No cost (simple delegation)

**Alternative considered:** Only `toPrivacy()`/`toPublic()`
- **Rejected:** May break existing integrations

### 4. Fee Mechanism

**Decision:** Optional protocol fee on toPublic

**Rationale:**
- Allows sustainable protocol development
- Only on privacy→public (not on holding)
- Configurable (can be 0)

**Trade-off:** Added complexity vs. sustainability
**Choice:** Let implementations decide

---

## What We're NOT Trying to Solve

**Clear scope boundaries:**

❌ **Cross-chain privacy:** Not in scope (use bridges)
❌ **Regulatory compliance:** Implementation choice
❌ **Key management:** User/wallet responsibility
❌ **Auditability backdoors:** Not our decision
❌ **Wrapping existing tokens:** Use wrapper standards instead

✅ **What we DO solve:**
- Single-token privacy/transparency switching
- Unified liquidity
- Deploy-today solution
- Full ERC-20 compatibility

---

## Open Questions for Community

1. **Naming:** Is "Dual-Mode" the best term?
   - Alternatives: "Convertible Privacy Token", "Hybrid Token"

2. **totalSupply() semantics:** Should privacy supply be included?
   - Current: Yes (reflects actual existence)
   - Alternative: No (strict ERC-20 interpretation)

3. **Mandatory vs. Optional fees:** Should standard enforce or suggest?
   - Current: Optional (implementation choice)
   - Alternative: Mandatory standardization

4. **Circuit complexity:** Can we simplify the dual-tree design?
   - Trade-off: Simplicity vs. Security

5. **Gas costs:** ~250K gas for proof verification acceptable?
   - Alternative: Optimize circuits further?

---

## Evolution from Earlier Designs

### v1.0 (Wrapper-thinking)
- Separate "privacy pool"
- "Deposit/withdraw" terminology
- Two logical tokens

### v2.0 (Dual-mode thinking) ✅ Current
- Single token, dual modes
- "Convert mode" terminology
- Unified liquidity

**Key insight:** Terminology matters! Changed from wrapper language to mode-switching language for conceptual clarity.

---

## Conclusion

This standard fills a gap between:
- **Too simple:** Wrapper approaches (fragmented liquidity)
- **Too hard:** Protocol-level changes (multi-year deployment)

**Sweet spot:** Deploy-today privacy with unified liquidity for new tokens.

**Philosophy:** Privacy should be an operational mode, not a separate asset class.
