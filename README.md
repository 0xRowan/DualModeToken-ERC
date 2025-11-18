# Dual-Mode Token Standard (ERC Proposal)

**A token standard combining ERC-20 (public) and ZK-SNARK (private) functionality within a single token.**

> **Status**: Draft - Seeking community feedback
> **Discussions**: [Ethereum Magicians](https://ethereum-magicians.org/t/draft-dual-mode-token-standard-single-token-with-public-and-private-modes/26592)

---

## 🎯 Core Concept

**"Privacy is a mode, not a separate token."**

Users can:
- Hold tokens in **public mode** (full ERC-20 compatibility)
- Convert to **private mode** (ZK-SNARK protected balances)
- Convert back to **public mode** freely
- One token, unified liquidity, no wrapper contracts

---

## 📋 Proposal Documents

### Main Specification
- **[ERC_DRAFT.md](./ERC_DRAFT.md)** - Complete ERC specification (ready for GitHub submission)

### Supporting Documentation
- **[RATIONALE.md](./docs/RATIONALE.md)** - Design decisions and comparisons
- **[contracts/README.md](./contracts/README.md)** - Smart contracts documentation

---

## 🆚 Comparison with Existing Approaches

| Aspect | Wrapper-Based | Protocol-Level | Dual-Mode (Ours) |
|--------|--------------|----------------|------------------|
| **Use Case** | Existing tokens ✅ | New blockchains | **New tokens ✅** |
| **Liquidity** | Split for new tokens | Unified | **✅ Unified** |
| **Deployment** | ✅ Today | Years (fork) | **✅ Today** |
| **Reversibility** | ✅ Yes | ✅ Yes | **✅ Yes** |
| **ERC-20 Compatible** | Separate token | N/A | **✅ Full** |
| **DeFi Access** | Requires unwrap | Native | **Requires toPublic()** |

**Key Insight**: Wrapper-based and dual-mode approaches are **complementary**:
- **Wrapper**: Best for adding privacy to existing tokens (DAI, USDC)
- **Dual-Mode**: Best for new token launches with built-in privacy

---

## 🔧 Quick Example

```solidity
// Public mode (ERC-20)
token.transfer(recipient, 100 ether);

// Convert to private mode
token.toPrivacy(100 ether, proofType, proof, encryptedNote);

// Private transfer (ZK-SNARK)
token.privacyTransfer(proofType, proof, encryptedNotes);

// Convert back to public
token.toPublic(recipient, proofType, proof, encryptedNotes);
```

---

## 📚 Repository Structure

```
DualModeToken-ERC/
├── ERC_DRAFT.md              # Main ERC specification
├── README.md                 # This file
├── QUICK_START.md            # Quick start guide
├── contracts/                # Reference implementation
│   ├── core/                 # Main contracts
│   ├── base/                 # Base contracts
│   ├── interfaces/           # Standard interfaces
│   └── README.md             # Contract documentation
└── docs/
    └── RATIONALE.md          # Design decisions
```

---

## 🤝 Contributing

This is an open proposal seeking community feedback. We welcome:

- Technical critique and improvements
- Use case suggestions
- Security analysis
- Implementation feedback
- Alternative design proposals

**Discussion Forum**: [Ethereum Magicians](https://ethereum-magicians.org/t/draft-dual-mode-token-standard-single-token-with-public-and-private-modes/26592)

---

## 🔗 Reference Implementation

- **Smart Contracts**: [contracts/](./contracts/)
- **Main Contract**: [DualModeToken.sol](./contracts/core/DualModeToken.sol)
- **Interface Definition**: [IDualModeToken.sol](./contracts/interfaces/IDualModeToken.sol)
- **Documentation**: [contracts/README.md](./contracts/README.md)

---

## 📝 License

Copyright and related rights waived via [CC0](https://creativecommons.org/publicdomain/zero/1.0/).

---

## 👥 Authors

- Rowan ([@0xRowan](https://github.com/0xRowan))

---

**Built with ❤️ for Ethereum privacy**
