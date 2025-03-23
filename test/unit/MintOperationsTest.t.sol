// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {Error} from "../../src/libraries/Error.sol";
import {ICryptoartNFTEvents} from "../interfaces/ICryptoartNFTEvents.sol";
import {ECDSA} from "@openzeppelin-contracts-5.0.2/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.0.2/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

contract MintOperationsTest is CryptoartNFTBase {
    using Strings for uint256;

    uint256 public constant TOKEN_ID = 1;

    CryptoartNFT.MintType mintTypeOpenMint = CryptoartNFT.MintType.OpenMint;
    CryptoartNFT.MintType mintTypeClaim = CryptoartNFT.MintType.Claim;

    function setUp() public override {
        super.setUp();
    }

    // ============ Standard Mint Tests ============

    function test_MintHappyPath() public {
        vm.expectEmit(true, true, false, true);
        emit Minted(user1, TOKEN_ID);

        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);

        // Verify token ownership
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        // Verify token metadata is set correctly
        CryptoartNFT.TokenURISet memory expectedURISet = signingUtils.createTokenURISet(TOKEN_ID);
        (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertEq(uris[0], expectedURISet.uriWhenRedeemable);
        assertEq(uris[1], expectedURISet.uriWhenNotRedeemable);
        assertEq(index, expectedURISet.redeemableDefaultIndex);
        assertTrue(pinned);

        // Verify token URI
        string memory expectedURI = string.concat(BASE_URI, expectedURISet.uriWhenRedeemable);
        assertEq(nft.tokenURI(TOKEN_ID), expectedURI);

        // Verify total supply
        assertEq(nft.totalSupply(), 1);
    }

    function test_MintWithExcessPayment() public {
        uint256 excessPayment = 0.05 ether + TOKEN_PRICE;
        uint256 balanceBefore = user1.balance;

        mintNFT(user1, TOKEN_ID, excessPayment);

        assertEq(user1.balance, balanceBefore - TOKEN_PRICE);
    }

    function test_RevertMintInsufficientPayment() public {
        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        uint256 payment = 0.05 ether;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Mint_InsufficientPayment.selector, data.tokenPrice, payment));
        nft.mint{value: payment}(data, tokenURISet);
    }

    function test_RevertMintInvalidSignature() public {
        uint256 badPrivateKey = 0xB22222;
        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, badPrivateKey);

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);
    }

    function test_RevertMintWithTamperedData() public {
        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        // Tamper with data
        data.tokenPrice = data.tokenPrice * 2;

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);
    }

    function test_RevertMintTokenAlreadyMinted() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data2 =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_AlreadyMinted.selector, TOKEN_ID));
        nft.mint{value: TOKEN_PRICE}(data2, tokenURISet);
    }

    function test_RevertMintWhenPaused() public {
        vm.prank(owner);
        nft.pause();

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert();
        nft.mint{value: TOKEN_PRICE}(data, tokenURISet);
    }

    function test_RevertMintExceedsMaxSupply() public {
        // Deploy a contract with a max supply of 1
        CryptoartNFT nft2 = testFixtures.deployProxyWithNFTInitialized(owner, authoritySigner, nftReceiver, 1, BASE_URI);
        uint256 tokenId2 = 2;

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data1 = createCustomMintData(nft2, user1, TOKEN_ID);
        CryptoartNFT.MintValidationData memory data2 = createCustomMintData(nft2, user1, tokenId2);

        vm.startPrank(user1);
        nft2.mint{value: TOKEN_PRICE}(data1, tokenURISet);
        vm.expectRevert(abi.encodeWithSelector(Error.Mint_ExceedsTotalSupply.selector, 2, 1));
        nft2.mint{value: TOKEN_PRICE}(data2, tokenURISet);
        vm.stopPrank();
    }

    // ============ Claim Tests ============

    function test_ClaimHappyPath() public {
        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeClaim, authoritySignerPrivateKey);

        vm.expectEmit(true, false, false, true);
        emit CryptoartNFT.Claimed(TOKEN_ID);

        vm.prank(user1);
        nft.claim{value: TOKEN_PRICE}(data, tokenURISet);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);
    }

    // ============ Mint With Trade Tests ============

    function test_MintWithTradeHappyPath() public {
        uint256[] memory tradedTokenIds = mintMultipleTokens(user1, 5);

        vm.expectEmit(true, false, false, true);
        emit MintedByTrading(TOKEN_ID, tradedTokenIds);

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        for (uint256 i = 0; i < tradedTokenIds.length; i++) {
            testAssertions.assertTokenOwnership(nft, tradedTokenIds[i], nftReceiver);
        }
    }

    function test_RevertMintWithTradeNotOwned() public {
        uint256 tokenId100 = 100;
        uint256 tokenId101 = 101;

        mintNFT(user1, tokenId100, TOKEN_PRICE);
        mintNFT(user2, tokenId101, TOKEN_PRICE);

        testAssertions.assertTokenOwnership(nft, tokenId100, user1);
        testAssertions.assertTokenOwnership(nft, tokenId101, user2);

        // Create tokens array with mixed ownership
        uint256[] memory tradedTokenIds = new uint256[](2);
        tradedTokenIds[0] = tokenId100;
        tradedTokenIds[1] = tokenId101;

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_NotOwned.selector, tokenId101, user1));
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
    }

    function test_RevertMintWithTradeEmptyArray() public {
        uint256[] memory tradedTokenIds = new uint256[](0);

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_EmptyArray.selector));
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
    }

    function test_RevertMintWithTradeArrayTooLarge() public {
        uint256[] memory tradedTokenIds = new uint256[](51); // max batch size is 50
        for (uint256 i = 0; i < tradedTokenIds.length; i++) {
            tradedTokenIds[i] = 100 + i;
        }

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_MaxSizeExceeded.selector, 51, 50));
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
    }

    // ============ Burn And Mint Tests ============

    function test_BurnAndMintHappyPath() public {
        uint256[] memory burnTokenIds = mintMultipleTokens(user1, 2);

        for (uint256 i = 0; i < burnTokenIds.length; i++) {
            testAssertions.assertTokenOwnership(nft, burnTokenIds[i], user1);
        }

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.expectEmit(true, false, false, true);
        emit MintedByBurning(TOKEN_ID, burnTokenIds);

        // Then burn and mint
        vm.prank(user1);
        nft.burnAndMint{value: TOKEN_PRICE}(burnTokenIds, burnTokenIds.length, data, tokenURISet);

        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        // Verify burned tokens no longer exist
        for (uint256 i = 0; i < burnTokenIds.length; i++) {
            vm.expectRevert();
            nft.ownerOf(burnTokenIds[i]);
        }
    }

    function test_RevertBurnAndMintInsufficientTokens() public {
        uint256[] memory burnTokenIds = mintMultipleTokens(user1, 2);

        for (uint256 i = 0; i < burnTokenIds.length; i++) {
            testAssertions.assertTokenOwnership(nft, burnTokenIds[i], user1);
        }

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        // Attempt to burn with wrong token count
        uint256 requiredBurnCount = 3;

        vm.prank(user1);
        vm.expectRevert(
            abi.encodeWithSelector(Error.Batch_InsufficientTokenAmount.selector, requiredBurnCount, burnTokenIds.length)
        );
        nft.burnAndMint{value: TOKEN_PRICE}(burnTokenIds, requiredBurnCount, data, tokenURISet);
    }

    function test_RevertBurnAndMintDuplicateTokens() public {
        // Mint a token to burn
        mintNFT(user1, 100, TOKEN_PRICE);

        // Create duplicate array
        uint256[] memory burnTokenIds = new uint256[](2);
        burnTokenIds[0] = 100;
        burnTokenIds[1] = 100;

        CryptoartNFT.TokenURISet memory tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        CryptoartNFT.MintValidationData memory data =
            createMintValidationData(user1, TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        // Attempt to burn with duplicate tokens
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_DuplicateTokenIds.selector));
        nft.burnAndMint{value: TOKEN_PRICE}(burnTokenIds, burnTokenIds.length, data, tokenURISet);
    }
}
