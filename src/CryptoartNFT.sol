// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC721Upgradeable, IERC165} from "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import {ERC721BurnableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import {ERC721EnumerableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import {ERC721PausableUpgradeable} from
    "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721PausableUpgradeable.sol";
import {
    ERC721RoyaltyUpgradeable,
    ERC2981Upgradeable
} from "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import {NoncesUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {ReentrancyGuardTransientUpgradeable} from
    "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardTransientUpgradeable.sol";
import {IERC7160} from "./interfaces/IERC7160.sol";
import {IStory} from "./interfaces/IStory.sol";
import {Error} from "./libraries/Error.sol";

/**
 * @title Cryptoart NFT Collection Contract
 * @author Cryptoart Team
 * @notice Manages the Cryptoart NFT collection, supporting voucher-based minting,
 * pairing with physical items (via IERC7160), story inscriptions (IStory),
 * burning, trading, and ERC2981 royalties. Uses OpenZeppelin upgradeable contracts.
 */
contract CryptoartNFT is
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
    /// @notice Default royalty percentage basis points (2.5%).
    uint96 public constant DEFAULT_ROYALTY_PERCENTAGE = 250;
    uint256 private constant MAX_ROYALTY_PERCENTAGE = 1000; // 10% (1000 basis points)
    uint8 private constant URIS_PER_TOKEN = 2;
    uint8 private constant URI_REDEEMABLE_INDEX = 0;
    uint8 private constant URI_NOT_REDEEMABLE_INDEX = 1;

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
    mapping(uint256 tokenId => string[URIS_PER_TOKEN] tokenURIs) private _tokenURIs;
    mapping(uint256 tokenId => uint256 pinnedURIIndex) private _pinnedURIIndex;
    mapping(uint256 tokenId => bool hasPinnedTokenURI) private _hasPinnedTokenURI;

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
    event NonceIncremented(address user, uint256 nextAvailableNonce);

    // ==========================================================================
    // Initialization
    // ==========================================================================

    /// @notice Locks the contract, preventing any future re-initialization.
    /// @dev See OpenZeppelin Initializable documentation.
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the upgradeable contract.
     * @dev Sets initial owner, signer, receiver, supply, base URI, and default royalties. Can only be called once.
     * @param contractOwner The initial owner of the contract.
     * @param contractAuthoritySigner The initial address authorized to sign vouchers.
     * @param _nftReceiver The initial address to receive traded NFTs.
     * @param _maxSupply The maximum number of NFTs allowed.
     * @param baseURI_ The initial base URI for token metadata.
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
        __ERC721Pausable_init();
        __Ownable_init(contractOwner);
        __Nonces_init();
        __ReentrancyGuardTransient_init();

        baseURI = baseURI_;
        ERC2981Upgradeable._setDefaultRoyalty(payable(contractOwner), DEFAULT_ROYALTY_PERCENTAGE);
        nftReceiver = _nftReceiver;
        authoritySigner = contractAuthoritySigner;
        maxSupply = _maxSupply;

        emit Initialized(contractOwner, contractAuthoritySigner);
    }

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
        if (tokenIds.length == 0) {
            revert Error.Batch_EmptyArray();
        }
        if (tokenIds.length > MAX_BATCH_SIZE) {
            revert Error.Batch_MaxSizeExceeded(tokenIds.length, MAX_BATCH_SIZE);
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

    /**
     * @notice Mints a new token using a signed voucher and payment.
     * @dev Requires a valid signature from the authority signer and sufficient payment.
     * @param data Mint validation data including recipient, tokenId, price, type, and signature.
     * @param tokenUriSet Initial URIs (redeemable/non-redeemable) for the token.
     */
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

    /**
     * @notice Claims a new token using a signed voucher and payment.
     * @dev Functionally similar to mint, distinguished by event emission.
     * @param data Mint validation data including recipient, tokenId, price, type, and signature.
     * @param tokenUriSet Initial URIs (redeemable/non-redeemable) for the token.
     */
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

    /**
     * @notice Mints a new token by trading in existing tokens, using a signed voucher and payment.
     * @dev Transfers specified `tradedTokenIds` from sender to `nftReceiver`.
     * @param tradedTokenIds Array of token IDs owned by the sender to be traded.
     * @param data Mint validation data including recipient, tokenId, price, type, and signature.
     * @param tokenUriSet Initial URIs (redeemable/non-redeemable) for the new token.
     */
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
        address _nftReceiver = nftReceiver;
        for (uint256 i; i < tradedTokenIds.length;) {
            _transferToNftReceiver(tradedTokenIds[i], _nftReceiver);
            unchecked {
                ++i;
            }
        }
    }

    function _transferToNftReceiver(uint256 tokenId, address _nftReceiver) private {
        ERC721Upgradeable.safeTransferFrom(msg.sender, _nftReceiver, tokenId);
    }

    /**
     * @notice Mints a new token by burning existing tokens, using a signed voucher and payment.
     * @dev Burns the specified `tokenIds` owned by the sender.
     * @param tokenIds Array of token IDs owned by the sender to be burned.
     * @param data Mint validation data including recipient, tokenId, price, type, and signature.
     * @param tokenUriSet Initial URIs (redeemable/non-redeemable) for the new token.
     */
    function burnAndMint(
        uint256[] calldata tokenIds,
        MintValidationData calldata data,
        TokenURISet calldata tokenUriSet
    ) external payable nonReentrant whenNotPaused {
        if (data.mintType != MintType.Burn) {
            revert Error.Auth_InvalidMintType();
        }
        if (tokenIds.length != data.requiredBurnOrTradeCount) {
            revert Error.Batch_InsufficientTokenAmount(data.requiredBurnOrTradeCount, tokenIds.length);
        }
        _batchBurn(tokenIds);
        _coreMint(data, tokenUriSet);
        emit MintedByBurning(data.tokenId, tokenIds);
    }

    // ==========================================================================
    // Burn Operations
    // ==========================================================================

    /**
     * @notice Burns multiple tokens owned by the sender.
     * @dev Reverts if the array is empty, exceeds max batch size, or contains duplicates.
     * @param tokenIds Array of token IDs to burn.
     */
    function batchBurn(uint256[] calldata tokenIds) external whenNotPaused {
        _batchBurn(tokenIds);
    }

    function _batchBurn(uint256[] calldata tokenIds) private validBatchSize(tokenIds) {
        for (uint256 i; i < tokenIds.length;) {
            burn(tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    /**
     * @notice Burns a single token.
     * @dev Overrides ERC721Burnable.burn. Requires caller to be owner or approved. Resets token royalty.
     * @param tokenId The token ID to burn.
     */
    function burn(uint256 tokenId) public override whenNotPaused {
        // require sender is owner or approved has been removed as the internal burn function already checks this
        ERC2981Upgradeable._resetTokenRoyalty(tokenId);
        ERC721BurnableUpgradeable.burn(tokenId);

        delete _tokenURIs[tokenId];
        delete _pinnedURIIndex[tokenId];
        delete _hasPinnedTokenURI[tokenId];

        emit Burned(tokenId);
        emit TokenUriUnpinned(tokenId);
    }

    // ==========================================================================
    // Metadata Management
    // ==========================================================================

    // @inheritdoc IERC721MultiMetadata.tokenURIs
    function tokenURIs(uint256 tokenId)
        external
        view
        override
        onlyIfTokenExists(tokenId)
        returns (uint256 index, string[URIS_PER_TOKEN] memory uris, bool isPinned)
    {
        index = _getTokenURIIndex(tokenId);
        uris = _tokenURIs[tokenId];
        isPinned = _hasPinnedTokenURI[tokenId];
    }

    /**
     * @notice Updates both URIs for a given token. Owner only.
     * @dev Allows administrative correction or update of metadata URIs. Emits MetadataUpdate.
     * @param tokenId The token ID to update.
     * @param newRedeemableURI The new URI for the redeemable state.
     * @param newNotRedeemableURI The new URI for the non-redeemable state.
     */
    function updateMetadata(uint256 tokenId, string calldata newRedeemableURI, string calldata newNotRedeemableURI)
        external
        whenNotPaused
        onlyOwner
        onlyIfTokenExists(tokenId)
    {
        _tokenURIs[tokenId][URI_REDEEMABLE_INDEX] = newRedeemableURI;
        _tokenURIs[tokenId][URI_NOT_REDEEMABLE_INDEX] = newNotRedeemableURI;
        emit MetadataUpdate(tokenId); // ERC4906
    }

    // @inheritdoc IERC721MultiMetadata.pinTokenURI
    // pin the index-0 URI of the token, which has redeemable attribute on true
    // pin the index-1 URI of the token, which has redeemable attribute on false
    function pinTokenURI(uint256 tokenId, uint256 index) external whenNotPaused onlyIfTokenExists(tokenId) onlyOwner {
        if (index >= _tokenURIs[tokenId].length) {
            revert Error.Token_IndexOutOfBounds(tokenId, index, URIS_PER_TOKEN - 1);
        }

        _pinnedURIIndex[tokenId] = index;

        emit TokenUriPinned(tokenId, index);
        emit MetadataUpdate(tokenId);
    }

    /**
     * @notice Marks a token as redeemable (pins URI index 0) by the token owner. Requires signature.
     * @dev Requires a valid signature from the authority signer
     * @param tokenId The token ID to mark as redeemable.
     * @param signature A signature from the authority signer authorizing the unpairing.
     */
    function markAsRedeemable(uint256 tokenId, bytes calldata signature, uint256 deadline)
        external
        onlyTokenOwner(tokenId)
    {
        if (_pinnedURIIndex[tokenId] == URI_REDEEMABLE_INDEX) {
            revert Error.Token_AlreadyRedeemable(tokenId);
        }

        _pinnedURIIndex[tokenId] = URI_REDEEMABLE_INDEX;
        _validateUnpairAuthorization(msg.sender, tokenId, signature, deadline);

        emit TokenUriPinned(tokenId, URI_REDEEMABLE_INDEX);
        emit MetadataUpdate(tokenId);
    }

    // @inheritdoc IERC721MultiMetadata.hasPinnedTokenURI
    function hasPinnedTokenURI(uint256 tokenId) external view onlyIfTokenExists(tokenId) returns (bool) {
        return _hasPinnedTokenURI[tokenId];
    }

    // @inheritdoc IERC721MultiMetadata.unpinTokenURI
    function unpinTokenURI(uint256) external pure {
        revert Error.Auth_UnpinningNotSupported();
    }
   
   // @inheritdoc IERC4906.MetadataUpdate  
    function triggerMetadataUpdate(uint256 _tokenId) external onlyOwner {
        emit MetadataUpdate(_tokenId);
    }

    // ==========================================================================
    // Story Features
    // ==========================================================================

    /// @inheritdoc IStory
    function addCollectionStory(string calldata creatorName, string calldata story) external whenNotPaused onlyOwner {
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

    /// @inheritdoc IStory
    function addStory(uint256 tokenId, string calldata collectorName, string calldata story)
        external
        whenNotPaused
        onlyTokenOwner(tokenId)
    {
        emit Story(tokenId, msg.sender, collectorName, story);
    }

    /**
     * @notice Emits an event signaling a change in visibility for a story. Token owner or admin only.
     * @dev Off-chain listeners interpret this event to control story display.
     * @param tokenId The token ID the story belongs to.
     * @param storyId An identifier for the specific story (derived off-chain from event logs).
     * @param visible The desired visibility state.
     */
    function toggleStoryVisibility(uint256 tokenId, string calldata storyId, bool visible) external whenNotPaused {
        if (ownerOf(tokenId) != msg.sender && msg.sender != owner()) {
            revert Error.Auth_Unauthorized(msg.sender);
        }
        emit ToggleStoryVisibility(tokenId, storyId, visible);
    }

    // ==========================================================================
    // Other External Functions
    // ==========================================================================

    /**
     * @notice Allows a user to increment their nonce, invalidating any previous off-chain signatures
     */
    function incrementNonce() external {
        NoncesUpgradeable._useNonce(msg.sender);
        emit NonceIncremented(msg.sender, nonces(msg.sender));
    }

    // ==========================================================================
    // Admin Controls
    // ==========================================================================

    /**
     * @notice Pauses the contract, halting mint, burn, and transfer operations. Owner only.
     * @dev Uses OpenZeppelin Pausable module.
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses the contract, resuming normal operations. Owner only.
     * @dev Uses OpenZeppelin Pausable module.
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Updates the default royalty receiver and percentage. Owner only.
     * @dev Royalty percentage must not exceed MAX_ROYALTY_PERCENTAGE (10%).
     * @param newReceiver The new address to receive default royalties.
     * @param newPercentage The new default royalty percentage in basis points.
     */
    function updateRoyalties(address payable newReceiver, uint96 newPercentage) external onlyOwner {
        if (newPercentage > MAX_ROYALTY_PERCENTAGE) {
            revert Error.Admin_RoyaltyTooHigh(newPercentage, MAX_ROYALTY_PERCENTAGE);
        }
        ERC2981Upgradeable._setDefaultRoyalty(newReceiver, newPercentage);
        emit RoyaltiesUpdated(newReceiver, newPercentage);
    }

    /**
     * @notice Sets a specific royalty for an individual token. Owner only.
     * @dev Overrides the default royalty for the specified tokenId.
     * @param tokenId The token ID to set royalty for.
     * @param receiver The address to receive royalties for this token.
     * @param feeNumerator The royalty amount in basis points for this token.
     */
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
        if (feeNumerator > MAX_ROYALTY_PERCENTAGE) {
            revert Error.Admin_RoyaltyTooHigh(feeNumerator, MAX_ROYALTY_PERCENTAGE);
        }
        ERC2981Upgradeable._setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @notice Updates the base URI for token metadata. Owner only.
     * @param newBaseURI The new base URI string.
     */
    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    /**
     * @notice Updates the address authorized to sign vouchers. Owner only.
     * @dev Cannot be set to the zero address.
     * @param newAuthoritySigner The new address for the authority signer.
     */
    function updateAuthoritySigner(address newAuthoritySigner) external onlyOwner nonZeroAddress(newAuthoritySigner) {
        authoritySigner = newAuthoritySigner;
        emit AuthoritySignerUpdated(newAuthoritySigner);
    }

    /**
     * @notice Updates the address that receives traded-in NFTs. Owner only.
     * @dev Cannot be set to the zero address.
     * @param newNftReceiver The new address for the NFT receiver.
     */
    function updateNftReceiver(address newNftReceiver) external onlyOwner nonZeroAddress(newNftReceiver) {
        nftReceiver = newNftReceiver;
        emit NftReceiverUpdated(newNftReceiver);
    }

    /**
     * @notice Withdraws the entire ETH balance of the contract to the owner. Owner only.
     * @dev Reverts if the balance is zero or if the transfer fails.
     */
    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;
        if (balance == 0) {
            revert Error.Admin_NoWithdrawableFunds();
        }
        (bool success,) = payable(msg.sender).call{value: balance}(""); // Send to owner
        if (!success) {
            revert Error.Admin_WithdrawalFailed(msg.sender, balance);
        }
    }

    /**
     * @notice Sets the maximum supply of NFTs. Owner only.
     * @param newMaxSupply The new maximum supply value.
     */
    function setMaxSupply(uint128 newMaxSupply) external onlyOwner {
        if (newMaxSupply < ERC721EnumerableUpgradeable.totalSupply()) {
            revert Error.Admin_MaxSupplyTooLow(newMaxSupply, ERC721EnumerableUpgradeable.totalSupply());
        }
        maxSupply = newMaxSupply;
        emit MaxSupplySet(newMaxSupply);
    }

    // ==========================================================================
    // Internal Core Mint Functions
    // ==========================================================================

    function _coreMint(MintValidationData calldata data, TokenURISet calldata tokenUriSet) private {
        _validateMintAuthorization(data, tokenUriSet);
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

    function _validateSignature(MintValidationData calldata data, TokenURISet calldata uriParams) private {
        if (block.timestamp > data.deadline) {
            revert Error.Auth_SignatureExpired(data.deadline, block.timestamp);
        }

        bytes32 contentHash = keccak256(
            abi.encode(
                data.recipient,
                data.tokenId,
                data.tokenPrice,
                data.mintType,
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

    /// @notice Sets base URIs for the token
    // contract can only set first and second URIs for metadata redeemable on true and false
    function _setTokenURIs(
        uint256 tokenId,
        string calldata uriWhenRedeemable,
        string calldata uriWhenNotRedeemable,
        uint256 initialURIIndex
    ) private {
        if (bytes(_tokenURIs[tokenId][0]).length != 0) {
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

    function _validateUnpairAuthorization(address minter, uint256 tokenId, bytes calldata signature, uint256 deadline)
        private
    {
        if (block.timestamp > deadline) {
            revert Error.Auth_SignatureExpired(deadline, block.timestamp);
        }

        bytes32 contentHash = keccak256(
            abi.encode(minter, tokenId, NoncesUpgradeable._useNonce(minter), block.chainid, deadline, address(this))
        );
        if (!_isValidSignature(contentHash, signature)) {
            revert Error.Auth_UnauthorizedSigner();
        }
    }

    // @notice Returns the pinned URI index
    function _getTokenURIIndex(uint256 tokenId) private view returns (uint256) {
        return _pinnedURIIndex[tokenId];
    }

    // ==========================================================================
    // Required Overrides By Solidity
    // ==========================================================================

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC7160).interfaceId || interfaceId == type(IERC4906).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable)
        onlyIfTokenExists(tokenId)
        returns (string memory fullURI)
    {
        string storage uri = _tokenURIs[tokenId][_getTokenURIIndex(tokenId)];

        if (bytes(uri).length == 0) {
            revert Error.Token_NoURIFound(tokenId);
        }

        fullURI = string.concat(_baseURI(), uri);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable)
        returns (address)
    {
        return super._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        ERC721EnumerableUpgradeable._increaseBalance(account, amount);
    }
}
