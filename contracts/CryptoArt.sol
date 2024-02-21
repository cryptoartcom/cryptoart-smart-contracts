// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

using Strings for uint256;

// Interface for royalties (EIP-2981)
interface IERC2981 {
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}

contract CryptoArtNFT is
    IERC4906,
    ERC721URIStorageUpgradeable,
    IERC2981,
    OwnableUpgradeable
{
    // uint256 public tokenCounter;
    uint256 public priceToMintNFT;
    uint256 private constant ROYALTY_BASE = 10000; // as per EIP-2981 (10000 = 100%, so 250 = 2.5%)
    uint256 public royaltyPercentage;
    address payable public royaltyReceiver; // the account to receive all royalties

    // metadata
    string public baseURI;

    // Merkle tree related
    bytes32 public merkleRoot;

    // Burn
    mapping (address => uint256) public burnCount;

    event RoyaltiesUpdated(address indexed receiver, uint256 newPercentage);

    function initialize() public initializer {
        __ERC721_init("CryptoArtNFT", "CART");
        __Ownable_init(msg.sender);

        priceToMintNFT = 0.0001 ether;
        royaltyReceiver = payable(msg.sender); // default to the contract creator
        baseURI = "ipfs://";
        royaltyPercentage = 250; // default to 2.5% royalty
    }

    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view virtual override(IERC165, ERC721URIStorageUpgradeable) returns (bool) {
        return interfaceId == bytes4(0x49064906) || super.supportsInterface(interfaceId);
    }

    function updateMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function updateMintPrice(uint256 newPrice) public onlyOwner {
        priceToMintNFT = newPrice;
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
    function mint(uint256 _tokenId, string memory metadataURI, bytes32[] memory merkleProof) public payable {
        require(_tokenNotExists(_tokenId), "Token already minted.");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _tokenId))));

        if(msg.sender != owner()){
            require(msg.value >= priceToMintNFT, "Not enough Ether to mint NFT.");
            require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid proof");
        }

        _mint(msg.sender, _tokenId);
        _setTokenURI(_tokenId, metadataURI);
    }
   
    function mintWithBurns(uint256 _tokenId, string memory metadataURI, bytes32[] memory merkleProof, uint256 burnsToUse) public payable {
        require(burnCount[msg.sender] >= burnsToUse, "Not enough burns available.");

        mint(_tokenId, metadataURI, merkleProof);
        burnCount[msg.sender] -= burnsToUse;
    }

    function _tokenNotExists(uint256 _tokenId) internal view returns (bool) {
        try this.ownerOf(_tokenId) returns (address _owner) {
            return (_owner == address(0));
        } catch {
            return true;
        }
    }

    // Burn
    function burn(uint256 tokenId) public virtual {
      // Only allow the owner to burn their token
      require(ownerOf(tokenId) == msg.sender || isApprovedForAll(ownerOf(tokenId), msg.sender), "Caller is not owner nor approved");
      _burn(tokenId);
      burnCount[_msgSender()] += 1;
    }

    function batchBurn(uint256[] memory tokenIds) public virtual {
      for (uint i = 0; i < tokenIds.length; i++) {
          burn(tokenIds[i]);
      }
    }
}
