// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin-contracts-upgradeable-5.0.2/token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol";
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
    IERC4906,
    ERC721URIStorageUpgradeable,
    ERC721RoyaltyUpgradeable,
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
    uint256 public totalSupply;

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
        Claimable,
        Burn
    }
    
    struct MintParams {
        uint256 tokenId;
        MintType mintType;
        uint256 tokenPrice;
    }

    struct TokenURISet {
        string uriWhenRedeemable;
        string uriWhenNotRedeemable;
        uint256 defaultIndex;
    }

    // ==========================================================================
    // Events
    // ==========================================================================

    event Initialized(address contractOwner, address contractAuthoritySigner);
    event BaseURISet(string newBaseURI);
    event TotalSupplySet(uint256 newTotalSupply);
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

    function initialize(address contractOwner, address contractAuthoritySigner) external initializer {
        __ERC721_init("Cryptoart", "CNFT");
        __ERC721URIStorage_init();
        __ERC721Royalty_init();
        __Ownable_init(contractOwner);
        __Pausable_init();
        __Nonces_init();

        baseURI = "";
        ERC2981Upgradeable._setDefaultRoyalty(payable(contractOwner), DEFAULT_ROYALTY_PERCENTAGE);

        _nftReceiver = 0x07f38db5E4d333bC6956D817258fe305520f2Fd7; // TODO: don't hard code this
        authoritySigner = contractAuthoritySigner;

        emit Initialized(contractOwner, contractAuthoritySigner);
    }

    // ==========================================================================
    // Minting Operations
    // ==========================================================================

    function mint(MintParams calldata mintParams, TokenURISet calldata tokenUriSet, bytes calldata signature)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (_tokenExists(mintParams.tokenId)) revert Error.TokenAlreadyMinted();
        if (totalSupply > 0 && mintParams.tokenId >= totalSupply) revert Error.ExceedsTotalSupply();

        _validateAuthorizedMint(
            msg.sender,
            mintParams.tokenId,
            mintParams.mintType,
            mintParams.tokenPrice,
            0,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.defaultIndex,
            signature
        );

        ERC721Upgradeable._safeMint(msg.sender, mintParams.tokenId);
        _setUri(
            mintParams.tokenId,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.defaultIndex
        );

        _refundExcessPayment(mintParams.tokenPrice);

        emit Minted(mintParams.tokenId);
    }

    function claimable(MintParams calldata mintParams, TokenURISet calldata tokenUriSet, bytes calldata signature)
        external
        payable
        whenNotPaused
        nonReentrant
    {
        if (_tokenExists(mintParams.tokenId)) revert Error.TokenAlreadyClaimed();

        _validateAuthorizedMint(
            msg.sender,
            mintParams.tokenId,
            MintType.Claimable,
            mintParams.tokenPrice,
            0,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.defaultIndex,
            signature
        );

        ERC721Upgradeable._safeMint(msg.sender, mintParams.tokenId);
        _setUri(
            mintParams.tokenId,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.defaultIndex
        );

        _refundExcessPayment(mintParams.tokenPrice);

        emit Claimed(mintParams.tokenId);
    }

    function mintWithTrade(
        uint256[] calldata tradedTokenIds,
        MintParams calldata mintParams,
        TokenURISet calldata tokenUriSet,
        bytes calldata signature
    ) external payable whenNotPaused nonReentrant {
        // TODO: question: Verify this check is correct. I'm a bit confused why it says "mintedTokenId" but then checks that the token should not exist
        if (_tokenExists(mintParams.tokenId)) revert Error.TokenAlreadyMinted();
        if (tradedTokenIds.length == 0) revert Error.TokenIdArrayCannotBeEmpty();

        // Transfer ownership of the traded tokens to the owner
        uint256 tradedTokensArrayLength = tradedTokenIds.length;
        for (uint256 i; i < tradedTokensArrayLength;) {
            unchecked {
                uint256 tokenId = tradedTokenIds[i];
                if (!_isOwnerOf(tokenId, msg.sender)) revert Error.CallerIsNotTokenOwner();
                _transfer(msg.sender, _nftReceiver, tokenId);
                ++i;
            }
        }

        _validateAuthorizedMint(
            msg.sender,
            mintParams.tokenId,
            mintParams.mintType,
            mintParams.tokenPrice,
            tradedTokenIds.length,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.defaultIndex,
            signature
        );

        ERC721Upgradeable._safeMint(msg.sender, mintParams.tokenId);
        _setUri(
            mintParams.tokenId,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.defaultIndex
        );

        emit MintedByTrading(mintParams.tokenId, tradedTokenIds);
    }

    function burnAndMint(
        uint256[] calldata tokenIds,
        uint256 requiredBurnCount,
        MintParams calldata mintParams,
        TokenURISet calldata tokenUriSet,
        bytes calldata signature
    ) external payable whenNotPaused nonReentrant {
        if (_tokenExists(mintParams.tokenId)) revert Error.TokenAlreadyMinted();
        if (tokenIds.length != requiredBurnCount) revert Error.NotEnoughTokensToBurn();

        _validateAuthorizedMint(
            msg.sender,
            mintParams.tokenId,
            mintParams.mintType,
            mintParams.tokenPrice,
            requiredBurnCount,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.defaultIndex,
            signature
        );

        batchBurn(tokenIds);
        ERC721Upgradeable._mint(msg.sender, mintParams.tokenId);
        _setUri(
            mintParams.tokenId,
            tokenUriSet.uriWhenRedeemable,
            tokenUriSet.uriWhenNotRedeemable,
            tokenUriSet.defaultIndex
        );

        emit MintedByBurning(mintParams.tokenId, tokenIds);
    }

    // ==========================================================================
    // Burn Operations
    // ==========================================================================

    // TODO: Gotta check this virtual stuff.  Why are these functions marked as virtual?

    function burn(uint256 tokenId) public virtual whenNotPaused {
        if (!_isOwnerOf(tokenId, msg.sender)) revert Error.CallerIsNotTokenOwner();
        ERC721Upgradeable._burn(tokenId);
        ERC2981Upgradeable._resetTokenRoyalty(tokenId);
        emit Burned(tokenId);
    }

    function batchBurn(uint256[] calldata tokenIds) public virtual whenNotPaused {
        uint256 tokenIdArrayLength = tokenIds.length;
        if (tokenIdArrayLength == 0) revert Error.TokenIdArrayCannotBeEmpty();
        if (tokenIdArrayLength >= MAX_BATCH_SIZE) revert Error.MaxBatchSizeExceeded();

        // Check for duplicates
        for (uint256 i; i < tokenIdArrayLength - 1; i++) {
            for (uint256 j = i + 1; j < tokenIdArrayLength; j++) {
                if (tokenIds[i] == tokenIds[j]) revert Error.DuplicateTokenIds();
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
        if (!_tokenExists(tokenId)) revert Error.ERC721UriQueryForNonexistentToken();
        return (_getTokenURIIndex(tokenId), _tokenURIs[tokenId], _hasPinnedTokenURI[tokenId]);
    }

    // @inheritdoc IERC721MultiMetadata.pinTokenURI
    // pin the index-0 URI of the token, which has redeemable attribute on true
    // pin the index-1 URI of the token, which has redeemable attribute on false
    function pinTokenURI(uint256 tokenId, uint256 index) external onlyOwner {
        if (index >= _tokenURIs[tokenId].length) revert Error.IndexOutOfBounds();

        _pinnedURIIndices[tokenId] = index;
        _hasPinnedTokenURI[tokenId] = true;

        emit TokenUriPinned(tokenId, index);
        emit MetadataUpdate(tokenId);
    }

    // holder unpairs the token in order to redeem physically again
    // pin the first URI of the token, which has redeemable attribute on true
    function markAsRedeemable(uint256 tokenId, bytes calldata signature) external {
        if (!_isOwnerOf(tokenId, msg.sender)) revert Error.CallerIsNotTokenOwner();

        _pinnedURIIndices[tokenId] = 0;
        _hasPinnedTokenURI[tokenId] = true;

        _validateAuthorizedUnpair(msg.sender, tokenId, signature);

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
    ) external {
        if (!_tokenExists(tokenId)) revert Error.TokenDoesNotExist();
        if (!_isOwnerOf(tokenId, msg.sender)) revert Error.CallerIsNotTokenOwner();

        emit CreatorStory(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addStory(
        uint256 tokenId,
        string calldata,
        /*collectorName*/
        string calldata story
    ) external {
        if (!_tokenExists(tokenId)) revert Error.TokenDoesNotExist();
        if (!_isOwnerOf(tokenId, msg.sender)) revert Error.CallerIsNotTokenOwner();

        emit Story(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    function toggleStoryVisibility(uint256 tokenId, string calldata storyId, bool visible) external {
        if (!_tokenExists(tokenId)) revert Error.TokenDoesNotExist();
        if (!_isOwnerOf(tokenId, msg.sender)) revert Error.CallerIsNotTokenOwner();

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
        if (newPercentage > ROYALTY_BASE) revert Error.RoyaltyPercentageTooHigh();

        ERC2981Upgradeable._setDefaultRoyalty(newReceiver, newPercentage);

        emit RoyaltiesUpdated(newReceiver, newPercentage);
    }

    function setBaseURI(string calldata newBaseURI) external onlyOwner {
        if (bytes(newBaseURI).length == 0) revert Error.EmptyBaseUriNotAllowed();
        baseURI = newBaseURI;
        emit BaseURISet(newBaseURI);
    }

    function updateMetadata(uint256 _tokenId, string calldata _newMetadataURI) external onlyOwner {
        if (!_tokenExists(_tokenId)) revert Error.TokenDoesNotExist();
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
        if (balance == 0) revert Error.NoWithdrawalFundsAvailable();
        (bool success,) = payable(msg.sender).call{value: balance}("");
        if (!success) revert Error.WithdrawalFailed();
    }

    function setTotalSupply(uint256 newTotalSupply) external onlyOwner {
        totalSupply = newTotalSupply;
        emit TotalSupplySet(newTotalSupply);
    }

    // ==========================================================================
    // Internal Functions
    // ==========================================================================

    function _validateAuthorizedMint(
        address minter,
        uint256 tokenId,
        MintType mintType,
        uint256 tokenPrice,
        uint256 tokenList,
        string calldata uriWhenRedeemable,
        string calldata uriWhenNotRedeemable,
        uint256 redeemableDefaultIndex,
        bytes calldata signature
    ) internal {
        bytes32 contentHash = keccak256(
            abi.encode(
                minter,
                tokenId,
                mintType,
                tokenPrice,
                tokenList,
                uriWhenRedeemable,
                uriWhenNotRedeemable,
                redeemableDefaultIndex,
                _useNonce(minter),
                block.chainid,
                address(this)
            )
        );
        address signer = _verifySignature(contentHash, signature);
        if (signer != authoritySigner) revert Error.UnauthorizedSigner();
    }

    function _validateAuthorizedUnpair(address minter, uint256 tokenId, bytes calldata signature) internal {
        bytes32 contentHash = keccak256(abi.encode(minter, tokenId, _useNonce(minter), block.chainid, address(this)));
        address signer = _verifySignature(contentHash, signature);
        if (signer != authoritySigner) revert Error.UnauthorizedSigner();
    }

    // @notice Returns the pinned URI index or the last token URI index (length - 1).
    function _getTokenURIIndex(uint256 tokenId) internal view returns (uint256) {
        return _hasPinnedTokenURI[tokenId] ? _pinnedURIIndices[tokenId] : _tokenURIs[tokenId].length - 1;
    }

    function _isOwnerOf(uint256 tokenId, address msgSender) private view returns (bool) {
        return ownerOf(tokenId) == msgSender;
    }

    function _refundExcessPayment(uint256 tokenPrice) private {
        if (msg.value < tokenPrice) revert Error.NotEnoughEthToMintNFT();
        uint256 excess = msg.value - tokenPrice;
        if (excess > 0) {
            (bool success,) = payable(msg.sender).call{value: excess}("");
            if (!success) revert Error.FailedToRefundExcessPayment();
        }
    }

    function _verifySignature(bytes32 contentHash, bytes calldata signature) private pure returns (address) {
        return ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(contentHash), signature);
    }

    function _tokenExists(uint256 _tokenId) internal view returns (bool) {
        return _ownerOf(_tokenId) != address(0);
    }

    /// @notice Sets base metadata for the token
    // contract can only set first and second URIs for metadata redeemable on true and false
    function _setUri(
        uint256 tokenId,
        string calldata uriWhenRedeemable,
        string calldata uriWhenNotRedeemable,
        uint256 redeemableDefaultIndex
    ) private {
        if (_tokenURIs[tokenId].length != 0) revert Error.TokenUriAlreadySet();

        _tokenURIs[tokenId].push(uriWhenRedeemable);
        _tokenURIs[tokenId].push(uriWhenNotRedeemable);
        _pinnedURIIndices[tokenId] = redeemableDefaultIndex;
        _hasPinnedTokenURI[tokenId] = true;

        emit TokenUriPinned(tokenId, redeemableDefaultIndex);
        emit MetadataUpdate(tokenId);
    }

    // ==========================================================================
    // Overrides
    // ==========================================================================

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(IERC165, ERC721URIStorageUpgradeable, ERC721RoyaltyUpgradeable)
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
        if (!_tokenExists(tokenId)) revert Error.ERC721UriQueryForNonexistentToken();

        uint256 index = _getTokenURIIndex(tokenId);
        string[] memory uris = _tokenURIs[tokenId];
        string memory uri = uris[index];

        if (bytes(uri).length == 0) revert Error.ERC721NoTokenUriFound();

        return string(abi.encodePacked(_baseURI(), uri));
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }
}
