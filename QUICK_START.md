# Quick Start Guide

## For Community Reviewers

### 📖 Understanding the Proposal

1. **Start here**: Read [README.md](./README.md) for overview
2. **Core concept**: [ERC_DRAFT.md](./ERC_DRAFT.md) - Complete specification
3. **Why this design**: [docs/RATIONALE.md](./docs/RATIONALE.md)
4. **See it in action**: [contracts/](./contracts/)

### 💬 Join the Discussion

- **Forum**: [Ethereum Magicians](TBD) (link TBD after posting)
- **Questions**: Open GitHub issues
- **Feedback**: Comment on discussion thread

---

## For Implementers

### 📝 Interface Overview

```solidity
interface IDualModeToken is IERC20 {
    // Mode conversion
    function toPrivacy(uint256 amount, uint8 proofType, bytes calldata proof, bytes calldata encryptedNote) external;
    function toPublic(address recipient, uint8 proofType, bytes calldata proof, bytes[] calldata encryptedNotes) external;

    // Privacy transfers
    function privacyTransfer(uint8 proofType, bytes calldata proof, bytes[] calldata encryptedNotes) external;

    // View functions
    function totalPrivacySupply() external view returns (uint256);
    function isNullifierSpent(bytes32 nullifier) external view returns (bool);
}
```

### 🔧 Reference Implementation

Full working implementation included:
- **Main contract**: [DualModeToken.sol](./contracts/core/DualModeToken.sol)
- **Base contract**: [PrivacyFeatures.sol](./contracts/base/PrivacyFeatures.sol)
- **Interfaces**: [contracts/interfaces/](./contracts/interfaces/)
- **Documentation**: [contracts/README.md](./contracts/README.md)

### 🚀 Integration Example

```solidity
// Deploy
DualModeToken token = new DualModeToken();
token.initialize(...);

// Public mode (standard ERC-20)
token.transfer(alice, 100 ether);

// Convert to private
token.toPrivacy(50 ether, proofType, proof, encryptedNote);

// Private transfer
token.privacyTransfer(proofType, proof, encryptedNotes);

// Convert back to public
token.toPublic(bob, proofType, proof, encryptedNotes);
```

---

## For ERC Editors

### 📄 Submission Checklist

This proposal includes:

- ✅ Standard YAML frontmatter
- ✅ Abstract
- ✅ Motivation
- ✅ Specification (complete interface)
- ✅ Rationale
- ✅ Backwards Compatibility analysis
- ✅ Security Considerations
- ✅ Copyright Waiver (CC0)
- ✅ Reference Implementation
- ✅ Test Cases (in implementation repository)

### 📊 Compliance

- **EIP-1**: Follows all formatting requirements
- **RFC 2119**: Uses proper keywords (MUST, SHOULD, etc.)
- **Category**: Standards Track - ERC
- **Dependencies**: Extends ERC-20, ERC-165

---

## Repository Structure

```
DualModeToken-ERC/
├── README.md                           # Project overview
├── ERC_DRAFT.md                        # Main ERC specification
├── QUICK_START.md                      # This file
├── LICENSE                             # CC0 license
├── docs/
│   ├── RATIONALE.md                    # Design decisions
│   ├── SECURITY.md                     # Security analysis (TBD)
│   └── IMPLEMENTATION.md               # Implementation guide (TBD)
└── discussions/
    └── ethereum-magicians/
        └── DISCUSSION_POST.md          # Forum post draft
```

---

## Timeline

1. **Now**: Community discussion on Ethereum Magicians
2. **2-4 weeks**: Gather feedback, refine proposal
3. **After consensus**: Submit PR to [ethereum/ERCs](https://github.com/ethereum/ERCs)
4. **Editor review**: Obtain ERC number
5. **Iterate**: Continue improving based on feedback

---

## Getting Help

- **Questions about the standard**: [Ethereum Magicians discussion](TBD)
- **Implementation questions**: Open an issue in this repository
- **General**: Open an issue in this repository

---

**Let's build privacy infrastructure for Ethereum together!** 🚀
