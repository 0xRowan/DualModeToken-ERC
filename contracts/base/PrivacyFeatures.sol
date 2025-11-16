// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "../interfaces/IZRC20.sol";
import "../interfaces/IVerifier.sol";

/**
 * @title PrivacyFeatures
 * @dev Abstract base contract providing ZK-SNARK privacy functionality
 *      This module handles the privacy layer with dual-tree Merkle structure
 *
 * Key Features:
 *   - Dual-layer Merkle tree (active subtree + finalized root tree)
 *   - ZK-SNARK proof verification for mints and transfers
 *   - Nullifier-based double-spend protection
 *   - Commitment-based privacy balances
 *
 * Note: This is an abstract contract meant to be inherited by DualModeToken
 */
abstract contract PrivacyFeatures is IZRC20, ReentrancyGuard {

    // ===================================
    //        CUSTOM ERRORS
    // ===================================
    error PrivacyNotInitialized();
    error PrivacyAlreadyInitialized();
    error InvalidProofType(uint8 receivedType);
    error InvalidProof();
    error CommitmentAlreadyExists(bytes32 commitment);
    error DoubleSpend(bytes32 nullifier);
    error OldActiveRootMismatch(bytes32 expected, bytes32 received);
    error OldFinalizedRootMismatch(bytes32 expected, bytes32 received);
    error IncorrectSubtreeIndex(uint256 expected, uint256 received);
    error InvalidStateForRegularMint();
    error InvalidStateForRollover();
    error SubtreeCapacityExceeded(uint256 needed, uint256 available);
    error InvalidUnshieldAmount(uint256 expected, uint256 proven);
    error InvalidMintAmount(uint256 expected, uint256 proven);

    // ===================================
    //        STATE VARIABLES
    // ===================================

    // --- Burn Address  ---
    uint256 public constant BURN_ADDRESS_X = 3782696719816812986959462081646797447108674627635188387134949121808249992769;
    uint256 public constant BURN_ADDRESS_Y = 10281180275793753078781257082583594598751421619807573114845203265637415315067;

    // --- Verifiers ---
    IActiveTransferVerifier public activeTransferVerifier;
    IFinalizedTransferVerifier public finalizedTransferVerifier;
    ITransferRolloverVerifier public rolloverTransferVerifier;
    IMintVerifier public mintVerifier;
    IMintRolloverVerifier public mintRolloverVerifier;

    // --- Privacy State ---
    mapping(bytes32 => bool) public nullifiers;  // Keep original name
    mapping(bytes32 => bool) public commitmentHashes;  // Keep original name
    uint256 public privacyTotalSupply;

    // --- Packed State ---
    ContractState public state;  // Keep original name

    // --- Tree Roots ---
    bytes32 public EMPTY_SUBTREE_ROOT;
    bytes32 public activeSubtreeRoot;
    bytes32 public finalizedRoot;
    uint256 public SUBTREE_CAPACITY;

    // --- Transaction Data Structure ---
    struct TransactionData {
        bytes32[2] nullifiers;
        bytes32[2] commitments;
        uint256[2] ephemeralPublicKey;
        uint256 viewTag;
    }

    // ===================================
    //        INITIALIZATION
    // ===================================

    /**
     * @dev Initialize privacy features (called by child contract)
     * @param verifiers_ Array of verifier contract addresses [mint, mintRollover, active, finalized, rollover]
     * @param subtreeHeight_ Height of active subtrees
     * @param rootTreeHeight_ Height of root tree
     * @param initialSubtreeEmptyRoot_ Empty subtree root hash
     * @param initialFinalizedEmptyRoot_ Empty finalized root hash
     */
    function _initializePrivacy(
        address[5] memory verifiers_,
        uint8 subtreeHeight_,
        uint8 rootTreeHeight_,
        bytes32 initialSubtreeEmptyRoot_,
        bytes32 initialFinalizedEmptyRoot_
    ) internal {
        if (state.initialized) revert PrivacyAlreadyInitialized();
        state.initialized = true;

        mintVerifier = IMintVerifier(verifiers_[0]);
        mintRolloverVerifier = IMintRolloverVerifier(verifiers_[1]);
        activeTransferVerifier = IActiveTransferVerifier(verifiers_[2]);
        finalizedTransferVerifier = IFinalizedTransferVerifier(verifiers_[3]);
        rolloverTransferVerifier = ITransferRolloverVerifier(verifiers_[4]);

        state.subTreeHeight = subtreeHeight_;
        SUBTREE_CAPACITY = 1 << subtreeHeight_;
        state.rootTreeHeight = rootTreeHeight_;
        EMPTY_SUBTREE_ROOT = initialSubtreeEmptyRoot_;

        activeSubtreeRoot = initialSubtreeEmptyRoot_;
        finalizedRoot = initialFinalizedEmptyRoot_;
        state.nextLeafIndexInSubtree = 0;
    }

    // ===================================
    //      PRIVACY MINT (INTERNAL)
    // ===================================

    /**
     * @dev Internal privacy mint function
     * @param expectedAmount The amount expected to be minted (validated against proof)
     * @param proofType 0 for regular, 1 for rollover
     * @param proof ZK-SNARK proof
     * @param encryptedNote Encrypted note
     * @return actualAmount The actual amount minted (from proof)
     */
    function _privacyMint(
        uint256 expectedAmount,
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) internal returns (uint256 actualAmount) {
        if (!state.initialized) revert PrivacyNotInitialized();

        if (proofType == 0) {
            actualAmount = _privacyMintRegular(expectedAmount, proof, encryptedNote);
        } else if (proofType == 1) {
            actualAmount = _privacyMintAndRollover(expectedAmount, proof, encryptedNote);
        } else {
            revert InvalidProofType(proofType);
        }

        privacyTotalSupply += actualAmount;
    }

    /**
     * @dev Regular privacy mint (no rollover)
     */
    function _privacyMintRegular(
        uint256 expectedAmount,
        bytes calldata _proof,
        bytes calldata _encryptedNote
    ) private returns (uint256) {
        if (state.nextLeafIndexInSubtree >= SUBTREE_CAPACITY) revert InvalidStateForRegularMint();

        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[4] memory pubSignals) =
            abi.decode(_proof, (uint[2], uint[2][2], uint[2], uint[4]));

        bytes32 newActiveRoot = bytes32(pubSignals[0]);
        bytes32 oldActiveRoot_from_proof = bytes32(pubSignals[1]);
        bytes32 newCommitment = bytes32(pubSignals[2]);
        uint256 mintAmount_from_proof = pubSignals[3];

        if (expectedAmount != mintAmount_from_proof) revert InvalidMintAmount(expectedAmount, mintAmount_from_proof);
        if (commitmentHashes[newCommitment]) revert CommitmentAlreadyExists(newCommitment);
        commitmentHashes[newCommitment] = true;

        if (activeSubtreeRoot != oldActiveRoot_from_proof) revert OldActiveRootMismatch(activeSubtreeRoot, oldActiveRoot_from_proof);
        if (!mintVerifier.verifyProof(a, b, c, pubSignals)) revert InvalidProof();

        activeSubtreeRoot = newActiveRoot;

        emit CommitmentAppended(state.currentSubtreeIndex, newCommitment, state.nextLeafIndexInSubtree, block.timestamp);
        state.nextLeafIndexInSubtree++;

        emit Minted(msg.sender, newCommitment, _encryptedNote, state.currentSubtreeIndex, state.nextLeafIndexInSubtree - 1, block.timestamp);

        return mintAmount_from_proof;
    }

    /**
     * @dev Privacy mint with rollover
     */
    function _privacyMintAndRollover(
        uint256 expectedAmount,
        bytes calldata _proof,
        bytes calldata _encryptedNote
    ) private returns (uint256) {
        if (state.nextLeafIndexInSubtree != SUBTREE_CAPACITY) revert InvalidStateForRollover();

        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[7] memory pubSignals) =
            abi.decode(_proof, (uint[2], uint[2][2], uint[2], uint[7]));

        bytes32 newActiveRoot = bytes32(pubSignals[0]);
        bytes32 newFinalizedRoot = bytes32(pubSignals[1]);
        bytes32 oldActiveRoot_from_proof = bytes32(pubSignals[2]);
        bytes32 oldFinalizedRoot_from_proof = bytes32(pubSignals[3]);
        bytes32 newCommitment = bytes32(pubSignals[4]);
        uint256 mintAmount_from_proof = pubSignals[5];
        uint256 subtreeIndex_from_proof = pubSignals[6];

        if (expectedAmount != mintAmount_from_proof) revert InvalidMintAmount(expectedAmount, mintAmount_from_proof);
        if (commitmentHashes[newCommitment]) revert CommitmentAlreadyExists(newCommitment);
        commitmentHashes[newCommitment] = true;

        if (activeSubtreeRoot != oldActiveRoot_from_proof) revert OldActiveRootMismatch(activeSubtreeRoot, oldActiveRoot_from_proof);
        if (finalizedRoot != oldFinalizedRoot_from_proof) revert OldFinalizedRootMismatch(finalizedRoot, oldFinalizedRoot_from_proof);
        if (state.currentSubtreeIndex != subtreeIndex_from_proof) revert IncorrectSubtreeIndex(state.currentSubtreeIndex, subtreeIndex_from_proof);

        if (!mintRolloverVerifier.verifyProof(a, b, c, pubSignals)) revert InvalidProof();

        emit SubtreeFinalized(state.currentSubtreeIndex, activeSubtreeRoot);

        activeSubtreeRoot = newActiveRoot;
        finalizedRoot = newFinalizedRoot;
        state.currentSubtreeIndex++;
        state.nextLeafIndexInSubtree = 0;

        emit CommitmentAppended(state.currentSubtreeIndex, newCommitment, state.nextLeafIndexInSubtree, block.timestamp);
        state.nextLeafIndexInSubtree++;

        emit Minted(msg.sender, newCommitment, _encryptedNote, state.currentSubtreeIndex, state.nextLeafIndexInSubtree - 1, block.timestamp);

        return mintAmount_from_proof;
    }

    // ===================================
    //     PRIVACY TRANSFER (INTERNAL)
    // ===================================

    /**
     * @dev Internal privacy transfer
     * @param proofType 0 for active, 1 for finalized, 2 for rollover
     * @param proof ZK-SNARK proof
     * @param encryptedNotes Encrypted notes
     */
    function _privacyTransfer(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) internal {
        if (!state.initialized) revert PrivacyNotInitialized();

        if (proofType == 0) {
            _transferActive(proof, encryptedNotes, false);
        } else if (proofType == 1) {
            _transferFinalized(proof, encryptedNotes, false);
        } else if (proofType == 2) {
            _transferAndRollover(proof, encryptedNotes);
        } else {
            revert InvalidProofType(proofType);
        }
    }

    /**
     * @dev Internal privacy burn
     * @param proofType 0 for active, 1 for finalized
     * @param proof ZK-SNARK proof
     * @param encryptedNotes Encrypted notes
     * @return burnAmount The amount
     */
    function _privacyBurn(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) internal returns (uint256 burnAmount) {
        if (!state.initialized) revert PrivacyNotInitialized();
        if (proofType >= 2) revert InvalidProofType(proofType);

        if (proofType == 0) {
            burnAmount = _transferActive(proof, encryptedNotes, true);
        } else {
            burnAmount = _transferFinalized(proof, encryptedNotes, true);
        }

        privacyTotalSupply -= burnAmount;
    }

    // ===================================
    //    INTERNAL TRANSFER LOGIC
    // ===================================

    function _transferActive(
        bytes calldata _proof,
        bytes[] calldata _encryptedNotes,
        bool isModeConversion
    ) private returns (uint256 withdrawAmount) {
        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[13] memory pubSignals) =
            abi.decode(_proof, (uint[2], uint[2][2], uint[2], uint[13]));

        bytes32 newActiveSubTreeRoot = bytes32(pubSignals[2]);
        uint256 numRealOutputs = pubSignals[3];
        withdrawAmount = pubSignals[4];
        bytes32 oldActiveSubTreeRoot = bytes32(pubSignals[5]);

        if (isModeConversion) {
            // Must convert non-zero amount for mode conversion
            if (withdrawAmount == 0) revert InvalidUnshieldAmount(1, 0);
            // Verify first output goes to burn address
            uint256 recipientX = pubSignals[10];
            uint256 recipientY = pubSignals[11];
            if (recipientX != BURN_ADDRESS_X || recipientY != BURN_ADDRESS_Y) {
                revert InvalidUnshieldAmount(0, 1);
            }
        } else {
            // Pure privacy transfer, conversion amount must be 0
            if (withdrawAmount != 0) revert InvalidUnshieldAmount(0, withdrawAmount);
        }

        uint256 availableCapacity = uint256(SUBTREE_CAPACITY - state.nextLeafIndexInSubtree);
        if (numRealOutputs > availableCapacity) revert SubtreeCapacityExceeded(numRealOutputs, availableCapacity);
        if (activeSubtreeRoot != oldActiveSubTreeRoot) revert OldActiveRootMismatch(activeSubtreeRoot, oldActiveSubTreeRoot);
        if (!activeTransferVerifier.verifyProof(a, b, c, pubSignals)) revert InvalidProof();

        activeSubtreeRoot = newActiveSubTreeRoot;

        TransactionData memory data;
        data.ephemeralPublicKey = [pubSignals[0], pubSignals[1]];
        data.nullifiers = [bytes32(pubSignals[6]), bytes32(pubSignals[7])];
        data.commitments = [bytes32(pubSignals[8]), bytes32(pubSignals[9])];
        data.viewTag = pubSignals[12];

        _processTransaction(data, _encryptedNotes);
    }

    function _transferFinalized(
        bytes calldata _proof,
        bytes[] calldata _encryptedNotes,
        bool isModeConversion
    ) private returns (uint256 withdrawAmount) {
        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[14] memory pubSignals) =
            abi.decode(_proof, (uint[2], uint[2][2], uint[2], uint[14]));

        bytes32 newActiveRoot = bytes32(pubSignals[2]);
        uint256 numRealOutputs = pubSignals[3];
        withdrawAmount = pubSignals[4];
        bytes32 oldFinalizedRoot = bytes32(pubSignals[5]);
        bytes32 oldActiveRoot = bytes32(pubSignals[6]);

        if (isModeConversion) {
            if (withdrawAmount == 0) revert InvalidUnshieldAmount(1, 0);
            uint256 recipientX = pubSignals[11];
            uint256 recipientY = pubSignals[12];
            if (recipientX != BURN_ADDRESS_X || recipientY != BURN_ADDRESS_Y) {
                revert InvalidUnshieldAmount(0, 1);
            }
        } else {
            if (withdrawAmount != 0) revert InvalidUnshieldAmount(0, withdrawAmount);
        }

        uint256 availableCapacity = uint32(SUBTREE_CAPACITY - state.nextLeafIndexInSubtree);
        if (numRealOutputs > availableCapacity) revert SubtreeCapacityExceeded(numRealOutputs, availableCapacity);
        if (activeSubtreeRoot != oldActiveRoot) revert OldActiveRootMismatch(activeSubtreeRoot, oldActiveRoot);
        if (finalizedRoot != oldFinalizedRoot) revert OldFinalizedRootMismatch(finalizedRoot, oldFinalizedRoot);
        if (!finalizedTransferVerifier.verifyProof(a, b, c, pubSignals)) revert InvalidProof();

        activeSubtreeRoot = newActiveRoot;

        TransactionData memory data;
        data.ephemeralPublicKey = [pubSignals[0], pubSignals[1]];
        data.nullifiers = [bytes32(pubSignals[7]), bytes32(pubSignals[8])];
        data.commitments = [bytes32(pubSignals[9]), bytes32(pubSignals[10])];
        data.viewTag = pubSignals[13];

        _processTransaction(data, _encryptedNotes);
    }

    function _transferAndRollover(
        bytes calldata _proof,
        bytes[] calldata _encryptedNotes
    ) private {
        (uint[2] memory a, uint[2][2] memory b, uint[2] memory c, uint[13] memory pubSignals) =
            abi.decode(_proof, (uint[2], uint[2][2], uint[2], uint[13]));

        bytes32 newActive = bytes32(pubSignals[2]);
        bytes32 newFinalized = bytes32(pubSignals[3]);
        uint256 withdrawAmount = pubSignals[4];
        bytes32 oldActive = bytes32(pubSignals[5]);
        bytes32 oldFinalized = bytes32(pubSignals[6]);
        uint256 subtreeIndex_from_proof = pubSignals[12];

        // Rollover transfers don't support unshield
        if (withdrawAmount != 0) revert InvalidUnshieldAmount(0, withdrawAmount);

        if (state.nextLeafIndexInSubtree != SUBTREE_CAPACITY) revert InvalidStateForRollover();
        if (activeSubtreeRoot != oldActive) revert OldActiveRootMismatch(activeSubtreeRoot, oldActive);
        if (finalizedRoot != oldFinalized) revert OldFinalizedRootMismatch(finalizedRoot, oldFinalized);
        if (state.currentSubtreeIndex != subtreeIndex_from_proof) revert IncorrectSubtreeIndex(state.currentSubtreeIndex, subtreeIndex_from_proof);
        if (!rolloverTransferVerifier.verifyProof(a, b, c, pubSignals)) revert InvalidProof();

        emit SubtreeFinalized(state.currentSubtreeIndex, activeSubtreeRoot);

        activeSubtreeRoot = newActive;
        finalizedRoot = newFinalized;
        state.currentSubtreeIndex++;
        state.nextLeafIndexInSubtree = 0;

        TransactionData memory data;
        data.ephemeralPublicKey = [pubSignals[0], pubSignals[1]];
        data.nullifiers = [bytes32(pubSignals[7]), bytes32(0)];
        data.commitments = [bytes32(pubSignals[8]), bytes32(0)];
        data.viewTag = pubSignals[11];

        _processTransaction(data, _encryptedNotes);
    }

    /**
     * @dev Process transaction: spend nullifiers and append commitments
     */
    function _processTransaction(
        TransactionData memory _data,
        bytes[] calldata _encryptedNotes
    ) private {
        // Spend Nullifiers
        for (uint32 i = 0; i < _data.nullifiers.length; i++) {
            bytes32 n = _data.nullifiers[i];
            if (n != bytes32(0)) {
                if (nullifiers[n]) revert DoubleSpend(n);
                nullifiers[n] = true;
                emit NullifierSpent(n);
            }
        }

        // Append Commitments
        for (uint i = 0; i < _data.commitments.length; i++) {
            bytes32 c = _data.commitments[i];
            if (c != bytes32(0)) {
                emit CommitmentAppended(state.currentSubtreeIndex, c, state.nextLeafIndexInSubtree, block.timestamp);
                state.nextLeafIndexInSubtree++;
                if (state.nextLeafIndexInSubtree >= SUBTREE_CAPACITY) revert InvalidStateForRegularMint();
            }
        }
        emit Transaction(_data.commitments, _encryptedNotes, _data.ephemeralPublicKey, _data.viewTag);
    }

    // ===================================
    //         VIEW FUNCTIONS
    // ===================================

    function getPrivacyState() external view override returns (
        bytes32 activeRoot,
        bytes32 finalizedRoot_,
        uint256 privacySupply,
        uint32 currentSubtreeIndex,
        uint32 nextLeafIndex
    ) {
        return (
            activeSubtreeRoot,
            finalizedRoot,
            privacyTotalSupply,
            state.currentSubtreeIndex,
            state.nextLeafIndexInSubtree
        );
    }
}
