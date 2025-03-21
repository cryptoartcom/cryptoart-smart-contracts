// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {ECDSA} from "@openzeppelin-contracts-5.0.2/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.0.2/utils/cryptography/MessageHashUtils.sol";
import {ERC1967Proxy} from "@openzeppelin-contracts-5.0.2/proxy/ERC1967/ERC1967Proxy.sol";
import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import {IERC7160} from "../src/interfaces/IERC7160.sol";

contract CryptoartNFTBase is Test {
    using Strings for uint256;

    CryptoartNFT nft;

    // Test accounts
    address public owner = makeAddr("owner");
    address public authoritySigner = makeAddr("authoritySigner");
    address public nftReceiver = makeAddr("nftReceiver");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Test key for authoritySigner (for creating signatures)
    uint256 public authoritySignerPrivateKey = 0xA11CE;

    // Test parameters
    string public constant BASE_URI = "ipfs://";
    uint256 public constant MAX_SUPPLY = 10000;

    function setUp() public virtual {
        // Fund test accounts
        vm.deal(owner, 1 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        // Set authority signer address to match private key for testing
        authoritySigner = vm.addr(authoritySignerPrivateKey);

        nft = _deployProxyWithNFTInitialized(owner, authoritySigner, nftReceiver, MAX_SUPPLY, BASE_URI);
    }

    function _deployProxyWithNFTInitialized(
        address _owner,
        address _authoritySigner,
        address _nftReceiver,
        uint256 _maxSupply,
        string memory _baseURI
    ) internal returns (CryptoartNFT) {
        // Deploy implementation
        CryptoartNFT implementation = new CryptoartNFT();

        // Initialize data
        bytes memory initData = abi.encodeWithSelector(
            CryptoartNFT.initialize.selector, _owner, _authoritySigner, _nftReceiver, _maxSupply, _baseURI
        );

        // Create proxy pointing to implementation and initData to call the initialize function
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // Typecast proxy contract as the implementation contract
        return CryptoartNFT(address(proxy));
    }

    function _createMintSignature(
        address recipient,
        uint256 tokenId,
        CryptoartNFT.MintType mintType,
        uint256 tokenPrice,
        string memory uriWhenRedeemable,
        string memory uriWhenNotRedeemable,
        uint256 redeemableDefaultIndex,
        uint256 nonce,
        address contractAddress
    ) internal view returns (bytes memory) {
        bytes32 contentHash = keccak256(
            abi.encode(
                recipient,
                tokenId,
                mintType,
                tokenPrice,
                uriWhenRedeemable,
                uriWhenNotRedeemable,
                redeemableDefaultIndex,
                nonce,
                contractAddress
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(contentHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authoritySignerPrivateKey, ethSignedMessageHash);

        return abi.encodePacked(r, s, v);
    }

    function _createMintParams(address recipient, uint256 tokenId)
        internal
        view
        returns (CryptoartNFT.MintValidationData memory validationData, CryptoartNFT.TokenURISet memory tokenURISet)
    {
        uint256 tokenPrice = 0.1 ether;
        string memory uriWhenRedeemable = string(abi.encodePacked("token-", tokenId.toString(), "-redeemable.json"));
        string memory uriWhenNotRedeemable =
            string(abi.encodePacked("token-", tokenId.toString(), "-not-redeemable.json"));
        uint8 redeemableDefaultIndex = 0; // Default to redeemable

        uint256 nonce = nft.nonces(recipient);
        CryptoartNFT.MintType mintType = CryptoartNFT.MintType.OpenMint;

        bytes memory signature = _createMintSignature(
            recipient,
            tokenId,
            mintType,
            tokenPrice,
            uriWhenRedeemable,
            uriWhenNotRedeemable,
            redeemableDefaultIndex,
            nonce,
            address(nft)
        );

        validationData = CryptoartNFT.MintValidationData({
            recipient: recipient,
            tokenId: tokenId,
            tokenPrice: tokenPrice,
            mintType: mintType,
            signature: signature
        });

        tokenURISet = CryptoartNFT.TokenURISet({
            uriWhenRedeemable: uriWhenRedeemable,
            uriWhenNotRedeemable: uriWhenNotRedeemable,
            redeemableDefaultIndex: redeemableDefaultIndex
        });
    }

    function _createUnpairSignature(address _owner, uint256 tokenId) internal view returns (bytes memory) {
        uint256 nonce = nft.nonces(owner);
        bytes32 contentHash = keccak256(abi.encode(_owner, tokenId, nonce, block.chainid, address(nft)));
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(contentHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authoritySignerPrivateKey, ethSignedMessageHash);

        return abi.encodePacked(r, s, v);
    }

    function _mintNFT(address user, uint256 tokenId) internal returns (uint256) {
        (CryptoartNFT.MintValidationData memory validationData, CryptoartNFT.TokenURISet memory tokenURISet) =
            _createMintParams(user, tokenId);

        vm.prank(user);
        nft.mint{value: validationData.tokenPrice}(validationData, tokenURISet);

        return tokenId;
    }

    function _batchMintNFTS(address user, uint256[] memory tokenIds) internal {
        for (uint256 i = 0; i < tokenIds.length; i++) {
            _mintNFT(user, tokenIds[i]);
        }
    }

    function _assertTokenOwnership(uint256 tokenId, address expectedOwner) internal view {
        assertEq(nft.ownerOf(tokenId), expectedOwner, "Token owner does not match expected owner");
    }
}
