// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

// Interfaces & Libraries (Matching CryptoartNFT)
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {IERC7160} from "../../src/interfaces/IERC7160.sol"; // Adjust path if needed
import {IStory} from "../../src/interfaces/IStory.sol"; // Adjust path if needed
import {Error} from "../../src/libraries/Error.sol"; // Adjust path if needed

// OZ Contracts (Matching CryptoartNFT)
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable, IERC165} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {
    ERC721PausableUpgradeable
} // <<< Updated
from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import {
    ERC721RoyaltyUpgradeable,
    ERC2981Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardTransientUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

/**
 * @title Cryptoart NFT Mock Upgrade
 * @author Cryptoart Team
 * @notice Mock contract for testing upgrades FROM CryptoartNFT. Includes sample new variables and functions.
 */
/// @custom:oz-upgrades-from CryptoartNFT
contract CryptoartNFTMockUpgrade is
    Initializable,
    IERC7160,
    IERC4906,
    ERC721BurnableUpgradeable,
    ERC721RoyaltyUpgradeable,
    ERC721EnumerableUpgradeable,
    ERC721PausableUpgradeable,
    OwnableUpgradeable,
    NoncesUpgradeable,
    IStory,
    ReentrancyGuardTransientUpgradeable
{
    using Strings for uint256;
    using Strings for address;

    // ==========================================================================
    // Constants
    // ==========================================================================

    uint256 private constant MAX_BATCH_SIZE = 50;
    // uint256 private constant ROYALTY_BASE = 10_000; // Removed as unused (per audit I-5)
    uint256 private constant MAX_ROYALTY_PERCENTAGE = 1000; // 10% limit (per audit I-3)

    // ---- CHANGE TO 500 FOR MOCK UPGRADE ----
    uint96 public constant DEFAULT_ROYALTY_PERCENTAGE = 500;
    // ----------------------------------------

    uint8 private constant URIS_PER_TOKEN = 2;
    uint8 private constant URI_REDEEMABLE_INDEX = 0; // Added per audit G-2
    uint8 private constant URI_NOT_REDEEMABLE_INDEX = 1; // Added per audit G-2

    // ==========================================================================
    // State Variables
    // ==========================================================================

    /// @notice Address authorized to sign minting and unpairing vouchers.
    address public authoritySigner;
    /// @notice Address receiving NFTs during mint-by-trade operations.
    address public nftReceiver;
    /// @notice Maximum number of NFTs that can be minted.
    uint256 public maxSupply;
    /// @notice Base URI prepended to token URIs.
    string public baseURI;

    // IERC7160
    mapping(uint256 tokenId => string[URIS_PER_TOKEN]) private _tokenURIs; // Use constant
    mapping(uint256 tokenId => uint256 pinnedURIIndex) private _pinnedURIIndex;
    mapping(uint256 tokenId => bool hasPinnedTokenURI) private _hasPinnedTokenURI;

    // ---- NEW VARIABLES FOR MOCK UPGRADE ----
    bool public mintingPaused;
    uint256 public version;
    // ----------------------------------------

    // ==========================================================================
    // Structs & Enums
    // ==========================================================================

    /// @notice Type of mint operation being performed.
    enum MintType {
        OpenMint,
        Claim,
        Trade,
        Burn
    }

    /// @notice Data required for validating mint operations via signature.
    struct MintValidationData {
        address recipient;
        uint256 tokenId;
        uint256 tokenPrice;
        MintType mintType;
        uint256 requiredBurnOrTradeCount;
        uint256 deadline;
        bytes signature;
    }

    /// @notice URI set provided during minting, containing redeemable/non-redeemable URIs.
    struct TokenURISet {
        string uriWhenRedeemable;
        string uriWhenNotRedeemable;
        uint8 initialURIIndex;
    }

    // ==========================================================================
    // Events
    // ==========================================================================

    /// @notice Emitted when the contract is initialized.
    event Initialized(address indexed contractOwner, address indexed contractAuthoritySigner);
    /// @notice Emitted when the base URI is updated.
    event BaseURISet(string newBaseURI);
    /// @notice Emitted when the maximum supply is updated.
    event MaxSupplySet(uint256 indexed newMaxSupply);
    /// @notice Emitted when default royalties are updated.
    event RoyaltiesUpdated(address indexed receiver, uint256 indexed newPercentage);
    /// @notice Emitted when the authority signer address is updated.
    event AuthoritySignerUpdated(address indexed newAuthoritySigner);
    /// @notice Emitted when the NFT receiver address is updated.
    event NftReceiverUpdated(address indexed newNftReceiver);
    /// @notice Emitted when a story's visibility is toggled.
    event ToggleStoryVisibility(uint256 indexed tokenId, string indexed storyId, bool visible);

    // NFT lifecycle events
    /// @notice Emitted on a standard mint.
    event Minted(address indexed recipient, uint256 indexed tokenId);
    /// @notice Emitted when a token is minted by burning other tokens.
    event MintedByBurning(uint256 tokenId, uint256[] burnedTokenIds);
    /// @notice Emitted on a claim operation.
    event Claimed(uint256 indexed tokenId);
    /// @notice Emitted when a token is burned.
    event Burned(uint256 indexed tokenId);
    /// @notice Emitted when a token is minted by trading in other tokens.
    event MintedByTrading(uint256 newTokenId, uint256[] tradedTokenIds);
    /// @notice Emitted when a user increments their nonce for the purpose of invalidating a signature
    event NonceIncremented(address indexed user, uint256 nextNonce); // <<< Added

    // ---- NEW EVENT AND ERROR FOR MOCK UPGRADE ----
    event InitializedV2();
    event MintingPauseToggled(bool isPaused);

    error Admin_MintingPaused();
    // ------------------------------------

    // ==========================================================================
    // Initialization
    // ==========================================================================

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable contract (Version 1).
     */
    function initialize(
        address contractOwner,
        address contractAuthoritySigner,
        address _nftReceiver,
        uint256 _maxSupply,
        string calldata baseURI_
    ) external initializer {
        if (contractOwner == address(0) || contractAuthoritySigner == address(0) || _nftReceiver == address(0)) {
            revert Error.Admin_ZeroAddress();
        }
        __ERC721_init("Cryptoart", "CNFT");
        __ERC721Burnable_init();
        __ERC721Royalty_init();
        __ERC721Enumerable_init();
        __ERC721Pausable_init(); // <<< Updated initializer
        __Ownable_init(contractOwner);
        __Nonces_init();
        __ReentrancyGuardTransient_init(); // <<< Updated initializer

        baseURI = baseURI_;
        ERC2981Upgradeable._setDefaultRoyalty(payable(contractOwner), DEFAULT_ROYALTY_PERCENTAGE); // Uses mock's %
        nftReceiver = _nftReceiver;
        authoritySigner = contractAuthoritySigner;
        maxSupply = _maxSupply;

        emit Initialized(contractOwner, contractAuthoritySigner);
    }

    // ---- INITIALIZER FOR MOCK UPGRADE V2 ----
    /**
     * @notice Initializes the upgradeable contract (Version 2).
     */
    function initializeV2() external reinitializer(2) {
        version = 2;
        emit InitializedV2();
    }
    // -----------------------------------------

    // ==========================================================================
    // Modifiers
    // ==========================================================================

    modifier onlyTokenOwner(uint256 tokenId) {
        if (ownerOf(tokenId) != msg.sender) {
            revert Error.Token_NotOwned(tokenId, msg.sender);
        }
        _;
    }

    modifier onlyIfTokenExists(uint256 tokenId) {
        if (!_tokenExists(tokenId)) {
            revert Error.Token_DoesNotExist(tokenId);
        }
        _;
    }

    modifier validBatchSize(uint256[] calldata tokenIds) {
        uint256 length = tokenIds.length;
        if (length == 0) {
            revert Error.Batch_EmptyArray();
        }
        if (length > MAX_BATCH_SIZE) {
            revert Error.Batch_MaxSizeExceeded(length, MAX_BATCH_SIZE);
        }
        _;
    }

    modifier nonZeroAddress(address _address) {
        if (_address == address(0)) {
            revert Error.Admin_ZeroAddress();
        }
        _;
    }

    // ==========================================================================
    // Mint Operations
    // ==========================================================================

    function mint(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        if (data.mintType != MintType.OpenMint) {
            revert Error.Auth_InvalidMintType();
        }
        
        _coreMint(data, tokenUriSet);
        emit Minted(data.recipient, data.tokenId);
    }

    function claim(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        if (data.mintType != MintType.Claim) {
            revert Error.Auth_InvalidMintType();
        }
        
        _coreMint(data, tokenUriSet);
        emit Claimed(data.tokenId);
    }

    function mintWithTrade(
        uint256[] calldata tradedTokenIds,
        MintValidationData calldata data,
        TokenURISet calldata tokenUriSet
    ) external payable nonReentrant whenNotPaused validBatchSize(tradedTokenIds) {
        if (data.mintType != MintType.Trade) {
            revert Error.Auth_InvalidMintType();
        }

        if (tradedTokenIds.length != data.requiredBurnOrTradeCount) {
            revert Error.Batch_InsufficientTokenAmount(data.requiredBurnOrTradeCount, tradedTokenIds.length);
        }   
        
        _batchTransferToNftReceiver(tradedTokenIds);
        _coreMint(data, tokenUriSet);
        emit MintedByTrading(data.tokenId, tradedTokenIds);
    }

    function _batchTransferToNftReceiver(uint256[] calldata tradedTokenIds) private {
        address _nftReceiver = nftReceiver; // Cache storage read
        uint256 tradedTokensArrayLength = tradedTokenIds.length;
        for (uint256 i = 0; i < tradedTokensArrayLength;) {
            // Pass receiver address per updated base contract
            _transferToNftReceiver(tradedTokenIds[i], _nftReceiver);
            unchecked {
                ++i;
            }
        }
    }

    // Updated signature to match base contract, removed onlyTokenOwner per audit G-3
    function _transferToNftReceiver(uint256 tokenId, address _nftReceiver) private {
        // safeTransferFrom handles ownership/approval checks
        ERC721Upgradeable.safeTransferFrom(msg.sender, _nftReceiver, tokenId);
    }

    function burnAndMint(
        uint256[] calldata tokenIds,
        uint256 requiredBurnCount,
        MintValidationData calldata data,
        TokenURISet calldata tokenUriSet
    ) external payable nonReentrant whenNotPaused {
        if (data.mintType != MintType.Burn) {
            revert Error.Auth_InvalidMintType();
        }
        
        if (tokenIds.length != requiredBurnCount) {
            revert Error.Batch_InsufficientTokenAmount(requiredBurnCount, tokenIds.length);
        }
        
        _batchBurn(tokenIds);
        _coreMint(data, tokenUriSet);

        emit MintedByBurning(data.tokenId, tokenIds);
    }

    // ==========================================================================
    // Burn Operations
    // ==========================================================================

    function batchBurn(uint256[] calldata tokenIds) external whenNotPaused {
        _batchBurn(tokenIds);
    }

    // Removed duplicate check loop per audit G-6
    function _batchBurn(uint256[] calldata tokenIds) private validBatchSize(tokenIds) {
        uint256 tokenIdArrayLength = tokenIds.length;
        for (uint256 i = 0; i < tokenIdArrayLength;) {
            // Underlying burn will revert if token already burned (duplicate)
            burn(tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function burn(uint256 tokenId) public override whenNotPaused {
        // _isApprovedOrOwner check is done internally by ERC721BurnableUpgradeable.burn
        ERC2981Upgradeable._resetTokenRoyalty(tokenId);
        ERC721BurnableUpgradeable.burn(tokenId);

        // Cleanup storage per audit G-5
        delete _tokenURIs[tokenId];
        delete _pinnedURIIndex[tokenId];
        delete _hasPinnedTokenURI[tokenId];

        emit Burned(tokenId);
        emit TokenUriUnpinned(tokenId); // Emit cleanup event
    }

    // ==========================================================================
    // Metadata Management
    // ==========================================================================

    // Implemented named returns per audit G-1
    function tokenURIs(uint256 tokenId)
        external
        view
        override
        onlyIfTokenExists(tokenId)
        returns (
            uint256 index,
            string[URIS_PER_TOKEN] memory uris,
            bool pinned // Use constant
        )
    {
        index = _getTokenURIIndex(tokenId);
        uris = _tokenURIs[tokenId];
        pinned = _hasPinnedTokenURI[tokenId];
        // Explicit return removed as named returns are used
    }

    function updateMetadata(uint256 tokenId, string calldata newRedeemableURI, string calldata newNotRedeemableURI)
        external
        whenNotPaused // <<< Added whenNotPaused
        onlyOwner
        onlyIfTokenExists(tokenId)
    {
        // Use named constants per audit G-2
        _tokenURIs[tokenId][URI_REDEEMABLE_INDEX] = newRedeemableURI;
        _tokenURIs[tokenId][URI_NOT_REDEEMABLE_INDEX] = newNotRedeemableURI;
        emit MetadataUpdate(tokenId);
    }

    // Use URIS_PER_TOKEN constant per audit G-2
    function pinTokenURI(uint256 tokenId, uint256 index)
        external
        whenNotPaused // <<< Added whenNotPaused
        onlyOwner
        onlyIfTokenExists(tokenId) // <<< Added per audit L-5
    {
        if (index >= URIS_PER_TOKEN) {
            // <<< Use constant
            revert Error.Token_IndexOutOfBounds(tokenId, index, URIS_PER_TOKEN - 1);
        }
        _pinnedURIIndex[tokenId] = index;
        // _hasPinnedTokenURI should already be true if URIs are set, ensure logic flow is correct
        // If this function could be called before _setTokenURIs, we might need:
        // if (!_hasPinnedTokenURI[tokenId]) { _hasPinnedTokenURI[tokenId] = true; }
        // But typically pin is called *after* URIs are set. Let's assume _hasPinnedTokenURI is already true.

        emit TokenUriPinned(tokenId, index);
        emit MetadataUpdate(tokenId);
    }

    // Updated signature to include deadline
    function markAsRedeemable(uint256 tokenId, bytes calldata signature, uint256 deadline)
        external
        whenNotPaused // <<< Added whenNotPaused
        onlyTokenOwner(tokenId)
    {
        if (_pinnedURIIndex[tokenId] == URI_REDEEMABLE_INDEX) {
            // Use constant
            revert Error.Token_AlreadyRedeemable(tokenId);
        }

        _pinnedURIIndex[tokenId] = URI_REDEEMABLE_INDEX; // Use constant

        // Pass deadline to validation function
        _validateUnpairAuthorization(msg.sender, tokenId, signature, deadline);

        emit TokenUriPinned(tokenId, URI_REDEEMABLE_INDEX); // Use constant
        emit MetadataUpdate(tokenId);
    }

    function hasPinnedTokenURI(uint256 tokenId)
        external
        view
        onlyIfTokenExists(tokenId) // <<< Added per audit L-4
        returns (bool pinned)
    {
        return _hasPinnedTokenURI[tokenId];
    }

    function unpinTokenURI(uint256) external pure {
        revert Error.Auth_UnpinningNotSupported(); // Keep as is
    }

    // ==========================================================================
    // Story Features
    // ==========================================================================

    // Use creatorName parameter per audit L-1
    function addCollectionStory(string calldata creatorName, string calldata story)
        external
        whenNotPaused // <<< Added whenNotPaused
        onlyOwner
    {
        emit CollectionStory(msg.sender, creatorName, story);
    }

    /// @inheritdoc IStory
    function addCreatorStory(uint256 tokenId, string calldata creatorName, string calldata story)
        external
        whenNotPaused
        onlyOwner
    {
        emit CreatorStory(tokenId, msg.sender, creatorName, story);
    }

    // Use collectorName parameter per audit L-1
    function addStory(uint256 tokenId, string calldata collectorName, string calldata story)
        external
        whenNotPaused // <<< Added whenNotPaused
        onlyTokenOwner(tokenId)
    {
        emit Story(tokenId, msg.sender, collectorName, story);
    }

    function toggleStoryVisibility(uint256 tokenId, string calldata storyId, bool visible)
        external
        whenNotPaused // <<< Added whenNotPaused
    {
        // Check needs to be inside as modifier cannot access state easily for owner check
        if (ownerOf(tokenId) != msg.sender && owner() != msg.sender) {
            revert Error.Auth_Unauthorized(msg.sender);
        }
        emit ToggleStoryVisibility(tokenId, storyId, visible);
    }

    // ==========================================================================
    // Other External Functions
    // ==========================================================================

    /**
     * @notice Allows a user to increment their nonce, invalidating previous signatures. Added per audit L-3
     */
    function incrementNonce() external {
        uint256 nextNonce = NoncesUpgradeable._useNonce(msg.sender);
        emit NonceIncremented(msg.sender, nextNonce);
    }

    // ==========================================================================
    // Admin Controls
    // ==========================================================================

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    // Added royalty limit check per audit I-3
    function updateRoyalties(address payable newReceiver, uint96 newPercentage) external onlyOwner {
        if (newPercentage > MAX_ROYALTY_PERCENTAGE) {
            // Use constant
            revert Error.Admin_RoyaltyTooHigh(newPercentage, MAX_ROYALTY_PERCENTAGE);
        }
        ERC2981Upgradeable._setDefaultRoyalty(newReceiver, newPercentage);
        emit RoyaltiesUpdated(newReceiver, newPercentage);
    }

    // Added royalty limit check per audit I-3
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        if (feeNumerator > MAX_ROYALTY_PERCENTAGE) {
            // Use constant
            revert Error.Admin_RoyaltyTooHigh(feeNumerator, MAX_ROYALTY_PERCENTAGE);
        }
        ERC2981Upgradeable._setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    function updateAuthoritySigner(address newAuthoritySigner) external onlyOwner nonZeroAddress(newAuthoritySigner) {
        authoritySigner = newAuthoritySigner;
        emit AuthoritySignerUpdated(newAuthoritySigner);
    }

    function updateNftReceiver(address newNftReceiver) external onlyOwner nonZeroAddress(newNftReceiver) {
        nftReceiver = newNftReceiver;
        emit NftReceiverUpdated(newNftReceiver);
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert Error.Admin_NoWithdrawableFunds();
        }
        (bool success,) = payable(owner()).call{value: balance}(""); // Use owner() from Ownable
        if (!success) {
            revert Error.Admin_WithdrawalFailed(owner(), balance);
        }
    }

    function setMaxSupply(uint128 newMaxSupply) external onlyOwner {
        if (newMaxSupply < ERC721EnumerableUpgradeable.totalSupply()) {
            revert Error.Admin_MaxSupplyTooLow(newMaxSupply, ERC721EnumerableUpgradeable.totalSupply());
        }
        maxSupply = newMaxSupply;
        emit MaxSupplySet(newMaxSupply);
    }

    // ---- NEW FUNCTION FOR MOCK UPGRADE ----
    function toggleMintingPause() external onlyOwner {
        mintingPaused = !mintingPaused;
        emit MintingPauseToggled(mintingPaused);
    }
    // ------------------------------------

    // ==========================================================================
    // Internal Core Mint Functions
    // ==========================================================================

    // Keep mock's mintingPaused check
    function _coreMint(MintValidationData calldata data, TokenURISet calldata tokenUriSet) private {
        if (mintingPaused) {
            // Mock upgrade check
            revert Admin_MintingPaused();
        }
        _validateMintAuthorization(data, tokenUriSet);
        // Renamed for consistency with base contract's likely name
        _setTokenURIs(
            data.tokenId, tokenUriSet.uriWhenRedeemable, tokenUriSet.uriWhenNotRedeemable, tokenUriSet.initialURIIndex
        );
        ERC721Upgradeable._safeMint(data.recipient, data.tokenId);
        _refundExcessPayment(data.tokenPrice);
    }

    function _validateMintAuthorization(MintValidationData calldata data, TokenURISet calldata uriParams) private {
        _validatePayment(data.tokenPrice);
        _validateTokenRequirements(data.tokenId);
        _validateSignature(data, uriParams);
    }

    function _validatePayment(uint256 tokenPrice) private view {
        if (msg.value < tokenPrice) {
            revert Error.Mint_InsufficientPayment(tokenPrice, msg.value);
        }
    }

    function _validateTokenRequirements(uint256 tokenId) private view {
        if (_tokenExists(tokenId)) {
            revert Error.Token_AlreadyMinted(tokenId);
        }
        if (ERC721EnumerableUpgradeable.totalSupply() >= maxSupply) {
            revert Error.Mint_ExceedsTotalSupply(tokenId, totalSupply());
        }
    }

    // Updated validation per I-1, I-2
    function _validateSignature(MintValidationData calldata data, TokenURISet calldata uriParams) private {
        if (block.timestamp > data.deadline) {
            revert Error.Auth_SignatureExpired(data.deadline, block.timestamp); // Match error params if changed
        }

        bytes32 contentHash = keccak256(
            abi.encode(
                data.recipient,
                data.tokenId,
                data.mintType,
                data.tokenPrice,
                data.requiredBurnOrTradeCount,
                uriParams.uriWhenRedeemable,
                uriParams.uriWhenNotRedeemable,
                uriParams.initialURIIndex,
                NoncesUpgradeable._useNonce(data.recipient),
                block.chainid, 
                data.deadline,
                address(this)
            )
        );
        if (!_isValidSignature(contentHash, data.signature)) {
            revert Error.Auth_UnauthorizedSigner();
        }
    }

    function _isValidSignature(bytes32 contentHash, bytes calldata signature) private view returns (bool) {
        address signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(contentHash), signature);
        return signer == authoritySigner;
    }

    // Renamed, uses constants per G-2
    function _setTokenURIs(
        uint256 tokenId,
        string calldata uriWhenRedeemable,
        string calldata uriWhenNotRedeemable,
        uint256 initialURIIndex
    ) private {
        // Check if already set only matters if mint logic doesn't prevent re-entry
        // _validateTokenRequirements handles this, so check likely redundant, but keeping for safety:
        if (bytes(_tokenURIs[tokenId][URI_REDEEMABLE_INDEX]).length != 0) {
            revert Error.Token_URIAlreadySet(tokenId);
        }
        if (initialURIIndex >= URIS_PER_TOKEN) {
            revert Error.Token_InvalidDefaultIndex(initialURIIndex);
        }

        _tokenURIs[tokenId][URI_REDEEMABLE_INDEX] = uriWhenRedeemable;
        _tokenURIs[tokenId][URI_NOT_REDEEMABLE_INDEX] = uriWhenNotRedeemable;
        _pinnedURIIndex[tokenId] = initialURIIndex;
        _hasPinnedTokenURI[tokenId] = true;

        emit TokenUriPinned(tokenId, initialURIIndex);
        emit MetadataUpdate(tokenId);
    }

    function _refundExcessPayment(uint256 tokenPrice) private {
        uint256 excess = msg.value - tokenPrice;
        if (excess > 0) {
            (bool success,) = payable(msg.sender).call{value: excess}("");
            if (!success) {
                revert Error.Mint_RefundFailed(msg.sender, excess);
            }
        }
    }

    function _tokenExists(uint256 _tokenId) private view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    // ==========================================================================
    // Internal Metadata Functions
    // ==========================================================================

    // Updated validation per I-1, I-2
    function _validateUnpairAuthorization(address minter, uint256 tokenId, bytes calldata signature, uint256 deadline)
        private
    {
        if (block.timestamp > deadline) {
            revert Error.Auth_SignatureExpired(deadline, block.timestamp); // Match error params if changed
        }

        bytes32 contentHash = keccak256(
            abi.encode(
                minter,
                tokenId,
                NoncesUpgradeable._useNonce(minter),
                block.chainid, // <<< Added chainId
                deadline, // <<< Added deadline
                address(this)
            )
        );
        if (!_isValidSignature(contentHash, signature)) {
            revert Error.Auth_UnauthorizedSigner();
        }
    }

    // Simplified per base contract update (always use pinned index)
    function _getTokenURIIndex(uint256 tokenId) private view returns (uint256) {
        return _pinnedURIIndex[tokenId];
    }

    // ==========================================================================
    // Required Overrides By Solidity
    // ==========================================================================

    // Updated override list
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC7160).interfaceId || interfaceId == type(IERC4906).interfaceId
            || super.supportsInterface(interfaceId);
    }

    // Optimized using storage ref per audit G-4
    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable)
        onlyIfTokenExists(tokenId)
        returns (string memory)
    {
        // Use storage pointer to avoid copying entire array
        string storage uri = _tokenURIs[tokenId][_getTokenURIIndex(tokenId)];

        if (bytes(uri).length == 0) {
            revert Error.Token_NoURIFound(tokenId);
        }

        // Use base function to get base URI
        string memory currentBaseURI = _baseURI();
        return bytes(currentBaseURI).length > 0 ? string.concat(currentBaseURI, uri) : uri;
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    // Updated override list, ensure body calls super
    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable) // Added Pausable & Burnable
        returns (address)
    {
        return super._update(to, tokenId, auth); // Call super to ensure all parent logic runs
    }

    // Ensure override list is correct (Pausable doesn't override this)
    function _increaseBalance(address account, uint128 amount)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        // Call super if necessary, or specific parent if OZ structure demands it
        super._increaseBalance(account, amount);
        // ERC721EnumerableUpgradeable._increaseBalance(account, amount); // Check OZ impl detail if super() fails
    }
}
