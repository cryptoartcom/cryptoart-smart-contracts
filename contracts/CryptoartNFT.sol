// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts-upgradeable/utils/NoncesUpgradeable.sol";

using Strings for uint256;

// Interface for royalties (EIP-2981)
interface IERC2981 {
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}

contract CryptoartNFT is
    IERC4906,
    ERC721URIStorageUpgradeable,
    IERC2981,
    OwnableUpgradeable,
    NoncesUpgradeable
{
    using ECDSA for bytes32;

    uint256 private constant ROYALTY_BASE = 10000; // as per EIP-2981 (10000 = 100%, so 250 = 2.5%)
    uint256 public royaltyPercentage;
    address payable public royaltyReceiver; // the account to receive all royalties
    // metadata
    string public baseURI;
    // Burn
    mapping (address => uint256) public burnCount;

    address private _owner;
    address private _authoritySigner;

    event RoyaltiesUpdated(address indexed receiver, uint256 newPercentage);
    // Define events for NFT lifecycle
    event Minted(uint256 tokenId);
    event MintedByBurning(uint256 tokenId, uint256[] burnedTokenIds);
    event Claimed(uint256 tokenId);
    event Burned(uint256 tokenId);
    event MintedByTrading(uint256 newTokenId, uint256[] tradedTokenIds);

    function initialize(address contractOwner, address contractAuthoritySigner) public initializer {
        __ERC721_init("Cryptoart", "CNFT");
        __ERC721URIStorage_init();
        __Ownable_init(contractOwner);

        royaltyReceiver = payable(contractOwner); // default to the contract creator
        baseURI = "https://staging.api.cryptoart.com/metadata/";
        royaltyPercentage = 250; // default to 2.5% royalty

        _owner = contractOwner;
        _authoritySigner = contractAuthoritySigner;
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721URIStorageUpgradeable) returns (bool) {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    // Royalties
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        royaltyAmount = (_salePrice * royaltyPercentage) / ROYALTY_BASE;
        return (royaltyReceiver, royaltyAmount);
    }

    function updateRoyalties(
        address payable newReceiver,
        uint256 newPercentage
    ) public onlyOwner {
        require(newPercentage <= ROYALTY_BASE, "Royalty percentage too high");
        royaltyReceiver = newReceiver;
        royaltyPercentage = newPercentage;

        emit RoyaltiesUpdated(newReceiver, newPercentage);
    }

    // Metadata
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function updateMetadata(
        uint256 _tokenId,
        string memory _newMetadataURI
    ) public onlyOwner {
        _setTokenURI(_tokenId, _newMetadataURI);
        triggerMetadataUpdate(_tokenId);
    }

    function triggerMetadataUpdate(uint256 _tokenId) public onlyOwner {
        emit MetadataUpdate(_tokenId);
    }

    function _baseURI() override internal view virtual returns (string memory) {
        return baseURI;
    }

    // Mint
    function mint(uint256 _tokenId, string memory mintType, uint256 tokenPrice, bytes memory signature) public payable {
        require(_tokenNotExists(_tokenId), "Token already minted.");
        require(msg.value >= tokenPrice, "Not enough Ether to mint NFT.");

        _validateAuthorizedMint(msg.sender, _tokenId, mintType, tokenPrice, 0, signature);

        _mint(msg.sender, _tokenId);
        emit Minted(_tokenId);
    }

    function claimable(uint256 _tokenId, uint256 tokenPrice, bytes memory signature) public {
        require(_tokenNotExists(_tokenId), "Token already minted.");

        _validateAuthorizedMint(msg.sender, _tokenId, 'claimable', tokenPrice, 0, signature);

        _mint(msg.sender, _tokenId);
        emit Claimed(_tokenId);
    }

    function mintWithBurns(uint256 _tokenId, uint256[] memory burnedTokenIds, string memory mintType, uint256 tokenPrice, uint256 burnsToUse, bytes memory signature) public payable {
        require(burnCount[msg.sender] >= burnsToUse, "Not enough burns available.");
        require(_tokenNotExists(_tokenId), "Token already minted.");

        _validateAuthorizedMint(msg.sender, _tokenId, mintType, tokenPrice, burnsToUse, signature);

        _mint(msg.sender, _tokenId);
        emit MintedByBurning(_tokenId, burnedTokenIds);

        burnCount[msg.sender] -= burnsToUse;
    }

    function mintWithTrade(uint256 _mintedTokenId, uint256[] memory tradedTokenIds, string memory mintType, uint256 tokenPrice, bytes memory signature) public payable {
        require(_tokenNotExists(_mintedTokenId), "Token already minted.");
        require(tradedTokenIds.length > 0, "No tokens provided for trade");

        // Transfer ownership of the traded tokens to the owner
        uint256 tradedTokensArrayLength = tradedTokenIds.length;
        for (uint256 i = 0; i < tradedTokensArrayLength; i++) {
          unchecked {
            uint256 tokenId = tradedTokenIds[i];
            require(ownerOf(tokenId) == msg.sender, "Sender must own the tokens to trade");
            _transfer(msg.sender, _owner, tokenId);
          }
        }

        _validateAuthorizedMint(msg.sender, _mintedTokenId, mintType, tokenPrice, tradedTokenIds.length, signature);

        _mint(msg.sender, _mintedTokenId);
        emit MintedByTrading(_mintedTokenId, tradedTokenIds);
    }

    function _tokenNotExists(uint256 _tokenId) internal view returns (bool) {
        return _ownerOf(_tokenId) == address(0);
    }

    // Burn
    function burn(uint256 tokenId) public virtual {
      // Only allow the owner to burn their token
      require(ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Caller is not owner nor approved");
      _burn(tokenId);
      emit Burned(tokenId);
      unchecked {
        burnCount[_msgSender()] += 1;
      }
    }

    function batchBurn(uint256[] memory tokenIds) public virtual {
      uint256 tokensArrayLength = tokenIds.length;
      for (uint256 i = 0; i < tokensArrayLength; i++) {
        unchecked {
          burn(tokenIds[i]);
        }
      }
    }

    function burnAndMint(uint256[] memory tokenIds, uint256 _tokenId, string memory mintType, uint256 tokenPrice, uint256 burnsToUse, bytes memory signature) public payable {
        require(_tokenNotExists(_tokenId), "Token already minted.");

        batchBurn(tokenIds);
        mintWithBurns(_tokenId, tokenIds, mintType, tokenPrice, burnsToUse, signature);
    }

    function _validateAuthorizedMint(address minter, uint256 tokenId,string memory mintType, uint256 tokenPrice, uint256 tokenList, bytes memory signature) internal {
        bytes32 contentHash = keccak256(abi.encode(minter, tokenId, mintType, tokenPrice, tokenList, _useNonce(minter), block.chainid, address(this)));
        address signer = _signatureWallet(contentHash, signature);
        require(signer == currentAuthoritySigner(), "Not authorized to mint");
    }

    function _signatureWallet(bytes32 contentHash, bytes memory signature) private pure returns (address) {
      return ECDSA.recover(MessageHashUtils.toEthSignedMessageHash(contentHash), signature);
    }

    // ownership
    function currentAuthoritySigner() public view returns (address){
        return _authoritySigner;
    }

    function owner() public view virtual override returns (address) {
        return _owner;
    }

    function updateAuthoritySigner(
        address newAuthoritySigner
    ) public onlyOwner {
        _authoritySigner = newAuthoritySigner;
    }

    function updateOwner(
        address newOwner
    ) public onlyOwner {
        transferOwnership(newOwner);
        _owner = newOwner;
    }

    function withdraw() public onlyOwner {
      uint256 balance = address(this).balance;

      // Always check if the balance is greater than zero to prevent failure in case of a zero balance withdrawal
      require(balance > 0, "No funds available for withdrawal");

      (bool success, ) = payable(msg.sender).call{value: balance}("");
      require(success, "Transfer failed.");
    }
}
