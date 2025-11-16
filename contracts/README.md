# Smart Contracts

This directory contains the reference implementation of the Dual-Mode Token Standard.

## 📁 Directory Structure

```
contracts/
├── core/
│   └── DualModeToken.sol          # Main dual-mode token implementation
├── base/
│   └── PrivacyFeatures.sol        # Privacy functionality base contract
└── interfaces/
    ├── IDualModeToken.sol         # Main interface (ERC standard)
    ├── IZRC20.sol                 # Privacy transfer interface
    └── IVerifier.sol              # ZK-SNARK verifier interface
```

## 🔧 Core Contracts

### DualModeToken.sol
Main implementation combining ERC-20 and privacy features.

**Key Functions:**
- `toPrivacy()` - Convert public balance to privacy mode
- `toPublic()` - Convert privacy balance to public mode
- `privacyTransfer()` - Execute privacy-preserving transfer
- `mintPublic()` / `mint()` - Dual minting capabilities

**Inherits:**
- `ERC20` (OpenZeppelin)
- `PrivacyFeatures` (Privacy layer)
- `IDualModeToken` (Standard interface)

### PrivacyFeatures.sol
Abstract base providing ZK-SNARK privacy functionality.

**Features:**
- Dual Merkle tree (Active + Finalized)
- ZK-SNARK proof verification
- Nullifier-based double-spend protection
- Commitment-based privacy balances

## 📝 Interfaces

### IDualModeToken.sol
**ERC standard interface** defining:
- Mode conversion functions
- Privacy transfer functions
- Supply tracking
- Events

### IZRC20.sol
Privacy transfer interface (used internally).

### IVerifier.sol
ZK-SNARK verifier interface (Groth16).

## 🔒 Security Features

1. **Supply Conservation**: `totalSupply() = publicSupply + privacySupply`
2. **Double-Spend Prevention**: Nullifier tracking
3. **Mode Conversion Integrity**: BURN_ADDRESS requirement
4. **Reentrancy Protection**: OpenZeppelin ReentrancyGuard

## 📦 Dependencies

- **OpenZeppelin Contracts**: `^4.9.0`
  - `ERC20.sol`
  - `ReentrancyGuard.sol`

- **ZK-SNARK Verifiers**: (Not included, generated from circuits)
  - `ProveMintVerifier`
  - `ProveActiveTransferVerifier`
  - `ProveFinalizedTransferVerifier`
  - `ProveRolloverTransferVerifier`
  - `ProveMintAndRolloverVerifier`

## 🚀 Deployment

### Prerequisites
```bash
npm install @openzeppelin/contracts
```

### Basic Deployment
```solidity
// 1. Deploy verifier contracts (from circuit output)
address[5] memory verifiers = [
    address(proveMintVerifier),
    address(proveActiveTransferVerifier),
    address(proveFinalizedTransferVerifier),
    address(proveRolloverTransferVerifier),
    address(proveMintAndRolloverVerifier)
];

// 2. Deploy DualModeToken
DualModeToken token = new DualModeToken();

// 3. Initialize
token.initialize(
    "My Token",                    // name
    "MTK",                         // symbol
    1_000_000 ether,               // maxSupply
    0.01 ether,                    // publicMintPrice
    100 ether,                     // publicMintAmount
    0.01 ether,                    // privacyMintPrice
    100 ether,                     // privacyMintAmount
    treasuryAddress,               // platformTreasury
    25,                            // platformFeeBps (0.25%)
    verifiers,                     // verifier addresses
    16,                            // subtreeHeight
    16,                            // rootTreeHeight
    EMPTY_SUBTREE_ROOT,            // initialSubtreeEmptyRoot
    EMPTY_FINALIZED_ROOT           // initialFinalizedEmptyRoot
);
```

## 🧪 Testing

Tests are located in the main repository (not included here to keep ERC proposal focused).

For testing:
1. See complete test suite in reference implementation
2. Tests cover:
   - Public mode operations (ERC-20)
   - Privacy mode operations
   - Mode conversion
   - Security invariants
   - Edge cases

## 📖 Usage Examples

### Public Mode (Standard ERC-20)
```solidity
// Transfer public tokens
token.transfer(recipient, 100 ether);

// Approve and transferFrom
token.approve(spender, 100 ether);
token.transferFrom(owner, recipient, 100 ether);
```

### Convert to Privacy Mode
```solidity
// Generate proof offline (using circuit)
bytes memory proof = generateMintProof(...);
bytes memory encryptedNote = encryptNote(...);

// Convert 100 tokens to privacy mode
token.toPrivacy(100 ether, 0, proof, encryptedNote);
```

### Privacy Transfer
```solidity
// Generate transfer proof offline
bytes memory proof = generateTransferProof(...);
bytes[] memory encryptedNotes = new bytes[](2);

// Execute private transfer
token.privacyTransfer(0, proof, encryptedNotes);
```

### Convert Back to Public
```solidity
// Generate conversion proof
bytes memory proof = generateConversionProof(...);
bytes[] memory encryptedNotes = new bytes[](1);

// Convert back to public mode
token.toPublic(recipient, 0, proof, encryptedNotes);
```

## 🔍 Implementation Notes

### Clone Pattern
Uses minimal proxy (EIP-1167) pattern via factory for gas-efficient deployment.

### Initialization
Constructor is empty; actual initialization via `initialize()` for clone compatibility.

### Fee Mechanism
- Optional protocol fee on `toPublic()` conversion
- Configurable via `platformFeeBps`
- Supports sustainable protocol development

### Backward Compatibility
- `shield()` alias for `toPrivacy()`
- `unshield()` alias for `toPublic()`
- Maintains compatibility with wrapper-based mental models

## ⚠️ Important Notes

### ZK-SNARK Circuits
This implementation requires ZK-SNARK circuits for:
- Minting commitments
- Privacy transfers
- Mode conversions

**Circuit generation is NOT included** in this ERC proposal. Implementers must:
1. Design circuits meeting specification requirements
2. Generate verifier contracts
3. Deploy and reference in initialization

### Gas Costs
- Public operations: ~50K gas (standard ERC-20)
- Privacy operations: ~250K gas (ZK proof verification)
- Mode conversion: ~300K gas (proof + mint/burn)

### Privacy Considerations
- Privacy set limited to this token's users
- Note encryption handled client-side
- Key management is user responsibility

## 📚 Additional Resources

- **Full Specification**: [ERC_DRAFT.md](../ERC_DRAFT.md)
- **Design Rationale**: [docs/RATIONALE.md](../docs/RATIONALE.md)
- **Security Analysis**: See ERC_DRAFT.md Security Considerations

## 📝 License

Copyright and related rights waived via [CC0](../LICENSE).
