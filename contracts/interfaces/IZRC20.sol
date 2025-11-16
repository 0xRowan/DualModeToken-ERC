// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

/**
 * @title IZRC20
 * @dev Interface for privacy-enhanced tokens using ZK-SNARKs
 *      This is the same interface used in shield version for compatibility
 */
interface IZRC20 {

    // ===================================
    //             EVENTS
    // ===================================

    event CommitmentAppended(uint32 indexed subtreeIndex, bytes32 commitment, uint32 indexed leafIndex, uint256 timestamp);
    event NullifierSpent(bytes32 indexed nullifier);
    event SubtreeFinalized(uint32 indexed subtreeIndex, bytes32 root);

    event Minted(
        address indexed minter,
        bytes32 commitment,
        bytes encryptedNote,
        uint32 subtreeIndex,
        uint32 leafIndex,
        uint256 timestamp
    );

    event Transaction(
        bytes32[2] newCommitments,
        bytes[] encryptedNotes,
        uint256[2] ephemeralPublicKey,
        uint256 viewTag
    );

    event Unshielded(
        address indexed initiator,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    // ===================================
    //       STATE STRUCTURE
    // ===================================

    struct ContractState {
        uint32 currentSubtreeIndex;
        uint32 nextLeafIndexInSubtree;
        uint8 subTreeHeight;
        uint8 rootTreeHeight;
        bool initialized;
    }

    // ===================================
    //    PRIVACY-SPECIFIC VIEW FUNCTIONS
    // ===================================

    // Note: name(), symbol(), decimals(), totalSupply() are provided by ERC20
    // DualModeToken inherits ERC20, so we don't redefine them here to avoid redundancy

    function finalizedRoot() external view returns (bytes32);
    function activeSubtreeRoot() external view returns (bytes32);

    // ===================================
    //      PRIVACY OPERATIONS
    // ===================================

    function mint(
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external payable;

    function transfer(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external;
}
