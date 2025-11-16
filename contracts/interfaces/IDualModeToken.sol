// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IZRC20.sol";

/**
 * @title IDualModeToken
 * @dev Interface for dual-mode tokens that combine ERC20 (public) and ZRC20 (private) functionality
 *
 * Architecture:
 *   - Public Mode: Standard ERC20 with transparent balances and transfers
 *   - Privacy Mode: ZK-SNARK protected balances and transfers
 *   - Mode Conversion: toPrivacy (public → private) and toPublic (private → public)
 */
interface IDualModeToken is IERC20, IZRC20 {

    // ===================================
    //             ENUMS
    // ===================================

    /// @notice Token operating modes
    enum TokenMode { PUBLIC, PRIVATE }

    // ===================================
    //             EVENTS
    // ===================================

    /// @notice Emitted when value is converted from public to privacy mode
    /// @param account The address converting tokens
    /// @param amount The amount converted
    /// @param commitment The cryptographic commitment created
    /// @param timestamp Block timestamp of conversion
    event ConvertToPrivacy(
        address indexed account,
        uint256 amount,
        bytes32 indexed commitment,
        uint256 timestamp
    );

    /// @notice Emitted when value is converted from privacy to public mode
    /// @param initiator The address initiating the conversion
    /// @param recipient The address receiving public tokens
    /// @param amount The amount converted
    /// @param timestamp Block timestamp of conversion
    event ConvertToPublic(
        address indexed initiator,
        address indexed recipient,
        uint256 amount,
        uint256 timestamp
    );

    /// @notice Emitted for dual-mode minting (OPTIONAL feature)
    /// @dev This event is implementation-specific and not required by the standard
    event DualMinted(
        address indexed minter,
        TokenMode mode,
        uint256 amount,
        uint256 timestamp
    );

    // ===================================
    //        MODE CONVERSION
    // ===================================

    /**
     * @notice Convert public balance to privacy mode
     * @dev Decreases public balance and creates privacy commitment via ZK proof
     * @param amount Amount to convert (must match proof)
     * @param proofType 0 for regular mint, 1 for rollover mint
     * @param proof ZK-SNARK proof of valid commitment creation
     * @param encryptedNote Encrypted note data for recipient wallet
     */
    function toPrivacy(
        uint256 amount,
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external;

    /**
     * @notice Convert privacy balance to public mode
     * @dev Decreases privacy balance and increases recipient's public balance via ZK proof
     * @param recipient Address to receive public tokens
     * @param proofType 0 for active transfer, 1 for finalized transfer
     * @param proof ZK-SNARK proof of note ownership and spending
     * @param encryptedNotes Encrypted notes for change outputs (if any)
     */
    function toPublic(
        address recipient,
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external;

    // ===================================
    //        OPTIONAL: DUAL MINTING
    // ===================================

    /**
     * @notice OPTIONAL: Mint public tokens (standard ERC20 mint)
     * @dev Implementations MAY implement this function
     * @dev If not implemented, users can acquire tokens through other means
     *      (e.g., pre-sale, DEX) and use toPrivacy() for privacy conversion
     * @param to Recipient address
     * @param amount Amount to mint
     */
    function mintPublic(address to, uint256 amount) external payable;

    /**
     * @notice OPTIONAL: Mint privacy tokens directly (ZK-SNARK protected mint)
     * @dev Implementations MAY implement this function
     * @dev If not implemented, users can mintPublic() then toPrivacy()
     * @param proofType 0 for regular, 1 for rollover
     * @param proof ZK-SNARK proof
     * @param encryptedNote Encrypted note
     */
    function mint(
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external payable;

    // ===================================
    //        PRIVACY TRANSFERS
    // ===================================

    /**
     * @notice Execute a privacy-preserving transfer
     * @dev Value stays within privacy mode (no conversion to public)
     * @param proofType 0 for active, 1 for finalized, 2 for rollover
     * @param proof ZK-SNARK proof of valid transfer
     * @param encryptedNotes Encrypted notes for recipients
     */
    function privacyTransfer(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external;

    // ===================================
    //          VIEW FUNCTIONS
    // ===================================

    /// @notice Get total supply in privacy mode
    /// @dev Tracked by increments/decrements, not computed from tree
    /// @return Total privacy supply
    function totalPrivacySupply() external view returns (uint256);

    /// @notice Check if a nullifier has been spent
    /// @param nullifier The nullifier hash to check
    /// @return True if spent, false otherwise
    function isNullifierSpent(bytes32 nullifier) external view returns (bool);

    // ===================================
    //    OPTIONAL: IMPLEMENTATION-SPECIFIC
    // ===================================

    /// @notice OPTIONAL: Get the maximum total supply (public + privacy)
    function MAX_SUPPLY() external view returns (uint256);

    /// @notice OPTIONAL: Get public mint price
    function PUBLIC_MINT_PRICE() external view returns (uint256);

    /// @notice OPTIONAL: Get public mint amount
    function PUBLIC_MINT_AMOUNT() external view returns (uint256);

    /// @notice OPTIONAL: Get privacy mint price
    function PRIVACY_MINT_PRICE() external view returns (uint256);

    /// @notice OPTIONAL: Get privacy mint amount
    function PRIVACY_MINT_AMOUNT() external view returns (uint256);

    /// @notice OPTIONAL: Check if contract is initialized
    function isInitialized() external view returns (bool);
}
