// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721URIStorageUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

using Strings for uint256;

// Interface for royalties (EIP-2981)
interface IERC2981 {
    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view returns (address receiver, uint256 royaltyAmount);
}

contract CryptoArtNFT is
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
    mapping(uint256 => bool) public claimed;

    event URIUpdated(uint256 indexed tokenId, string newURI);
    event RoyaltiesUpdated(address indexed receiver, uint256 newPercentage);

    function initialize() public initializer {
        __ERC721_init("CryptoArtNFT", "CART");
        __Ownable_init(msg.sender);

        priceToMintNFT = 0.0001 ether;
        royaltyReceiver = payable(msg.sender); // default to the contract creator
        baseURI = "ipfs://";
        royaltyPercentage = 250; // default to 2.5% royalty
    }

    function updateMerkleRoot(bytes32 _merkleRoot) public onlyOwner {
        merkleRoot = _merkleRoot;
    }

    function updateMetadata(
        uint256 _tokenId,
        string memory _newMetadataURI
    ) public onlyOwner {
        _setTokenURI(_tokenId, _newMetadataURI);
        emit URIUpdated(_tokenId, _newMetadataURI);
    }

    function updateMintPrice(uint256 newPrice) public onlyOwner {
        priceToMintNFT = newPrice;
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

    function royaltyInfo(
        uint256 _tokenId,
        uint256 _salePrice
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        royaltyAmount = (_salePrice * royaltyPercentage) / ROYALTY_BASE;
        return (royaltyReceiver, royaltyAmount);
    }

    // Mapping to handle whitelist
    mapping(address => bool) public whitelist;

    // Function to add whitelisted addresses
    // Function to add a set of addresses to whitelist
    function addToWhitelist(address[] memory _addresses) public onlyOwner {
        for (uint i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = true;
        }
    }

    // Function to remove a set of addresses from whitelist
    function removeFromWhitelist(address[] memory _addresses) public onlyOwner {
        for (uint i = 0; i < _addresses.length; i++) {
            whitelist[_addresses[i]] = false;
        }
    }

    // metadata
    function setBaseURI(string memory newBaseURI) public onlyOwner {
        baseURI = newBaseURI;
    }

    function _baseURI() override internal view virtual returns (string memory) {
        return baseURI;
    }

    // mint
    function mint(uint256 _tokenId, string memory metadataURI, bytes32[] memory merkleProof) public payable {
        require(_tokenNotExists(_tokenId), "Token already minted.");

        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender, _tokenId))));

        if(msg.sender != owner()){
            require(msg.value >= priceToMintNFT, "Not enough Ether to mint NFT.");
            require(whitelist[msg.sender], "Minting is not open or your address is not whitelisted");
            require(MerkleProof.verify(merkleProof, merkleRoot, leaf), "Invalid proof");
        }

        _mint(msg.sender, _tokenId);
        // _setTokenURI(_tokenId, tokenURI(_tokenId));
        _setTokenURI(_tokenId, string(abi.encodePacked(baseURI, metadataURI)));
        claimed[_tokenId] = true;
        // tokenCounter++;
    }

    function _tokenNotExists(uint256 _tokenId) internal view returns (bool) {
        try this.ownerOf(_tokenId) returns (address _owner) {
            return (_owner == address(0));
        } catch {
            return true;
        }
    }
}
