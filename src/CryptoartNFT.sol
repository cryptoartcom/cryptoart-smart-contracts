// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/utils/NoncesUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/utils/PausableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import "@openzeppelin-contracts-5.0.2/utils/cryptography/ECDSA.sol";
import "@openzeppelin-contracts-5.0.2/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin-contracts-5.0.2/utils/math/SafeCast.sol";
import {IERC7160} from "./interfaces/IERC7160.sol";
import {IStory} from "./interfaces/IStory.sol";
import {Error} from "./libraries/Error.sol";

contract CryptoartNFT is
    IERC7160,
    IERC4906, // TODO: Should check why this is being used, possible question to other dev, I don't know what its being used for or how it is being inherited exactly
    ERC721URIStorageUpgradeable,
    ERC721RoyaltyUpgradeable,
    ERC721EnumerableUpgradeable,
    OwnableUpgradeable,
    PausableUpgradeable,
    NoncesUpgradeable,
    IStory,
    ReentrancyGuardUpgradeable
{
    using SafeCast for uint256;
    using Strings for uint256;
    using Strings for address;

    // ==========================================================================
    // Constants
    // ==========================================================================

    uint256 private constant ROYALTY_BASE = 10000; // as per EIP-2981 (10000 = 100%, so 250 = 2.5%)
    uint96 public constant DEFAULT_ROYALTY_PERCENTAGE = 250; // default royalty percentage 2.5%
    uint256 private constant MAX_BATCH_SIZE = 50;

    // ==========================================================================
    // State Variables
    // ==========================================================================

    string public baseURI;
    address public authoritySigner;
    // TODO: question: there's a total supply variable and setter function in the original contract but no checks for it.  What was the intention here with this? Maybe the last dev meant it to be MaxSupply
    uint128 public maxSupply;

    // Wallet in charge of receiving all tokens transfered for minting
    address public _nftReceiver;

    // IERC7160
    mapping(uint256 => string[]) private _tokenURIs;
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
        uint256 tokenCount;
        bytes signature;
    }

    struct TokenURISet {
        string uriWhenRedeemable;
        string uriWhenNotRedeemable;
        uint256 redeemableDefaultIndex;
    }

    // ==========================================================================
    // Events
    // ==========================================================================

    event Initialized(address contractOwner, address contractAuthoritySigner);
    event BaseURISet(string newBaseURI);
    event MaxSupplySet(uint256 newMaxSupply);
    event RoyaltiesUpdated(address indexed receiver, uint256 newPercentage);
    event AuthoritySignerUpdated(address newAuthoritySigner);
    event NftReceiverUpdated(address newNftReceiver);
    event ToggleStoryVisibility(uint256 tokenId, string storyId, bool visible);

    // NFT lifecycle events
    event Minted(uint256 tokenId);
    event MintedByBurning(uint256 tokenId, uint256[] burnedTokenIds);
    event Claimed(uint256 tokenId);
    event Burned(uint256 tokenId);
    event MintedByTrading(uint256 newTokenId, uint256[] tradedTokenIds);

    // ==========================================================================
    // Initialization
    // ==========================================================================

    function initialize(address contractOwner, address contractAuthoritySigner, uint128 _maxSupply)
        external
        initializer
    {
        __ERC721_init("Cryptoart", "CNFT");
        __ERC721URIStorage_init();
        __ERC721Royalty_init();
        __ERC721Enumerable_init();
        __Ownable_init(contractOwner);
        __Pausable_init();
        __Nonces_init();
        // TODO: question: is this really what we want the base URI to be?
        baseURI = "";
        ERC2981Upgradeable._setDefaultRoyalty(payable(contractOwner), DEFAULT_ROYALTY_PERCENTAGE);

        _nftReceiver = 0x07f38db5E4d333bC6956D817258fe305520f2Fd7; // TODO: don't hard code this
        authoritySigner = contractAuthoritySigner;
        maxSupply = _maxSupply;

        emit Initialized(contractOwner, contractAuthoritySigner);
    }

    // ==========================================================================
    // Minting Operations
    // ==========================================================================
    // TODO: question: what was the intention with MintType? When was each mint type suppose to be used? For example, "claimable" is only for claimable function? OpenMint and whitelist is for the mint function?
    function mint(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        _coreMint(data, tokenUriSet);
        emit Minted(data.tokenId);
    }

    function claim(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        _coreMint(data, tokenUriSet);
        emit Claimed(data.tokenId);
    }

    function mintWithTrade(
        uint256[] calldata tradedTokenIds,
        MintValidationData calldata data,
        TokenURISet calldata tokenUriSet
    ) external payable whenNotPaused nonReentrant {
        // TODO: question: Verify this check is correct. I'm a bit confused why it says "mintedTokenId" but then checks that the token should not exist
        if (tradedTokenIds.length == 0) {
            revert Error.Batch_EmptyArray();
        }

        // Transfer ownership of the traded tokens to the owner
        uint256 tradedTokensArrayLength = tradedTokenIds.length;
        for (uint256 i; i < tradedTokensArrayLength;) {
            uint256 tokenId = tradedTokenIds[i];
            if (!_isOwnerOf(tokenId, msg.sender)) {
                revert Error.Token_NotOwned(tokenId, msg.sender);
            }
            _transfer(msg.sender, _nftReceiver, tokenId);
            unchecked {
                ++i;
            }
        }

        _coreMint(data, tokenUriSet);
        emit MintedByTrading(data.tokenId, tradedTokenIds);
    }

    function burnAndMint(
        uint256[] calldata tokenIds,
        uint256 requiredBurnCount,
        MintValidationData calldata data,
        TokenURISet calldata tokenUriSet
    ) external payable whenNotPaused nonReentrant {
        if (tokenIds.length != requiredBurnCount) {
            revert Error.Batch_InsufficientTokenAmount(requiredBurnCount, tokenIds.length);
        }

        batchBurn(tokenIds);
        _coreMint(data, tokenUriSet);
        emit MintedByBurning(data.tokenId, tokenIds);
    }

    // ==========================================================================
    // Burn Operations
    // ==========================================================================

    // TODO: Gotta check this virtual stuff.  Why are these functions marked as virtual?

    function burn(uint256 tokenId) public virtual whenNotPaused {
        if (!_isOwnerOf(tokenId, msg.sender)) {
            revert Error.Token_NotOwned(tokenId, msg.sender);
        }
        ERC721Upgradeable._burn(tokenId);
        ERC2981Upgradeable._resetTokenRoyalty(tokenId);
        emit Burned(tokenId);
    }

    function batchBurn(uint256[] calldata tokenIds) public virtual whenNotPaused {
        uint256 tokenIdArrayLength = tokenIds.length;
        if (tokenIdArrayLength == 0) {
            revert Error.Batch_EmptyArray();
        }
        if (tokenIdArrayLength >= MAX_BATCH_SIZE) {
            revert Error.Batch_MaxSizeExceeded(tokenIdArrayLength, MAX_BATCH_SIZE);
        }

        // Check for duplicates
        for (uint256 i; i < tokenIdArrayLength - 1; i++) {
            for (uint256 j = i + 1; j < tokenIdArrayLength; j++) {
                if (tokenIds[i] == tokenIds[j]) revert Error.Batch_DuplicateTokenIds();
            }
        }

        for (uint256 i; i < tokenIdArrayLength;) {
            burn(tokenIds[i]);
            unchecked {
                ++i;
            }
        }
    }

    // ==========================================================================
    // Metadata Management
    // ==========================================================================

    // @inheritdoc IERC721MultiMetadata.tokenURIs
    function tokenURIs(uint256 tokenId) external view returns (uint256 index, string[] memory uris, bool pinned) {
        if (!_tokenExists(tokenId)) {
            revert Error.Token_DoesNotExist(tokenId);
        }
        return (_getTokenURIIndex(tokenId), _tokenURIs[tokenId], _hasPinnedTokenURI[tokenId]);
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
    function markAsRedeemable(uint256 tokenId, bytes calldata signature) external {
        if (!_isOwnerOf(tokenId, msg.sender)) {
            revert Error.Token_NotOwned(tokenId, msg.sender);
        }

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
    // TODO: question: check this against the original contract and ask a question about if necessary
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
    ) external {
        if (!_tokenExists(tokenId)) {
            revert Error.Token_DoesNotExist(tokenId);
        }
        if (!_isOwnerOf(tokenId, msg.sender)) {
            revert Error.Token_NotOwned(tokenId, msg.sender);
        }

        emit CreatorStory(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addStory(
        uint256 tokenId,
        string calldata,
        /*collectorName*/
        string calldata story
    ) external {
        if (!_tokenExists(tokenId)) {
            revert Error.Token_DoesNotExist(tokenId);
        }
        if (!_isOwnerOf(tokenId, msg.sender)) {
            revert Error.Token_NotOwned(tokenId, msg.sender);
        }

        emit Story(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    function toggleStoryVisibility(uint256 tokenId, string calldata storyId, bool visible) external {
        if (!_tokenExists(tokenId)) {
            revert Error.Token_DoesNotExist(tokenId);
        }
        if (!_isOwnerOf(tokenId, msg.sender)) {
            revert Error.Token_NotOwned(tokenId, msg.sender);
        }

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

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        if (bytes(newBaseURI).length == 0) {
            revert Error.Admin_EmptyBaseURI();
        }
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    function updateMetadata(uint256 _tokenId, string calldata _newMetadataURI) external onlyOwner {
        if (!_tokenExists(_tokenId)) {
            revert Error.Token_DoesNotExist(_tokenId);
        }
        ERC721URIStorageUpgradeable._setTokenURI(_tokenId, _newMetadataURI);
        triggerMetadataUpdate(_tokenId);
    }

    function triggerMetadataUpdate(uint256 _tokenId) public onlyOwner {
        // TODO: question: evaluate this; don't know why this would be here
        emit MetadataUpdate(_tokenId);
    }

    function updateAuthoritySigner(address newAuthoritySigner) external onlyOwner {
        authoritySigner = newAuthoritySigner;
        emit AuthoritySignerUpdated(newAuthoritySigner);
    }

    function updateNftReceiver(address newNftReceiver) external onlyOwner {
        _nftReceiver = newNftReceiver;
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
    // Internal Functions
    // ==========================================================================

    function _coreMint(MintValidationData calldata data, TokenURISet calldata tokenUriSet) private {
        if (_tokenExists(data.tokenId)) {
            revert Error.Token_AlreadyMinted(data.tokenId);
        }
        if (ERC721EnumerableUpgradeable.totalSupply() > maxSupply) {
            revert Error.Mint_ExceedsTotalSupply(data.tokenId, totalSupply());
        }

        _validateMintAuthorization(data, tokenUriSet);
        ERC721Upgradeable._safeMint(data.recipient, data.tokenId);
        _setTokenMetadata(
            data.tokenId,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.redeemableDefaultIndex
        );
        _refundExcessPayment(data.tokenPrice);
    }

    function _validateMintAuthorization(MintValidationData calldata data, TokenURISet calldata uriParams) private {
        _validatePayment(data.tokenPrice);
        _validateSignature(data, uriParams);
    }

    function _validatePayment(uint256 tokenPrice) private view {
        if (msg.value < tokenPrice) {
            revert Error.Mint_InsufficientPayment(tokenPrice, msg.value);
        }
    }

    function _validateSignature(MintValidationData calldata data, TokenURISet calldata uriParams) private {
        bytes32 contentHash = keccak256(
            abi.encode(
                data.recipient,
                data.tokenId,
                data.mintType,
                data.tokenPrice,
                data.tokenCount,
                uriParams.uriWhenRedeemable,
                uriParams.uriWhenNotRedeemable,
                uriParams.redeemableDefaultIndex,
                _useNonce(data.recipient),
                block.chainid,
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

    /// @notice Sets base metadata for the token
    // contract can only set first and second URIs for metadata redeemable on true and false
    function _setTokenMetadata(
        uint256 tokenId,
        string calldata uriWhenRedeemable,
        string calldata uriWhenNotRedeemable,
        uint256 redeemableDefaultIndex
    ) private {
        if (_tokenURIs[tokenId].length != 0) {
            revert Error.Token_URIAlreadySet(tokenId);
        }

        _tokenURIs[tokenId].push(uriWhenRedeemable);
        _tokenURIs[tokenId].push(uriWhenNotRedeemable);
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

    function _validateUnpairAuthorization(address minter, uint256 tokenId, bytes calldata signature) internal {
        bytes32 contentHash = keccak256(abi.encode(minter, tokenId, _useNonce(minter), block.chainid, address(this)));
        if (!_isValidSignature(contentHash, signature)) {
            revert Error.Auth_UnauthorizedSigner();
        }
    }

    // @notice Returns the pinned URI index or the last token URI index (length - 1).
    function _getTokenURIIndex(uint256 tokenId) internal view returns (uint256) {
        return _hasPinnedTokenURI[tokenId] ? _pinnedURIIndices[tokenId] : _tokenURIs[tokenId].length - 1;
    }

    function _isOwnerOf(uint256 tokenId, address msgSender) private view returns (bool) {
        return ownerOf(tokenId) == msgSender;
    }

    function _tokenExists(uint256 _tokenId) internal view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    // ==========================================================================
    // Required Overrides By Solidity
    // ==========================================================================

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721URIStorageUpgradeable, ERC721RoyaltyUpgradeable, ERC721EnumerableUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IERC7160).interfaceId || interfaceId == type(IERC4906).interfaceId
            || super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721URIStorageUpgradeable, ERC721Upgradeable)
        returns (string memory)
    {
        if (!_tokenExists(tokenId)) {
            revert Error.Token_DoesNotExist(tokenId);
        }

        uint256 index = _getTokenURIIndex(tokenId);
        string[] memory uris = _tokenURIs[tokenId];
        string memory uri = uris[index];

        if (bytes(uri).length == 0) {
            revert Error.Token_NoURIFound(tokenId);
        }
        // TODO: Examine this. Couldn't we just concatenate instead like this:
        //       return string.concat(base, _tokenURI);
        return string(abi.encodePacked(_baseURI(), uri));
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    function _update(address to, uint256 tokenId, address auth)
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        returns (address)
    {
        return ERC721EnumerableUpgradeable._update(to, tokenId, auth);
    }

    function _increaseBalance(address account, uint128 amount)
        internal
        virtual
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
    {
        ERC721EnumerableUpgradeable._increaseBalance(account, amount);
    }
}
