// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";
import {IERC7160} from "./IERC7160.sol";
import {IStory} from "./IStory.sol";

/* solium-disable-next-line */
using Strings for uint256;

// Interface for royalties (EIP-2981)
interface IERC2981 {
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}

contract CryptoartNFT is
    IERC7160,
    IERC4906,
    ERC721URIStorageUpgradeable,
    IERC2981,
    OwnableUpgradeable,
    NoncesUpgradeable,
    IStory
{
    using ECDSA for bytes32;

    /// @dev String representation for address
    using Strings for address;

    uint256 private constant ROYALTY_BASE = 10000; // as per EIP-2981 (10000 = 100%, so 250 = 2.5%)
    uint256 public royaltyPercentage;
    address payable public royaltyReceiver; // the account to receive all royalties
    // metadata
    string public baseURI;
    // Burn
    mapping(address => uint256) public burnCount;

    address private __gap; // Gap to maintain storage layout
    address public _authoritySigner;

    // IERC7160
    mapping(uint256 => string[]) private _tokenURIs;
    mapping(uint256 => uint256) private _pinnedURIIndices;
    mapping(uint256 => bool) private _hasPinnedTokenURI;

    // State variable to keep track of total supply
    uint256 private _totalSupply;

    event RoyaltiesUpdated(address indexed receiver, uint256 newPercentage);
    
    // Define events for NFT lifecycle
    event Minted(uint256 tokenId);
    event MintedByBurning(uint256 tokenId, uint256[] burnedTokenIds);
    event Claimed(uint256 tokenId);
    event Burned(uint256 tokenId);
    event MintedByTrading(uint256 newTokenId, uint256[] tradedTokenIds);

    // Story
    /// @param tokenId The token id to which the story is attached
    /// @param storyId The transaction id of the story
    /// @param visible The visibility of the story
    event ToggleStoryVisibility(uint256 tokenId, string storyId, bool visible);

    function initialize(
        address contractOwner,
        address contractAuthoritySigner
    ) external initializer {
        __ERC721_init("Cryptoart", "CNFT");
        __ERC721URIStorage_init();
        __Ownable_init(contractOwner);
        __Nonces_init();

        royaltyReceiver = payable(contractOwner); // default to the contract creator
        baseURI = "";
        royaltyPercentage = 250; // default to 2.5% royalty

        transferOwnership(contractOwner); // Ownable's transferOwnership
        _authoritySigner = contractAuthoritySigner;
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(IERC165, ERC721URIStorageUpgradeable)
        returns (bool)
    {
        return
            interfaceId == bytes4(0x49064906) ||
            super.supportsInterface(interfaceId);
    }

    // Royalties
    function royaltyInfo(
        uint256,
        uint256 _salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        royaltyAmount = (_salePrice * royaltyPercentage) / ROYALTY_BASE;
        return (royaltyReceiver, royaltyAmount);
    }

    function updateRoyalties(
        address payable newReceiver,
        uint256 newPercentage
    ) external onlyOwner {
        require(newPercentage <= ROYALTY_BASE, "Royalty percentage too high");
        royaltyReceiver = newReceiver;
        royaltyPercentage = newPercentage;

        emit RoyaltiesUpdated(newReceiver, newPercentage);
    }

    // Metadata
    function setBaseURI(string memory newBaseURI) external onlyOwner {
        baseURI = newBaseURI;
    }

    function updateMetadata(
        uint256 _tokenId,
        string memory _newMetadataURI
    ) external onlyOwner {
        _setTokenURI(_tokenId, _newMetadataURI);
        triggerMetadataUpdate(_tokenId);
    }

    function triggerMetadataUpdate(uint256 _tokenId) public onlyOwner {
        emit MetadataUpdate(_tokenId);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseURI;
    }

    // Mint
    function mint(
        uint256 _tokenId,
        string memory mintType,
        uint256 tokenPrice,
        string memory redeemableTrueURI,
        string memory redeemableFalseURI,
        uint256 redeemableDefaultIndex,
        bytes memory signature
    ) external payable {
        require(_tokenNotExists(_tokenId), "Token already minted.");
        require(msg.value >= tokenPrice, "Not enough Ether to mint NFT.");

        _validateAuthorizedMint(
            msg.sender,
            _tokenId,
            mintType,
            tokenPrice,
            0,
            redeemableTrueURI,
            redeemableFalseURI,
            redeemableDefaultIndex,
            signature
        );

        _mint(msg.sender, _tokenId);
        setUri(_tokenId, redeemableTrueURI, redeemableFalseURI, redeemableDefaultIndex);

        emit Minted(_tokenId);
    }

    function claimable(
        uint256 _tokenId,
        uint256 tokenPrice,
        string memory redeemableTrueURI,
        string memory redeemableFalseURI,
        uint256 redeemableDefaultIndex,
        bytes memory signature
    ) external payable {
        require(_tokenNotExists(_tokenId), "Token already minted or claimed.");

        _validateAuthorizedMint(
            msg.sender,
            _tokenId,
            "claimable",
            tokenPrice,
            0,
            redeemableTrueURI,
            redeemableFalseURI,
            redeemableDefaultIndex,
            signature
        );

        _mint(msg.sender, _tokenId);
        setUri(_tokenId, redeemableTrueURI, redeemableFalseURI, redeemableDefaultIndex);

        emit Claimed(_tokenId);
    }

    function mintWithBurns(
        uint256 _tokenId,
        uint256[] memory burnedTokenIds,
        string memory mintType,
        uint256 tokenPrice,
        uint256 burnsToUse,
        string memory redeemableTrueURI,
        string memory redeemableFalseURI,
        uint256 redeemableDefaultIndex,
        bytes memory signature
    ) public payable {
        require(
            burnCount[msg.sender] >= burnsToUse,
            "Not enough burns available."
        );
        require(_tokenNotExists(_tokenId), "Token already minted.");

        _validateAuthorizedMint(
            msg.sender,
            _tokenId,
            mintType,
            tokenPrice,
            burnsToUse,
            redeemableTrueURI,
            redeemableFalseURI,
            redeemableDefaultIndex,
            signature
        );

        _mint(msg.sender, _tokenId);
        setUri(_tokenId, redeemableTrueURI, redeemableFalseURI, redeemableDefaultIndex);

        emit MintedByBurning(_tokenId, burnedTokenIds);
        burnCount[msg.sender] -= burnsToUse;
    }

    function mintWithTrade(
        uint256 _mintedTokenId,
        uint256[] memory tradedTokenIds,
        string memory mintType,
        uint256 tokenPrice,
        string memory redeemableTrueURI,
        string memory redeemableFalseURI,
        uint256 redeemableDefaultIndex,
        bytes memory signature
    ) external payable {
        require(_tokenNotExists(_mintedTokenId), "Token already minted.");
        require(tradedTokenIds.length > 0, "No tokens provided for trade");

        // Transfer ownership of the traded tokens to the owner
        uint256 tradedTokensArrayLength = tradedTokenIds.length;
        for (uint256 i = 0; i < tradedTokensArrayLength; i++) {
            unchecked {
                uint256 tokenId = tradedTokenIds[i];
                require(
                    ownerOf(tokenId) == msg.sender,
                    "Sender must own the tokens to trade"
                );
                _transfer(msg.sender, owner(), tokenId);
            }
        }

        _validateAuthorizedMint(
            msg.sender,
            _mintedTokenId,
            mintType,
            tokenPrice,
            tradedTokenIds.length,
            redeemableTrueURI,
            redeemableFalseURI,
            redeemableDefaultIndex,
            signature
        );

        _mint(msg.sender, _mintedTokenId);
        setUri(_mintedTokenId, redeemableTrueURI, redeemableFalseURI, redeemableDefaultIndex);

        emit MintedByTrading(_mintedTokenId, tradedTokenIds);
    }

    function _tokenNotExists(uint256 _tokenId) internal view returns (bool) {
        return _ownerOf(_tokenId) == address(0);
    }

    // Burn
    function burn(uint256 tokenId) public virtual {
        // Only allow the owner to burn their token
        require(
            ownerOf(tokenId) == msg.sender ||
                isApprovedForAll(ownerOf(tokenId), msg.sender),
            "Caller is not owner nor approved"
        );
        _burn(tokenId);
        emit Burned(tokenId);
        unchecked {
            burnCount[_msgSender()] += 1;
        }
    }

    function batchBurn(uint256[] memory tokenIds) public virtual {
        uint256 tokensArrayLength = tokenIds.length;
        for (uint256 i = 0; i < tokensArrayLength; i++) {
          burn(tokenIds[i]);
        }
    }

    function burnAndMint(
        uint256[] memory tokenIds,
        uint256 _tokenId,
        string memory mintType,
        uint256 tokenPrice,
        uint256 burnsToUse,
        string memory redeemableTrueURI,
        string memory redeemableFalseURI,
        uint256 redeemableDefaultIndex,
        bytes memory signature
    ) external payable {
        require(_tokenNotExists(_tokenId), "Token already minted.");

        batchBurn(tokenIds);
        mintWithBurns(
            _tokenId,
            tokenIds,
            mintType,
            tokenPrice,
            burnsToUse,
            redeemableTrueURI,
            redeemableFalseURI,
            redeemableDefaultIndex,
            signature
        );
    }

    function _validateAuthorizedMint(
        address minter,
        uint256 tokenId,
        string memory mintType,
        uint256 tokenPrice,
        uint256 tokenList,
        string memory redeemableTrueURI,
        string memory redeemableFalseURI,
        uint256 redeemableDefaultIndex,
        bytes memory signature
    ) internal {
        bytes32 contentHash = keccak256(
            abi.encode(
                minter,
                tokenId,
                mintType,
                tokenPrice,
                tokenList,
                redeemableTrueURI,
                redeemableFalseURI,
                redeemableDefaultIndex,
                _useNonce(minter),
                block.chainid,
                address(this)
            )
        );
        address signer = _signatureWallet(contentHash, signature);
        require(signer == _authoritySigner, "Not authorized to mint");
    }

    function _signatureWallet(
        bytes32 contentHash,
        bytes memory signature
    ) private pure returns (address) {
        return
            ECDSA.recover(
                MessageHashUtils.toEthSignedMessageHash(contentHash),
                signature
            );
    }

    function updateAuthoritySigner(
        address newAuthoritySigner
    ) external onlyOwner {
        _authoritySigner = newAuthoritySigner;
    }

    function withdraw() external onlyOwner {
        uint256 balance = address(this).balance;

        // Always check if the balance is greater than zero to prevent failure in case of a zero balance withdrawal
        require(balance > 0, "No funds available for withdrawal");

        (bool success, ) = payable(msg.sender).call{value: balance}("");
        require(success, "Transfer failed.");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                IERC7160
    //////////////////////////////////////////////////////////////////////////*/
    // @notice Returns the pinned URI index or the last token URI index (length - 1).
    function _getTokenURIIndex(
        uint256 tokenId
    ) internal view returns (uint256) {
        return
            _hasPinnedTokenURI[tokenId]
                ? _pinnedURIIndices[tokenId]
                : _tokenURIs[tokenId].length - 1;
    }

    // @notice Implementation of ERC721.tokenURI for backwards compatibility.
    // @inheritdoc ERC721.tokenURI
    function tokenURI(
        uint256 tokenId
    ) public view virtual override returns (string memory) {
        require(
            !_tokenNotExists(tokenId),
            "ERC721: URI query for nonexistent token"
        );

        uint256 index = _getTokenURIIndex(tokenId);
        string[] memory uris = _tokenURIs[tokenId];
        string memory uri = uris[index];

        // Revert if no URI is found for the token.
        require(bytes(uri).length > 0, "ERC721: not URI found");
        return string(abi.encodePacked(_baseURI(), uri));
    }

    // @inheritdoc IERC721MultiMetadata.tokenURIs
    function tokenURIs(
        uint256 tokenId
    ) external view returns (uint256 index, string[] memory uris, bool pinned) {
        require(
            !_tokenNotExists(tokenId),
            "ERC721: URI query for nonexistent token"
        );
        return (
            _getTokenURIIndex(tokenId),
            _tokenURIs[tokenId],
            _hasPinnedTokenURI[tokenId]
        );
    }

    // @inheritdoc IERC721MultiMetadata.pinTokenURI
    // pin the index-0 URI of the token, which has redeemable attribute on true
    // pin the index-1 URI of the token, which has redeemable attribute on false
    function pinTokenURI(uint256 tokenId, uint256 index) external onlyOwner {
        require(
            index < _tokenURIs[tokenId].length,
            "Index out of bounds for token URI"
        );

        _pinnedURIIndices[tokenId] = index;
        _hasPinnedTokenURI[tokenId] = true;
        emit TokenUriPinned(tokenId, index);
        emit MetadataUpdate(tokenId);
    }

    // holder unpairs the token in order to redeem physically again
    // pin the first URI of the token, which has redeemable attribute on true
    function pinRedeemableTrueTokenUri(
        uint256 tokenId,
        bytes memory signature
    ) external {
        require(msg.sender == ownerOf(tokenId), "Unauthorized");

        _validateAuthorizedUnpair(msg.sender, tokenId, signature);

        _pinnedURIIndices[tokenId] = 0;
        _hasPinnedTokenURI[tokenId] = true;
        emit TokenUriPinned(tokenId, 0);
        emit MetadataUpdate(tokenId);
    }

    // @inheritdoc IERC721MultiMetadata.unpinTokenURI
    function unpinTokenURI(uint256) external pure {
        return;
    }

    // @inheritdoc IERC721MultiMetadata.hasPinnedTokenURI
    function hasPinnedTokenURI(
        uint256 tokenId
    ) external view returns (bool pinned) {
        return _hasPinnedTokenURI[tokenId];
    }

    /// @notice Sets base metadata for the token
    // contract can only set first and second URIs for metadata redeemable on true and false
    function setUri(
        uint256 tokenId,
        string memory redeemableTrueURI,
        string memory redeemableFalseURI,
        uint256 redeemableDefaultIndex
    ) private {
        require(_tokenURIs[tokenId].length == 0, "URI already set for token");

        _tokenURIs[tokenId].push(redeemableTrueURI);
        _tokenURIs[tokenId].push(redeemableFalseURI);
        _pinnedURIIndices[tokenId] = redeemableDefaultIndex;
        _hasPinnedTokenURI[tokenId] = true;

        emit TokenUriPinned(tokenId, redeemableDefaultIndex);
        emit MetadataUpdate(tokenId);
    }

    function _validateAuthorizedUnpair(
        address minter,
        uint256 tokenId,
        bytes memory signature
    ) internal {
        bytes32 contentHash = keccak256(
            abi.encode(
                minter,
                tokenId,
                _useNonce(minter),
                block.chainid,
                address(this)
            )
        );
        address signer = _signatureWallet(contentHash, signature);
        require(signer == _authoritySigner, "Not authorized to unpair");
    }

    /*//////////////////////////////////////////////////////////////////////////
                                Story Inscriptions
    //////////////////////////////////////////////////////////////////////////*/

    /// @inheritdoc IStory
    function addCreatorStory(
        uint256 tokenId,
        string calldata,
        /*creatorName*/ string calldata story
    ) external {
        require(!_tokenNotExists(tokenId), "Token does not exist");
        require(
            msg.sender == ownerOf(tokenId) || msg.sender == owner(),
            "Caller is not the owner of the token"
        );

        emit CreatorStory(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    /// @inheritdoc IStory
    function addStory(
        uint256 tokenId,
        string calldata,
        /*collectorName*/ string calldata story
    ) external {
        require(!_tokenNotExists(tokenId), "Token does not exist");
        require(
            msg.sender == ownerOf(tokenId),
            "Caller is not the owner of the token"
        );

        emit Story(tokenId, msg.sender, msg.sender.toHexString(), story);
    }

    function toggleStoryVisibility(
        uint256 tokenId,
        string calldata storyId,
        bool visible
    ) external {
        require(!_tokenNotExists(tokenId), "Token does not exist");
        require(
            msg.sender == ownerOf(tokenId) || msg.sender == owner(),
            "Caller is not the owner of the token"
        );

        emit ToggleStoryVisibility(tokenId, storyId, visible);
    }

    function addCollectionStory(
        string calldata creatorName,
        string calldata story
    ) external override {}

    /*//////////////////////////////////////////////////////////////////////////
                                Supply
    //////////////////////////////////////////////////////////////////////////*/
    
    // Getter for total supply
    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    // Function to set the total supply (onlyOwner)
    function setTotalSupply(uint256 newTotalSupply) external onlyOwner {
        _totalSupply = newTotalSupply;
    }
}
