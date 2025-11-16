// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "../base/PrivacyFeatures.sol";
import "../interfaces/IDualModeToken.sol";

/**
 * @title DualModeToken
 * @dev A token with dual modes: public (ERC20) and private (ZK-SNARK)
 *
 * Architecture:
 *      ERC20 (OpenZeppelin) ← Public balances & transfers
 *        ↑
 *      PrivacyFeatures ← Privacy balances & ZK transfers
 *        ↑
 *      DualModeToken ← Mode Conversion & dual minting
 *
 * Key Features:
 *   - Dual Minting: Public mint (ERC20) and Private mint (ZK)
 *   - toPrivacy: Convert public → private
 *   - toPublic: Convert private → public
 *   - Total Supply: public + private <= MAX_SUPPLY
 *   - Backward Compatibility: shield/unshield aliases maintained
 */
contract DualModeToken is ERC20, PrivacyFeatures, IDualModeToken {

    // ===================================
    //        CUSTOM ERRORS
    // ===================================
    error AlreadyInitialized();
    error MaxSupplyExceeded();
    error IncorrectMintPrice(uint256 expected, uint256 sent);
    error IncorrectMintAmount(uint256 expected, uint256 actual);
    error InsufficientPublicBalance();
    error ZeroAddress();
    error TransferFailed();

    // ===================================
    //        STATE VARIABLES
    // ===================================
    uint256 public override MAX_SUPPLY;
    uint256 public override PUBLIC_MINT_PRICE;
    uint256 public override PUBLIC_MINT_AMOUNT;
    uint256 public override PRIVACY_MINT_PRICE;
    uint256 public override PRIVACY_MINT_AMOUNT;

    address public platformTreasury;
    uint256 public platformFeeBps; // Basis points (e.g., 25 = 0.25%)

    bool private _initialized;

    // ===================================
    //        CONSTRUCTOR
    // ===================================

    /**
     * @dev Constructor is empty because we use Clone pattern
     *      Actual initialization happens in initialize()
     */
    constructor() ERC20("", "") {}

    // ===================================
    //        INITIALIZATION
    // ===================================

    /**
     * @notice Initialize the dual-mode token (called by factory)
     * @param name_ Token name
     * @param symbol_ Token symbol
     * @param maxSupply_ Maximum total supply (public + privacy)
     * @param publicMintPrice_ Price to mint public tokens
     * @param publicMintAmount_ Amount minted per public mint
     * @param privacyMintPrice_ Price to mint privacy tokens
     * @param privacyMintAmount_ Amount minted per privacy mint
     * @param platformTreasury_ Address to receive fees
     * @param platformFeeBps_ Platform fee in basis points
     * @param verifiers_ Array of ZK verifier addresses
     * @param subtreeHeight_ Height of privacy subtrees
     * @param rootTreeHeight_ Height of privacy root tree
     * @param initialSubtreeEmptyRoot_ Initial empty subtree root
     * @param initialFinalizedEmptyRoot_ Initial empty finalized root
     */
    function initialize(
        string memory name_,
        string memory symbol_,
        uint256 maxSupply_,
        uint256 publicMintPrice_,
        uint256 publicMintAmount_,
        uint256 privacyMintPrice_,
        uint256 privacyMintAmount_,
        address platformTreasury_,
        uint256 platformFeeBps_,
        address[5] memory verifiers_,
        uint8 subtreeHeight_,
        uint8 rootTreeHeight_,
        bytes32 initialSubtreeEmptyRoot_,
        bytes32 initialFinalizedEmptyRoot_
    ) external {
        if (_initialized) revert AlreadyInitialized();
        _initialized = true;

        // Initialize ERC20 metadata (via internal function)
        _setMetadata(name_, symbol_);

        // Initialize configuration
        MAX_SUPPLY = maxSupply_;
        PUBLIC_MINT_PRICE = publicMintPrice_;
        PUBLIC_MINT_AMOUNT = publicMintAmount_;
        PRIVACY_MINT_PRICE = privacyMintPrice_;
        PRIVACY_MINT_AMOUNT = privacyMintAmount_;
        platformTreasury = platformTreasury_;
        platformFeeBps = platformFeeBps_;

        // Initialize privacy features
        _initializePrivacy(
            verifiers_,
            subtreeHeight_,
            rootTreeHeight_,
            initialSubtreeEmptyRoot_,
            initialFinalizedEmptyRoot_
        );
    }

    /**
     * @dev Internal function to set ERC20 metadata
     *      This is a workaround since ERC20 constructor requires name/symbol
     */
    function _setMetadata(string memory name_, string memory symbol_) private {
        // Directly update storage slots (advanced technique)
        // Slot 6: name length + data
        // Slot 7: symbol length + data
        assembly {
            let nameLength := mload(name_)
            let symbolLength := mload(symbol_)

            // Store name
            if lt(nameLength, 32) {
                // Short string: store inline
                sstore(6, or(mload(add(name_, 32)), mul(nameLength, 2)))
            }
            if iszero(lt(nameLength, 32)) {
                // Long string: store length and data separately
                sstore(6, or(mul(nameLength, 2), 1))
                let slot := keccak256(6, 32)
                for { let i := 0 } lt(i, div(add(nameLength, 31), 32)) { i := add(i, 1) } {
                    sstore(add(slot, i), mload(add(add(name_, 32), mul(i, 32))))
                }
            }

            // Store symbol
            if lt(symbolLength, 32) {
                sstore(7, or(mload(add(symbol_, 32)), mul(symbolLength, 2)))
            }
            if iszero(lt(symbolLength, 32)) {
                sstore(7, or(mul(symbolLength, 2), 1))
                let slot := keccak256(7, 32)
                for { let i := 0 } lt(i, div(add(symbolLength, 31), 32)) { i := add(i, 1) } {
                    sstore(add(slot, i), mload(add(add(symbol_, 32), mul(i, 32))))
                }
            }
        }
    }

    // ===================================
    //        PUBLIC MINTING
    // ===================================

    /**
     * @notice Mint public tokens (standard ERC20 mint)
     * @param to Recipient address
     * @param amount Amount to mint (must equal PUBLIC_MINT_AMOUNT)
     */
    function mintPublic(address to, uint256 amount) external payable override nonReentrant {
        if (msg.value != PUBLIC_MINT_PRICE) revert IncorrectMintPrice(PUBLIC_MINT_PRICE, msg.value);
        if (amount != PUBLIC_MINT_AMOUNT) revert IncorrectMintAmount(PUBLIC_MINT_AMOUNT, amount);
        if (totalSupply() + amount > MAX_SUPPLY) revert MaxSupplyExceeded();

        _mint(to, amount);

        emit DualMinted(to, TokenMode.PUBLIC, amount, block.timestamp);
    }

    // ===================================
    //        PRIVACY MINTING
    // ===================================

    /**
     * @notice Mint privacy tokens (ZK-SNARK protected mint)
     * @dev Keep function name as 'mint' to match shield version
     * @param proofType 0 for regular, 1 for rollover
     * @param proof ZK-SNARK proof
     * @param encryptedNote Encrypted note
     */
    function mint(
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external payable override nonReentrant {
        if (msg.value != PRIVACY_MINT_PRICE) revert IncorrectMintPrice(PRIVACY_MINT_PRICE, msg.value);
        if (totalSupply() + PRIVACY_MINT_AMOUNT > MAX_SUPPLY) revert MaxSupplyExceeded();

        _privacyMint(PRIVACY_MINT_AMOUNT, proofType, proof, encryptedNote);

        emit DualMinted(msg.sender, TokenMode.PRIVATE, PRIVACY_MINT_AMOUNT, block.timestamp);
    }

    // ===================================
    //        MODE CONVERSION (Public → Private)
    // ===================================

    /**
     * @notice Convert public balance to privacy mode
     * @dev Burns ERC20 tokens and creates privacy commitment
     * @param amount Amount to convert
     * @param proofType 0 for regular, 1 for rollover
     * @param proof ZK-SNARK proof
     * @param encryptedNote Encrypted note
     */
    function toPrivacy(
        uint256 amount,
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external override nonReentrant {
        if (balanceOf(msg.sender) < amount) revert InsufficientPublicBalance();

        // 1. Burn public tokens
        _burn(msg.sender, amount);

        // 2. Create privacy commitment
        uint256 actualMinted = _privacyMint(amount, proofType, proof, encryptedNote);

        // 3. Verify amount matches
        if (actualMinted != amount) revert IncorrectMintAmount(amount, actualMinted);

        // Get commitment from last minted event (this is a simplification)
        bytes32 commitment = bytes32(uint256(uint160(msg.sender))); // Placeholder

        emit ConvertToPrivacy(msg.sender, amount, commitment, block.timestamp);
    }

    /// @notice Backward compatibility alias for toPrivacy
    /// @dev Allows existing clients to continue using shield()
    function shield(
        uint256 amount,
        uint8 proofType,
        bytes calldata proof,
        bytes calldata encryptedNote
    ) external {
        // Delegate to toPrivacy
        this.toPrivacy(amount, proofType, proof, encryptedNote);
    }

    // ===================================
    //        MODE CONVERSION (Private → Public)
    // ===================================

    /**
     * @notice Convert privacy balance to public mode
     * @dev Converts privacy commitments to public ERC20 tokens
     * @param recipient Address to receive public tokens
     * @param proofType 0 for active, 1 for finalized
     * @param proof ZK-SNARK proof
     * @param encryptedNotes Encrypted notes
     */
    function toPublic(
        address recipient,
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external override nonReentrant {
        if (recipient == address(0)) revert ZeroAddress();

        // 1. Convert privacy tokens to get amount
        uint256 conversionAmount = _privacyBurn(proofType, proof, encryptedNotes);

        // 2. Calculate fee
        uint256 protocolFee = (conversionAmount * platformFeeBps) / 10000;
        uint256 recipientAmount = conversionAmount - protocolFee;

        // 3. Mint public tokens to recipient
        if (recipientAmount > 0) {
            _mint(recipient, recipientAmount);
        }

        // 4. Mint fee to treasury
        if (protocolFee > 0) {
            _mint(platformTreasury, protocolFee);
        }

        emit ConvertToPublic(msg.sender, recipient, conversionAmount, block.timestamp);
    }

    /// @notice Backward compatibility alias for toPublic
    /// @dev Allows existing clients to continue using unshield()
    function unshield(
        address recipient,
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external {
        // Delegate to toPublic
        this.toPublic(recipient, proofType, proof, encryptedNotes);
    }

    // ===================================
    //        PRIVACY TRANSFERS
    // ===================================

    /**
     * @notice Execute a privacy-preserving transfer
     * @dev Value stays within privacy mode (no conversion to public)
     * @param proofType 0 for active, 1 for finalized, 2 for rollover
     * @param proof ZK-SNARK proof
     * @param encryptedNotes Encrypted notes
     */
    function privacyTransfer(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external override {
        _privacyTransfer(proofType, proof, encryptedNotes);
    }

    /// @notice Backward compatibility alias for privacyTransfer
    /// @dev Allows IZRC20 clients to continue using transfer()
    function transfer(
        uint8 proofType,
        bytes calldata proof,
        bytes[] calldata encryptedNotes
    ) external {
        _privacyTransfer(proofType, proof, encryptedNotes);
    }

    // ===================================
    //        VIEW FUNCTIONS
    // ===================================

    function isInitialized() external view override returns (bool) {
        return _initialized;
    }

    /**
     * @notice Get total supply (public + privacy)
     * @dev EIP requirement: totalSupply() MUST return sum of both modes
     * @return Total supply across both public and privacy modes
     */
    function totalSupply() public view override(ERC20, IERC20) returns (uint256) {
        return ERC20.totalSupply() + privacyTotalSupply;
    }

    /**
     * @notice Get total supply in privacy mode
     * @dev Required by EIP standard
     * @return Total privacy supply
     */
    function totalPrivacySupply() external view override returns (uint256) {
        return privacyTotalSupply;
    }

    /**
     * @notice Check if a nullifier has been spent
     * @dev Required by EIP standard
     * @param nullifier The nullifier hash to check
     * @return True if spent, false otherwise
     */
    function isNullifierSpent(bytes32 nullifier) external view override returns (bool) {
        return nullifiers[nullifier];
    }

    // ===================================
    //        FEE DISTRIBUTION
    // ===================================

    /**
     * @notice Distribute collected mint fees to treasury
     */
    function distributeFees() external nonReentrant {
        uint256 balance = address(this).balance;
        if (balance == 0) revert("No fees to distribute");

        (bool success, ) = platformTreasury.call{value: balance}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @notice Receive ETH for mint payments
     */
    receive() external payable {}
}
