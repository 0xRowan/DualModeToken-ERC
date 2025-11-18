---
eip: TBD
title: Dual-Mode Fungible Token Standard
description: A token standard supporting both transparent (ERC-20) and privacy-preserving (zk-SNARK) modes with seamless conversion
author: Rowan (@0xRowan)
discussions-to: https://ethereum-magicians.org/t/draft-dual-mode-token-standard-single-token-with-public-and-private-modes/26592
status: Draft
type: Standards Track
category: ERC
created: 2025-11-15
requires: 20, 165
---

## Abstract

This EIP defines a standard interface for fungible tokens that operate in two modes: transparent mode (fully compatible with ERC-20) and privacy mode (using zero-knowledge proofs). Token holders can convert balances between modes. The transparent mode uses standard account-based balances, while the privacy mode uses cryptographic commitments stored in a Merkle tree. Total supply is maintained as the sum of both modes.

## Motivation

### The Privacy Dilemma for New Token Projects

When launching a new token, projects face a fundamental choice:

1. **Standard ERC-20**: Full DeFi composability but zero privacy
2. **Pure privacy protocols**: Strong privacy but limited ecosystem integration

This creates real-world problems:
- **DAOs** need public treasury transparency but want anonymous governance voting
- **Businesses** require auditable accounting but need private payroll transactions
- **Users** want DeFi participation but need privacy for personal holdings

Existing solutions require trade-offs that limit adoption.

### Current Approaches and Their Limitations

#### 1. Wrapper-Based Privacy (e.g., Tornado Cash, Privacy Pools)

**Mechanism**: Wrap existing tokens (DAI, ETH) into a privacy pool contract.

```
DAI (public) → deposit → Privacy Pool → withdraw → DAI (public)
```

**Strengths**:
- ✅ Works with any existing ERC-20 token
- ✅ Permissionless deployment
- ✅ No changes to underlying token required

**Limitations for New Token Projects**:
- ❌ Creates two separate tokens (Token A vs. Wrapped Token B)
- ❌ Splits liquidity between public and wrapped versions
- ❌ Requires managing two separate contract addresses
- ❌ Users must unwrap to access DeFi (additional friction)

**Best suited for**: Adding privacy to existing deployed tokens (DAI, USDC, etc.)


### Our Approach: Integrated Dual-Mode for New Tokens

This standard provides a alternative option specifically designed for **new token deployments** that want privacy as a core feature from day one.

**Target Use Case**: Projects launching new tokens (governance tokens, protocol tokens, app tokens) that need both DeFi integration and optional privacy.

**Mechanism**:
```
Single Token Contract
  ↓
Public Mode (ERC-20) ←→ Privacy Mode (ZK-SNARK)
  ↓                           ↓
DeFi/DEX Trading          Private Holdings
```

**Key Advantages**:

1. **Unified Token Economics**
   - No liquidity split between public/private versions
   - One token address, one market price
   - Simplified token distribution and airdrops

2. **Seamless Mode Switching**
   - Convert to privacy mode for holdings: `toPrivacy()`
   - Convert to public mode for DeFi: `toPublic()`
   - Users choose privacy per transaction, not per token

3. **Full ERC-20 Compatibility**
   - Works with existing wallets, DEXs, and DeFi protocols
   - No special support needed for public mode operations
   - Standard `totalSupply()` accounting: public + private

4. **Transparent Supply Tracking**
   - `totalSupply() = totalPublicSupply() + totalPrivacySupply()`
   - Prevents hidden inflation
   - Regulatory visibility into aggregate metrics

5. **Application-Layer Deployment**
   - Deploy today on any EVM chain (Ethereum, L2s, sidechains)
   - No protocol changes or governance votes required
   - No coordination with core developers needed

### Honest Limitations

This standard is **not** a universal solution. Key constraints:

1. **New Tokens Only**
   - Designed for new token deployments with privacy built-in
   - Cannot add privacy to existing tokens (use wrapper-based solutions for that)

2. **Privacy-to-DeFi Requires Conversion**
   - Privacy mode balances cannot directly interact with DEXs/DeFi
   - Users must `toPublic()` before DeFi operations (similar to unwrapping)
   - Conversion reveals amounts on-chain (privacy-to-public events)

### When to Use This Standard

| Scenario | Recommended Approach |
|----------|---------------------|
| Adding privacy to DAI, USDC, WETH | ❌ Use wrapper-based (this won't work) |
| Launching new governance/protocol token | ✅ **This standard** |
| Maximum privacy for existing assets | ❌ Use established privacy pools |
| DAO treasury with selective privacy | ✅ **This standard** |
| Privacy for entire blockchain | ❌ Protocol-level solution |
| Privacy-first DeFi protocol token | ✅ **This standard** |

### Real-World Use Cases

**1. DAO Governance Token**
```
Public Mode:
  - Treasury management (transparent)
  - Grant distributions (auditable)
  - DEX trading (liquidity)

Privacy Mode:
  - Anonymous voting (no vote buying)
  - Private delegation (confidential strategy)
  - Personal holdings (no public scrutiny)
```

**2. Privacy-Aware Business Token**
```
Public Mode:
  - Investor reporting (compliance)
  - Exchange listings (liquidity)
  - Public fundraising (transparency)

Privacy Mode:
  - Employee compensation (confidential)
  - Supplier payments (competitive advantage)
  - Strategic reserves (private holdings)
```

**3. Protocol Token with Optional Privacy**
```
Public Mode:
  - Staking (DeFi integration)
  - Liquidity provision (AMM pools)
  - Trading (price discovery)

Privacy Mode:
  - Long-term holdings (privacy)
  - Over-the-counter transfers (confidential)
  - Strategic positions (no front-running)
```

### Design Philosophy

This standard embraces a core principle: **"Privacy is a mode, not a separate token."**

Rather than forcing users to choose between incompatible assets (Token A vs. Privacy Token B), we enable contextual privacy within a single fungible token. Users select the appropriate mode for each use case, maintaining capital efficiency and unified liquidity.

This approach acknowledges that privacy and composability serve different purposes, and most users need both at different times—not a forced choice between them.

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 and RFC 8174.

### Definitions

- **Transparent Mode**: Token balance stored in a standard `mapping(address => uint256)` accessible via ERC-20 functions
- **Privacy Mode**: Token value encoded in cryptographic commitments within a Merkle tree
- **Commitment**: A cryptographic hash binding a value and owner's public key: `Hash(stealthPublicKey, amount, salt)`
- **Nullifier**: A unique identifier proving a commitment is spent: `Hash(commitment, privateKey)`
- **Mode Conversion**: The process of moving value between transparent and privacy modes
- **BURN_ADDRESS**: A provably unspendable elliptic curve point used to ensure privacy-to-transparent conversions are secure

### Interface

```solidity
// SPDX-License-Identifier: CC0-1.0
pragma solidity ^0.8.0;

interface IERC_DUAL_MODE {

    /// @notice Emitted when value is converted from transparent to privacy mode
    /// @param account The address converting tokens
    /// @param amount The amount converted
    /// @param commitment The cryptographic commitment created
    /// @param timestamp Block timestamp of the conversion
    event ConvertToPrivacy(
        address indexed account,
        uint256 amount,
        bytes32 indexed commitment,
        uint256 timestamp
    );

    /// @notice Emitted when value is converted from privacy to transparent mode
    /// @param initiator The address initiating the conversion
    /// @param recipient The address receiving tokens
    /// @param amount The amount converted
    /// @param timestamp Block timestamp of the conversion
    event ConvertToPublic(
        address indexed initiator,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Emitted when a commitment is appended to the Merkle tree
    /// @param subtreeIndex The subtree index
    /// @param commitment The commitment hash
    /// @param leafIndex The leaf position within the subtree
    /// @param timestamp Block timestamp of the commitment
    event CommitmentAppended(
        uint32 indexed subtreeIndex,
        bytes32 indexed commitment,
        uint32 leafIndex,
        uint256 timestamp
    );

    /// @notice Emitted when a nullifier is marked as spent
    /// @param nullifier The nullifier hash
    event NullifierSpent(bytes32 indexed nullifier);

    /// @notice Emitted for privacy mode transfers
    /// @param commitments Array of new commitments
    /// @param encryptedNotes Encrypted note data for recipients
    /// @param ephemeralPublicKey Ephemeral key for note decryption
    /// @param viewTag Single-byte filter for efficient scanning
    event PrivacyTransfer(
        bytes32[2] commitments,
        bytes[] encryptedNotes,
        uint256[2] ephemeralPublicKey,
        uint256 viewTag
    );

    /// @notice Convert transparent balance to privacy mode
    /// @param amount The amount to convert
    /// @param proofType Proof type: 0 for regular mint, 1 for rollover mint
    /// @param proof ZK-SNARK proof of valid commitment creation
    /// @param encryptedNote Encrypted note data for recipient wallet
    /// @dev MUST verify caller has sufficient transparent balance
    /// @dev MUST decrease caller's transparent balance by `amount`
    /// @dev MUST decrease `totalPublicSupply()` by `amount`
    /// @dev MUST verify ZK proof validity using ProveMint circuit
    /// @dev MUST add commitment to Merkle tree
    /// @dev MUST increase `totalPrivacySupply()` by `amount`
    /// @dev MUST emit ConvertToPrivacy and CommitmentAppended events
    /// @dev MUST maintain invariant: totalSupply() == totalPublicSupply() + totalPrivacySupply()
    function toPrivacy(
        uint256 amount,
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external;

    /// @notice Convert privacy balance to transparent mode
    /// @param recipient The address to receive the transparent tokens
    /// @param proofType Proof type: 0 (active tree) or 1 (finalized tree)
    /// @param proof ZK-SNARK proof of note ownership and spending
    /// @param encryptedNotes Encrypted notes for change outputs (if any)
    /// @dev MUST verify ZK proof using ProveActiveTransfer or ProveFinalizedTransfer circuit
    /// @dev MUST verify the first output is sent to BURN_ADDRESS (see Security Considerations)
    /// @dev MUST verify nullifiers are not already spent
    /// @dev MUST mark nullifiers as spent
    /// @dev MUST add output commitments to Merkle tree
    /// @dev MUST decrease `totalPrivacySupply()` by conversion amount
    /// @dev MUST increase recipient's transparent balance by conversion amount
    /// @dev MUST increase `totalPublicSupply()` by conversion amount
    /// @dev MUST emit ConvertToPublic, NullifierSpent, and CommitmentAppended events
    /// @dev MUST maintain invariant: totalSupply() == totalPublicSupply() + totalPrivacySupply()
    function toPublic(
        address recipient,
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external;

    /// @notice Execute a privacy-preserving transfer
    /// @param proofType Proof type: 0 (active), 1 (finalized), 2 (rollover)
    /// @param proof ZK-SNARK proof of valid transfer
    /// @param encryptedNotes Encrypted notes for recipients
    /// @dev MUST verify ZK proof using appropriate circuit based on proofType
    /// @dev MUST verify nullifiers are not already spent
    /// @dev MUST mark input nullifiers as spent
    /// @dev MUST add output commitments to Merkle tree
    /// @dev MUST emit PrivacyTransfer, NullifierSpent, and CommitmentAppended events
    /// @dev MUST NOT change totalPrivacySupply() (value conservation within privacy mode)
    function privacyTransfer(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external;

    /// @notice Get transparent balance of an account
    /// @param account The address to query
    /// @return The transparent mode balance
    function publicBalanceOf(address account) external view returns (uint256);

    /// @notice Get total supply in transparent mode
    /// @return Total transparent supply
    function totalPublicSupply() external view returns (uint256);

    /// @notice Get total supply in privacy mode
    /// @return Total privacy supply tracked by increments/decrements (not computed from tree)
    function totalPrivacySupply() external view returns (uint256);

    /// @notice Get current active Merkle tree root
    /// @return Active subtree root hash
    function activeSubtreeRoot() external view returns (bytes32);

    /// @notice Get finalized Merkle tree root
    /// @return Root tree root hash
    function finalizedRoot() external view returns (bytes32);

    /// @notice Check if a nullifier has been spent
    /// @param nullifier The nullifier hash to check
    /// @return True if spent, false otherwise
    function isNullifierSpent(bytes32 nullifier) external view returns (bool);

    /// @notice Get the BURN_ADDRESS coordinates (Baby Jubjub curve point)
    /// @return x The x-coordinate of the burn address
    /// @return y The y-coordinate of the burn address
    function getBurnAddress() external view returns (uint256 x, uint256 y);
}
```

### ERC-20 Compatibility

Implementations MUST implement the ERC-20 interface. All ERC-20 functions operate exclusively on transparent mode balances:

- `balanceOf(account)` MUST return the transparent balance (equivalent to `publicBalanceOf(account)`)
- `transfer(to, amount)` MUST transfer transparent balance only
- `approve(spender, amount)` MUST approve transparent balance spending
- `transferFrom(from, to, amount)` MUST transfer transparent balance with allowance
- `totalSupply()` MUST return `totalPublicSupply() + totalPrivacySupply()`

Implementations MUST emit standard ERC-20 `Transfer` events for transparent mode operations.

### Supply Invariant

Implementations MUST maintain the following invariant at all times:

```solidity
totalSupply() == totalPublicSupply() + totalPrivacySupply()
```

Where:
- `totalSupply()`: Inherited from ERC-20, represents total token supply
- `totalPublicSupply()`: Sum of all transparent balances (tracked via `_publicBalances` mapping)
- `totalPrivacySupply()`: Tracked by incrementing on `toPrivacy`/mint and decrementing on `toPublic` (NOT computed from Merkle tree commitments, as commitment values are encrypted)

### Privacy Guarantees

#### Hidden Information

Privacy mode operations MUST NOT reveal on-chain:
- Transaction amounts (except when converting modes via `toPrivacy`/`toPublic`)
- Sender identity (except when converting to privacy mode via `toPrivacy`)
- Recipient identity in privacy transfers
- Individual commitment values (commitments are cryptographically opaque hashes)

#### Public Information

The following information is publicly visible:
- Commitment hashes (cryptographically opaque, reveal no value)
- Nullifier hashes (cryptographically opaque, only prevent double-spending)
- Merkle tree roots (cryptographic state commitments)
- `totalPrivacySupply()` (aggregate only, no per-user breakdown)
- Conversion event amounts in `ConvertToPrivacy` and `ConvertToPublic` events

### Zero-Knowledge Proof Requirements

#### Proof System

Implementations SHOULD use Groth16 zk-SNARKs with:
- **Curve**: BN254 (alt_bn128)
- **Hash Function**: Poseidon (ZK-friendly)
- **Encryption Curve**: Baby Jubjub

#### toPrivacy Circuit (ProveMint)

**Circuit Template**: `ProveMint(subtreeLevels)`

**Private Inputs**:
- `stealthPublicKey[2]`: Recipient's Baby Jubjub public key
- `salt`: Random value for commitment uniqueness
- `leafIndex`: Position in Merkle tree for insertion
- `insertionPathElements[subtreeLevels]`: Merkle path for insertion

**Public Inputs/Outputs**:
```solidity
public [
    oldActiveRoot,    // Current Merkle root before insertion
    newCommitment,    // The commitment being created
    mintAmount        // Amount being converted (matches function parameter)
]
```

**Circuit Output** (computed internally, becomes public signal):
```solidity
newActiveRoot  // New Merkle root after insertion
```

**Constraints**:
1. `newCommitment == Poseidon(stealthPublicKey[0], mintAmount, salt)`
2. Insertion position at `leafIndex` is currently empty (value 0)
3. `newActiveRoot` is correctly computed from inserting `newCommitment` at `leafIndex`
4. `mintAmount > 0` and fits in 100 bits
5. `stealthPublicKey` is a valid Baby Jubjub curve point
6. `salt != 0` and fits in 254 bits

**Solidity Proof Decoding**:
```solidity
(uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[4] memory pubSignals) =
    abi.decode(proof, (uint[2], uint[2][2], uint[2], uint[4]));

bytes32 newActiveRoot = bytes32(pubSignals[0]);
bytes32 oldActiveRoot = bytes32(pubSignals[1]);
bytes32 newCommitment = bytes32(pubSignals[2]);
uint256 mintAmount = pubSignals[3];
```

#### toPublic Circuit (ProveActiveTransfer with BURN_ADDRESS)

**Circuit Template**: `ProveActiveTransfer(subtreeLevels)`

**Private Inputs**:
- `inCommitment[2]`: Input commitments being spent
- `inAmount[2]`: Input note amounts
- `inStealthPublicKey[2][2]`: Input note owners
- `inSalt[2]`: Input note salts
- `inStealthPrivateKey[2]`: Private keys to compute nullifiers
- `inPathElements[2][subtreeLevels]`: Merkle paths for inputs
- `inLeafIndex[2]`: Input positions in tree
- `senderSpendPublicKey[2]`: Sender's public key (for change verification)
- `outAmount[2]`: Output amounts (first to BURN_ADDRESS, second for change)
- `outStealthPublicKey[2][2]`: Output recipients
- `outSalt[2]`: Output salts
- `nextLeafIndex`: Next available leaf position
- `insertionPathElements1[subtreeLevels]`: Path for first output
- `insertionPathElements2[subtreeLevels]`: Path for second output
- `ephemeralPrivateKey`: For stealth address generation
- `recipientScanPublicKey[2]`: Recipient's scan key
- `isModeConversion`: Set to 1 for toPublic operation (mode conversion)

**Public Inputs/Outputs**:
```solidity
public [
    oldActiveRoot,                  // Merkle root before operation
    nullifiers[2],                  // Nullifiers of spent notes
    commitments[2],                 // New output commitments
    recipientStealthPublicKey[2],   // First output recipient (MUST be BURN_ADDRESS for toPublic)
    viewTag                         // For efficient scanning
]
```

**Circuit Outputs** (computed internally):
```solidity
ephemeralPublicKey[2]  // For note encryption
newActiveRoot          // New Merkle root
numRealOutputs         // Number of actual outputs (1 or 2)
conversionAmount       // Amount being converted to public mode (only if isModeConversion=1)
```

**Constraints**:
1. Input commitments exist in Merkle tree at specified positions
2. Nullifiers correctly computed: `nullifier[i] == Poseidon(inCommitment[i], inStealthPrivateKey[i])`
3. Private keys match public keys: `inStealthPublicKey[i] == derive(inStealthPrivateKey[i])`
4. Input commitments correctly formed: `inCommitment[i] == Poseidon(inStealthPublicKey[i], inAmount[i], inSalt[i])`
5. Output commitments correctly formed: `commitments[i] == Poseidon(outStealthPublicKey[i], outAmount[i], outSalt[i])`
6. Value conservation: `sum(inAmount) == sum(outAmount)`
7. `conversionAmount = isModeConversion ? outAmount[0] : 0`
8. First output goes to `recipientStealthPublicKey`
9. Second output (if exists) goes back to sender
10. Merkle root correctly updated with new commitments

**Solidity Proof Decoding**:
```solidity
(uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[13] memory pubSignals) =
    abi.decode(proof, (uint[2], uint[2][2], uint[2], uint[13]));

uint256[2] memory ephemeralPublicKey = [pubSignals[0], pubSignals[1]];
bytes32 newActiveRoot = bytes32(pubSignals[2]);
uint256 numRealOutputs = pubSignals[3];
uint256 conversionAmount = pubSignals[4];  // Amount being converted to public mode
bytes32 oldActiveRoot = bytes32(pubSignals[5]);
bytes32 nullifier0 = bytes32(pubSignals[6]);
bytes32 nullifier1 = bytes32(pubSignals[7]);
bytes32 commitment0 = bytes32(pubSignals[8]);
bytes32 commitment1 = bytes32(pubSignals[9]);
uint256 recipientX = pubSignals[10];  // MUST verify == BURN_ADDRESS_X
uint256 recipientY = pubSignals[11];  // MUST verify == BURN_ADDRESS_Y
uint256 viewTag = pubSignals[12];
```

**Critical Security Requirement**:
```solidity
// Contract MUST verify first output sent to BURN_ADDRESS
require(recipientX == BURN_ADDRESS_X, "First output must be burned");
require(recipientY == BURN_ADDRESS_Y, "First output must be burned");
```

#### privacyTransfer Circuit (ProveActiveTransfer)

Uses the same `ProveActiveTransfer` circuit as `toPublic`, but with `isModeConversion = 0`:

**Key Differences**:
- `conversionAmount` will be 0 (no mode conversion)
- `recipientStealthPublicKey` is the actual recipient (not BURN_ADDRESS)
- Contract does NOT verify BURN_ADDRESS constraint

**Solidity Usage**:
```solidity
// Same decoding as toPublic
uint256 conversionAmount = pubSignals[4];
require(conversionAmount == 0, "No conversion in privacy transfer");
// recipientStealthPublicKey is the actual transfer recipient
```

### BURN_ADDRESS Specification

The BURN_ADDRESS is a Baby Jubjub elliptic curve point that MUST be generated using a verifiable "nothing-up-my-sleeve" process:

**Generation Process**:
1. Seed string: `"zkCoreVerity.burn.address.v1"` (or implementation-specific)
2. Hash: `h = Poseidon(seed)`
3. Hash-to-curve: `(BURN_ADDRESS_X, BURN_ADDRESS_Y) = HashToCurve_BabyJubJub(h)`

**Security Properties**:
- MUST be a valid point on the Baby Jubjub curve
- MUST NOT be the point at infinity
- Private key MUST be computationally infeasible to derive
- Generation process MUST be publicly documented and verifiable

**Contract Storage**:
```solidity
uint256 public constant BURN_ADDRESS_X = <derived_value>;
uint256 public constant BURN_ADDRESS_Y = <derived_value>;
```

Implementations MUST provide:
1. Documentation of the exact seed string used
2. Verification script to reproduce the hash-to-curve process
3. Independent verification by multiple parties

### Merkle Tree Structure

Implementations SHOULD use a dual-layer Merkle tree architecture:

**Active Subtree**:
- Height: RECOMMENDED 16 levels (65,536 leaves)
- Purpose: Store recent commitments
- Used for: Low-cost proof generation

**Root Tree**:
- Height: RECOMMENDED 20 levels (1,048,576 subtrees)
- Purpose: Archive finalized subtree roots
- Total capacity: ~68 billion commitments

**Rollover Mechanism**:
When active subtree reaches capacity:
1. Archive current `activeSubtreeRoot` into root tree
2. Reset active subtree to empty
3. Increment subtree index
4. Future transactions can still spend old notes using finalized tree proofs

### Note Encryption

Implementations MUST encrypt commitment metadata using:

**Encryption Scheme**:
- ECDH key exchange on Baby Jubjub curve
- Authenticated encryption (e.g., AES-GCM)
- Semantic security (ciphertexts indistinguishable from random)

**Stealth Addresses**:
- Sender generates ephemeral keypair
- Derives shared secret: `sharedSecret = ephemeralPrivateKey * recipientScanPublicKey`
- Derives one-time stealth public key for recipient
- Only recipient can detect and decrypt using their private scan key

**View Tags**:
- Single-byte identifier: `viewTag = Hash(sharedSecret) mod 256`
- Recipients filter transactions by view tag before attempting decryption
- Reduces scanning cost by ~256x

## Rationale

### Design Philosophy: Integrated Dual-Mode Architecture

This standard is built on the principle that **privacy is a mode, not a separate token**. Unlike approaches that create distinct assets for public and private usage, this design embeds both capabilities within a single fungible token.

### Alternative Architectural Approaches

#### Wrapper-Based Architecture

**Design**: Create a separate privacy-preserving wrapper contract that holds underlying ERC-20 tokens.

**Characteristics**:
- Users hold two distinct tokens: original (public) and wrapped (private)
- Wrapping: `Token A → Token B (privacy wrapper)`
- Unwrapping: `Token B → Token A`

**Trade-offs**:
- ✅ Can add privacy to any existing token without redeployment
- ✅ Preserves original token's properties and governance
- ❌ **Liquidity fragmentation**: DEXs require separate pools for Token A and Token B
- ❌ **Capital inefficiency**: Cannot use Token A while holding Token B (funds locked in wrapper)
- ❌ **User complexity**: Must manage two token balances and understand wrapping mechanics
- ❌ **Higher gas costs**: Wrapping/unwrapping involves cross-contract transfers

#### Protocol-Level Privacy

**Design**: Modify the blockchain protocol itself to support native privacy features.

**Characteristics**:
- Privacy built into the base layer (consensus rules)
- All network participants must upgrade
- Often irreversible (no "public mode" exists)

**Trade-offs**:
- ✅ Maximum privacy set (all network users)
- ✅ Strongest cryptographic guarantees
- ✅ No additional contract interaction needed
- ❌ **Deployment timeline**: Requires consensus fork (multi-year coordination)
- ❌ **Irreversibility**: Typically one-way (cannot convert back to transparent)
- ❌ **Regulatory risk**: Protocol-level privacy faces higher jurisdictional scrutiny
- ❌ **Coordination overhead**: Requires agreement from core developers and node operators

### Why Integrated Dual-Mode Architecture?

This standard combines the best aspects of both approaches while avoiding their primary limitations:

**Single Token, Dual Capability**:
```
Traditional: Token A (public) + Token B (private wrapper) = 2 assets
This Standard: Token C (public mode ↔ private mode) = 1 asset
```

**Key Advantages**:

1. **Unified Liquidity**
   - DEXs only need one trading pair
   - No fragmentation between "public version" and "private version"
   - Full liquidity available regardless of current mode

2. **Bidirectional Flexibility**
   - Users can freely switch: `public → private → public → private`
   - Unlike wrappers (require unwrapping to access public features)
   - Unlike protocol-level (often irreversible)

3. **Capital Efficiency**
   - Can convert to public mode for DeFi, back to private for holdings
   - No need to maintain separate balances in both forms
   - Mode conversion is internal (no external token transfers)

4. **Simplified User Experience**
   - Single token address to track
   - No "wrapping" concept to understand
   - Mode switching feels like a native feature, not a workaround

5. **Immediate Deployability**
   - Application-layer standard (no protocol changes)
   - Can be deployed today on any EVM chain
   - No coordination with core developers required

6. **Regulatory Adaptability**
   - Transparent mode satisfies compliance requirements
   - Privacy mode available when legally permitted
   - Can respond to changing jurisdictional rules by adjusting mode usage

**Comparison Table**:

| Architecture | Liquidity | Capital Efficiency | User Complexity | Deployment | Reversibility |
|--------------|-----------|-------------------|-----------------|------------|---------------|
| Wrapper-based | Fragmented | Low (locked) | High (2 tokens) | Easy | ✅ Yes |
| Protocol-level | Unified | High | Low | Hard (years) | ❌ Usually no |
| **This Standard** | **Unified** | **High** | **Low (1 token)** | **Easy** | **✅ Yes** |

### Why Dual-Mode Serves Real-World Needs

**Business Use Case**:
- Transparent mode: Public accounting, investor reporting, compliance audits
- Privacy mode: Employee payroll, supplier payments, competitive strategy

**DAO Use Case**:
- Transparent mode: Treasury operations, public grant distributions
- Privacy mode: Anonymous voting, confidential negotiations

**Individual Use Case**:
- Transparent mode: DeFi participation (trading, lending, staking)
- Privacy mode: Personal savings, private transactions

**Regulatory Use Case**:
- Can comply with "right to privacy" in permissive jurisdictions
- Can satisfy "transparency requirements" in restrictive jurisdictions
- Single token adapts to different regulatory environments

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

This ensures:
- ✅ Circuit value conservation: 100 = 50 + 50
- ✅ Security: Note B can never be spent (no private key exists)
- ✅ Supply invariant: totalSupply unchanged, just redistributed between modes

**Alternative Approach**: A custom circuit could directly output `conversionAmount` without creating a BURN_ADDRESS note. This is more efficient but requires circuit development and trusted setup. The BURN_ADDRESS approach allows reuse of standard transfer circuits.

### Why Track totalPrivacySupply Separately?

Implementations cannot compute `totalPrivacySupply` by summing unspent commitments because:
- Commitment values are encrypted (only hash is on-chain)
- Traversing the entire Merkle tree is computationally infeasible

Instead, track by increment/decrement:
- `toPrivacy`: `totalPrivacySupply += amount`
- `toPublic`: `totalPrivacySupply -= amount`
- `privacyTransfer`: No change (value stays in privacy mode)

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

## Backwards Compatibility

This standard is fully backward compatible with ERC-20:

- All ERC-20 functions operate on transparent balances
- All standard ERC-20 events are emitted
- Existing DeFi protocols work without modification
- Privacy mode is additive and optional

## Reference Implementation

See [contracts/DualModeToken.sol](../contracts/DualModeToken.sol) for a complete reference implementation.

**Key Components**:
1. `DualModeToken.sol`: Main contract implementing this standard
2. `ProveMint.circom`: Circuit for toPrivacy operations
3. `ProveActiveTransfer.circom`: Circuit for toPublic and privacyTransfer
4. Verifier contracts: Groth16 proof verification
5. Client libraries: Proof generation, note encryption, tree synchronization

## Security Considerations

### Critical: toPublic Conversion Mechanism

**Attack Vector**: If the contract does not verify BURN_ADDRESS, an attacker can:

```
1. Hold Note A (100 privacy balance)
2. Call toPublic(50) with proof sending output to attacker's own privacy address
3. If contract skips BURN_ADDRESS check:
   - Attacker receives 50 public balance (converted from privacy mode)
   - Note B (50) sent to attacker's privacy address ← Still spendable in privacy mode!
   - Note C (50 change)
   Result: 50 + 50 + 50 = 150 (created 50 out of thin air!)
```

**Mitigation**: Contract MUST verify:
```solidity
require(recipientX == BURN_ADDRESS_X && recipientY == BURN_ADDRESS_Y,
        "toPublic: first output must be burned");
```

This is not optional—it's a critical security requirement.

### Double-Spending Prevention

**Transparent Mode**: Standard ERC-20 balance checking prevents double-spending.

**Privacy Mode**: Nullifier uniqueness enforced on-chain:
```solidity
require(!nullifiers[nullifier], "Nullifier already spent");
nullifiers[nullifier] = true;
```

Each commitment can only be spent once, as nullifiers are deterministically derived from commitments and private keys.

### Supply Inflation

**Attack**: Malicious proof claiming incorrect values.

**Mitigation**: ZK circuits enforce value conservation. Verifier contracts validate proofs on-chain before state changes. The invariant `totalSupply() == totalPublicSupply() + totalPrivacySupply()` must hold after every operation.

### Front-Running

**Risk**: Mode conversion transactions reveal amounts in mempool.

**Mitigations**:
- Users can batch multiple conversions
- Use privacy mode exclusively for sensitive operations
- Future: Confidential conversion amounts (requires circuit changes)

### Privacy Limitations

#### Timing Analysis
Transactions reveal timing. Correlation attacks may link transparent-to-privacy conversions with subsequent privacy transactions.

**Mitigation**: Wait random intervals between conversions and subsequent operations.

#### Amount Correlation
`toPrivacy` and `toPublic` events reveal exact amounts. Unique amounts (e.g., 123.456789) can fingerprint users.

**Mitigation**: Use round amounts or split conversions.

#### Anonymity Set
Privacy guarantees depend on the number of active privacy mode users.

**Mitigation**: Encourage adoption, potentially implement decoy transactions.

#### Metadata Leakage
On-chain metadata (gas price, nonce, timestamp) can leak information.

**Mitigation**: Use privacy-preserving transaction relayers or account abstraction.

### Trusted Setup Risks

Groth16 requires a trusted setup. If setup participants collude and preserve "toxic waste," they could generate false proofs.

**Mitigations**:
- Multi-party computation (MPC) ceremonies with diverse participants
- Publish ceremony transcripts for verification
- Future: Migrate to universal setup schemes (PLONK, STARKs)

### BURN_ADDRESS Security

**Risk**: If BURN_ADDRESS private key is known, attacker could spend "burned" notes.

**Mitigation**:
- Generate via publicly verifiable hash-to-curve
- Multiple independent parties verify generation
- Use "nothing-up-my-sleeve" seed string
- Hash-to-curve guarantees no known discrete log

### Denial of Service

**Risk**: Spam Merkle tree with many small commitments.

**Mitigation**: Implementations MAY impose minimum conversion amounts or fees.

### Regulatory Risks

Privacy features may face regulatory scrutiny. This standard provides transparent mode for compliance but does not guarantee regulatory acceptance in all jurisdictions.

**Non-Technical Mitigation**: Consult legal counsel before deployment.

## Copyright

Copyright and related rights waived via [CC0](../LICENSE.md).
