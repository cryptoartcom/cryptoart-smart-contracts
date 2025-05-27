// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/Test.sol";
import {CryptoartNFT} from "../src/CryptoartNFT.sol";
import {SigningUtils} from "./helpers/SigningUtils.sol";
import {TestAssertions} from "./helpers/TestAssertions.sol";
import {TestFixtures} from "./helpers/TestFixtures.sol";

/**
 * @title CryptoartNFTBase
 * @dev Base contract for CryptoartNFT tests with common setup and utilities
 */
contract CryptoartNFTBase is Test {
    // Contract instance
    CryptoartNFT nft;

    // Test accounts
    address public proxyAdmin = makeAddr("proxyAdmin");
    address public owner = makeAddr("owner");
    address public authoritySigner = makeAddr("authoritySigner");
    address public nftReceiver = makeAddr("nftReceiver");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Test key for authoritySigner (for creating signatures)
    uint256 public authoritySignerPrivateKey = 0xA11CE;

    // Test parameters
    string public constant BASE_URI = "ipfs://";
    uint256 public constant MAX_SUPPLY = 10001;
    uint256 public constant TOKEN_PRICE = 0.1 ether;
    uint256 public constant TOKEN_ID = 1;
    uint256 public constant DEFAULT_EXPIRATION = 1 days;
    uint256 public constant REQUIRED_MINT_CLAIM_COUNT = 0;
    uint256 public constant REQUIRED_BURN_TRADE_COUNT = 2;

    // Helper contracts
    SigningUtils public signingUtils;
    TestAssertions public testAssertions;
    TestFixtures public testFixtures;

    function setUp() public virtual {
        // Initialize helper contracts
        signingUtils = new SigningUtils();
        testAssertions = new TestAssertions();
        testFixtures = new TestFixtures();

        // Fund test accounts
        vm.deal(owner, 1 ether);
        vm.deal(user1, 1 ether);
        vm.deal(user2, 1 ether);

        // Set authority signer address to match private key for testing
        authoritySigner = vm.addr(authoritySignerPrivateKey);

        nft = testFixtures.deployTransparentProxyWithNFTInitialized(
            proxyAdmin, owner, authoritySigner, nftReceiver, MAX_SUPPLY, BASE_URI
        );
    }

    function mintNFT(address user, uint256 tokenId, uint256 tokenPrice, uint256 paymentValue) internal {
        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user, tokenId, tokenPrice, CryptoartNFT.MintType.OpenMint, authoritySignerPrivateKey);

        vm.prank(user);
        nft.mint{value: paymentValue}(data, tokenURISet);
    }

    function mintMultipleTokens(address to, uint256 count) internal returns (uint256[] memory) {
        uint256[] memory tokenIds = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            tokenIds[i] = 100 + i;
            mintNFT(to, tokenIds[i], TOKEN_PRICE, TOKEN_PRICE);
        }
        return tokenIds;
    }

    function createMintData(
        address user,
        uint256 tokenId,
        uint256 tokenPrice,
        CryptoartNFT.MintType mintType,
        uint256 signerPrivateKey
    )
        internal
        view
        returns (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet)
    {
        uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;

        tokenURISet = signingUtils.createTokenURISet(tokenId);
        bytes memory signature = signingUtils.createMintSignature(
            user,
            tokenId,
            mintType,
            signerPrivateKey,
            tokenURISet,
            tokenPrice,
            REQUIRED_MINT_CLAIM_COUNT,
            nft.nonces(user),
            deadline,
            address(nft)
        );

        data = CryptoartNFT.MintValidationData({
            recipient: user,
            tokenId: tokenId,
            tokenPrice: tokenPrice,
            mintType: mintType,
            requiredBurnOrTradeCount: REQUIRED_MINT_CLAIM_COUNT,
            deadline: deadline,
            signature: signature
        });
    }
}
