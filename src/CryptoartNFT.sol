// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin-contracts-5.0.2/interfaces/IERC4906.sol";
import "@openzeppelin-contracts-5.0.2/utils/cryptography/ECDSA.sol";
import "@openzeppelin-contracts-5.0.2/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/utils/NoncesUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/utils/PausableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/utils/ReentrancyGuardUpgradeable.sol";
import {IERC7160} from "./interfaces/IERC7160.sol";
import {IStory} from "./interfaces/IStory.sol";
import {Error} from "./libraries/Error.sol";

contract CryptoartNFT is
    IERC7160,
    IERC4906,
    ERC721RoyaltyUpgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    NoncesUpgradeable,
    IStory,
    ReentrancyGuardUpgradeable
{
    using Strings for uint256;
    using Strings for address;

    // ==========================================================================
    // Constants
    // ==========================================================================

    uint256 private constant MAX_BATCH_SIZE = 50;
    uint256 private constant ROYALTY_BASE = 10_000; // as per EIP-2981 (10000 = 100%, so 250 = 2.5%)
    uint96 public constant DEFAULT_ROYALTY_PERCENTAGE = 250; // default royalty percentage 2.5%
    uint8 private constant URIS_PER_TOKEN = 2;

    // ==========================================================================
    // State Variables
    // ==========================================================================

    address public authoritySigner;
    address public nftReceiver; // wallet in charge of receiving tokens transferred for minting
    uint256 public maxSupply;
    string public baseURI;

    // IERC7160
    mapping(uint256 => string[2]) private _tokenURIs;
    mapping(uint256 => uint256) private _pinnedURIIndices;
    mapping(uint256 => bool) private _hasPinnedTokenURI;

    // ==========================================================================
    // Structs & Enums
    // ==========================================================================

    enum MintType {
        OpenMint,
        Whitelist,
        Claim,
        Burn
    }

    struct MintValidationData {
        address recipient;
        uint256 tokenId;
        uint256 tokenPrice;
        MintType mintType;
        bytes signature;
    }

    struct TokenURISet {
        string uriWhenRedeemable;
        string uriWhenNotRedeemable;
        uint8 redeemableDefaultIndex;
    }

    // ==========================================================================
    // Events
    // ==========================================================================

    event Initialized(address indexed contractOwner, address indexed contractAuthoritySigner);
    event BaseURISet(string newBaseURI);
    event MaxSupplySet(uint256 indexed newMaxSupply);
    event RoyaltiesUpdated(address indexed receiver, uint256 indexed newPercentage);
    event AuthoritySignerUpdated(address indexed newAuthoritySigner);
    event NftReceiverUpdated(address indexed newNftReceiver);
    event ToggleStoryVisibility(uint256 indexed tokenId, string indexed storyId, bool visible);

    // NFT lifecycle events
    event Minted(address indexed recipient, uint256 indexed tokenId);
    event MintedByBurning(uint256 tokenId, uint256[] burnedTokenIds);
    event Claimed(uint256 indexed tokenId);
    event Burned(uint256 indexed tokenId);
    event MintedByTrading(uint256 newTokenId, uint256[] tradedTokenIds);

    // ==========================================================================
    // Initialization
    // ==========================================================================

    /// @notice Locks the contract, preventing any future re-initialization.
    /// @dev [See more](https://docs.openzeppelin.com/contracts/5.x/api/proxy#Initializable-_disableInitializers--).
    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

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
        __ERC721Royalty_init();
        __ERC721Enumerable_init();
        __Ownable_init(contractOwner);
        __Pausable_init();
        __Nonces_init();

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
        _coreMint(data, tokenUriSet);
        emit Minted(data.recipient, data.tokenId);
    }

    function claim(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
        external
        payable
        nonReentrant
        whenNotPaused
    {
        _coreMint(data, tokenUriSet);
        emit Claimed(data.tokenId);
    }

    function mintWithTrade(
        uint256[] calldata tradedTokenIds,
        MintValidationData calldata data,
        TokenURISet calldata tokenUriSet
    ) external payable nonReentrant whenNotPaused validBatchSize(tradedTokenIds) {
        _batchTransferToNftReceiver(tradedTokenIds);
        _coreMint(data, tokenUriSet);
        emit MintedByTrading(data.tokenId, tradedTokenIds);
    }

    function _batchTransferToNftReceiver(uint256[] calldata tradedTokenIds) private {
        uint256 tradedTokensArrayLength = tradedTokenIds.length;
        for (uint256 i = 0; i < tradedTokensArrayLength;) {
            _transferToNftReceiver(tradedTokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function _transferToNftReceiver(uint256 tokenId) private onlyTokenOwner(tokenId) {
        ERC721Upgradeable.safeTransferFrom(msg.sender, nftReceiver, tokenId);
    }

    function burnAndMint(
        uint256[] calldata tokenIds,
        uint256 requiredBurnCount,
        MintValidationData calldata data,
        TokenURISet calldata tokenUriSet
    ) external payable nonReentrant whenNotPaused {
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

    function batchBurn(uint256[] calldata tokenIds) external nonReentrant whenNotPaused {
        _batchBurn(tokenIds);
    }

    function _batchBurn(uint256[] calldata tokenIds) private validBatchSize(tokenIds) {
        uint256 tokenIdArrayLength = tokenIds.length;
        for (uint256 i = 0; i < tokenIdArrayLength - 1; ++i) {
            for (uint256 j = i + 1; j < tokenIdArrayLength; ++j) {
                if (tokenIds[i] == tokenIds[j]) revert Error.Batch_DuplicateTokenIds(tokenIds[i]);
            }
        }
        for (uint256 i = 0; i < tokenIdArrayLength;) {
            _burnToken(tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    function burn(uint256 tokenId) external nonReentrant whenNotPaused {
        _burnToken(tokenId);
    }

    function _burnToken(uint256 tokenId) private onlyTokenOwner(tokenId) {
        ERC721Upgradeable._burn(tokenId);
        ERC2981Upgradeable._resetTokenRoyalty(tokenId);
        emit Burned(tokenId);
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
        returns (uint256 index, string[2] memory uris, bool pinned)
    {
        return (_getTokenURIIndex(tokenId), _tokenURIs[tokenId], _hasPinnedTokenURI[tokenId]);
    }

    function updateMetadata(uint256 tokenId, string calldata newRedeemableURI, string calldata newNotRedeemableURI)
        external
        onlyOwner
        onlyIfTokenExists(tokenId)
    {
        _tokenURIs[tokenId][0] = newRedeemableURI;
        _tokenURIs[tokenId][1] = newNotRedeemableURI;
        emit MetadataUpdate(tokenId);
    }

    // @inheritdoc IERC721MultiMetadata.pinTokenURI
    // pin the index-0 URI of the token, which has redeemable attribute on true
    // pin the index-1 URI of the token, which has redeemable attribute on false
    function pinTokenURI(uint256 tokenId, uint256 index) external onlyOwner {
        if (index >= _tokenURIs[tokenId].length) {
            revert Error.Token_IndexOutOfBounds(tokenId, index, _tokenURIs[tokenId].length - 1);
        }

        _pinnedURIIndices[tokenId] = index;
        _hasPinnedTokenURI[tokenId] = true;

        emit TokenUriPinned(tokenId, index);
        emit MetadataUpdate(tokenId);
    }

    // holder unpairs the token in order to redeem physically again
    // pin the first URI of the token, which has redeemable attribute on true
    function markAsRedeemable(uint256 tokenId, bytes calldata signature) external onlyTokenOwner(tokenId) {
        _pinnedURIIndices[tokenId] = 0;
        _hasPinnedTokenURI[tokenId] = true;

        _validateUnpairAuthorization(msg.sender, tokenId, signature);

        emit TokenUriPinned(tokenId, 0);
        emit MetadataUpdate(tokenId);
    }

    // @inheritdoc IERC721MultiMetadata.hasPinnedTokenURI
    function hasPinnedTokenURI(uint256 tokenId) external view returns (bool pinned) {
        return _hasPinnedTokenURI[tokenId];
    }

    // @inheritdoc IERC721MultiMetadata.unpinTokenURI
    function unpinTokenURI(uint256) external pure {
        // TODO: implement
        return;
    }

    // ==========================================================================
    // Story Features
    // ==========================================================================

    // TODO: Appropriately add the implementations to the story functions

    /// @inheritdoc IStory
    function addCreatorStory(
        uint256 tokenId,
        string calldata,
        /*creatorName*/
        string calldata story
    ) external onlyTokenOwner(tokenId) {
        emit CreatorStory(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addStory(
        uint256 tokenId,
        string calldata,
        /*collectorName*/
        string calldata story
    ) external onlyTokenOwner(tokenId) {
        emit Story(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    function toggleStoryVisibility(uint256 tokenId, string calldata storyId, bool visible)
        external
        onlyTokenOwner(tokenId)
        onlyIfTokenExists(tokenId)
    {
        emit ToggleStoryVisibility(tokenId, storyId, visible);
    }

    function addCollectionStory(string calldata creatorName, string calldata story) external override {}

    // ==========================================================================
    // Admin Controls
    // ==========================================================================

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function updateRoyalties(address payable newReceiver, uint96 newPercentage) external onlyOwner {
        if (newPercentage > ROYALTY_BASE) {
            revert Error.Admin_RoyaltyTooHigh(newPercentage, ROYALTY_BASE);
        }

        ERC2981Upgradeable._setDefaultRoyalty(newReceiver, newPercentage);

        emit RoyaltiesUpdated(newReceiver, newPercentage);
    }

    /// @dev Set token-specific royalties
    function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner {
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
        (bool success,) = payable(msg.sender).call{value: balance}("");
        if (!success) {
            revert Error.Admin_WithdrawalFailed(msg.sender, balance);
        }
    }

    function setMaxSupply(uint128 newMaxSupply) external onlyOwner {
        maxSupply = newMaxSupply;
        emit MaxSupplySet(newMaxSupply);
    }

    // ==========================================================================
    // Internal Core Mint Functions
    // ==========================================================================

    function _coreMint(MintValidationData calldata data, TokenURISet calldata tokenUriSet) private {
        _validateMintAuthorization(data, tokenUriSet);
        _setTokenMetadata(
            data.tokenId,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.redeemableDefaultIndex
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
        bytes32 contentHash = keccak256(
            abi.encode(
                data.recipient,
                data.tokenId,
                data.mintType,
                data.tokenPrice,
                uriParams.uriWhenRedeemable,
                uriParams.uriWhenNotRedeemable,
                uriParams.redeemableDefaultIndex,
                NoncesUpgradeable._useNonce(data.recipient),
                address(this)
            )
        );
        if (!_isValidSignature(contentHash, data.signature)) {
            revert Error.Auth_UnauthorizedSigner();
        }
    }

    function _isValidSignature(bytes32 contentHash, bytes calldata signature) private view returns (bool isValidSignature) {
        address signer = ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(contentHash), signature);
        isValidSignature = signer == authoritySigner;
    }

    /// @notice Sets base metadata for the token
    // contract can only set first and second URIs for metadata redeemable on true and false
    function _setTokenMetadata(
        uint256 tokenId,
        string calldata uriWhenRedeemable,
        string calldata uriWhenNotRedeemable,
        uint256 redeemableDefaultIndex
    ) private {
        if (bytes(_tokenURIs[tokenId][0]).length != 0) {
            revert Error.Token_URIAlreadySet(tokenId);
        }
        if (redeemableDefaultIndex >= URIS_PER_TOKEN) {
            revert Error.Token_InvalidDefaultIndex(redeemableDefaultIndex);
        }

        _tokenURIs[tokenId][0] = uriWhenRedeemable;
        _tokenURIs[tokenId][1] = uriWhenNotRedeemable;
        _pinnedURIIndices[tokenId] = redeemableDefaultIndex;
        _hasPinnedTokenURI[tokenId] = true;

        emit TokenUriPinned(tokenId, redeemableDefaultIndex);
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

    function _tokenExists(uint256 _tokenId) private view returns (bool tokenExists) {
        tokenExists = _ownerOf(_tokenId) != address(0);
    }

    // ==========================================================================
    // Internal Metadata Functions
    // ==========================================================================

    function _validateUnpairAuthorization(address minter, uint256 tokenId, bytes calldata signature) private {
        bytes32 contentHash = keccak256(abi.encode(minter, tokenId, NoncesUpgradeable._useNonce(minter), address(this)));
        if (!_isValidSignature(contentHash, signature)) {
            revert Error.Auth_UnauthorizedSigner();
        }
    }

    // @notice Returns the pinned URI index or the last token URI index (length - 1).
    function _getTokenURIIndex(uint256 tokenId) private view returns (uint256 tokenURIIndex) {
        tokenURIIndex = _hasPinnedTokenURI[tokenId] ? _pinnedURIIndices[tokenId] : _tokenURIs[tokenId].length - 1;
    }

    // ==========================================================================
    // Required Overrides By Solidity
    // ==========================================================================

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, ERC721RoyaltyUpgradeable, ERC721EnumerableUpgradeable)
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
        returns (string memory)
    {
        uint256 index = _getTokenURIIndex(tokenId);
        string[2] memory uris = _tokenURIs[tokenId];
        string memory uri = uris[index];

        if (bytes(uri).length == 0) {
            revert Error.Token_NoURIFound(tokenId);
        }
        return string.concat(_baseURI(), uri);
    }

    function _baseURI() internal view override returns (string memory) {
        return baseURI;
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        return ERC721EnumerableUpgradeable._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount)
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        ERC721EnumerableUpgradeable._increaseBalance(account, amount);
    }
}
