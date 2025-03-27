// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {Error} from "../../src/libraries/Error.sol";
import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

contract MintOperationsTest is CryptoartNFTBase {
    CryptoartNFT.MintType mintTypeOpenMint = CryptoartNFT.MintType.OpenMint;
    CryptoartNFT.MintType mintTypeClaim = CryptoartNFT.MintType.Claim;

    // ============ Standard Mint Tests ============

    function test_MintHappyPath() public {
        vm.expectEmit(true, false, false, true);
        emit Minted(user1, TOKEN_ID);
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);

        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);
        assertEq(nft.totalSupply(), 1);
    }

    function test_MintWithExcessPayment() public {
        uint256 excessPayment = 0.05 ether + TOKEN_PRICE;
        uint256 balanceBefore = user1.balance;

        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, excessPayment);

        assertEq(user1.balance, balanceBefore - TOKEN_PRICE);
    }

    function test_RevertMintInsufficientPayment() public {
        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);
        uint256 payment = 0.05 ether;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Mint_InsufficientPayment.selector, data.tokenPrice, payment));
        nft.mint{value: payment}(data, tokenURISet);
    }

    function test_RevertMintInvalidSignature() public {
        uint256 badPrivateKey = 0xB22222;
        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, badPrivateKey);

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);
    }

    function test_RevertMintWithTamperedData() public {
        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

        // Tamper with data
        data.tokenPrice = data.tokenPrice * 2;

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);
    }

    function test_RevertMintTokenAlreadyMinted() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        (CryptoartNFT.MintValidationData memory data2, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_AlreadyMinted.selector, TOKEN_ID));
        nft.mint{value: TOKEN_PRICE}(data2, tokenURISet);
    }

    function test_RevertMintWhenPaused() public {
        vm.prank(owner);
        nft.pause();

        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert();
        nft.mint{value: TOKEN_PRICE}(data, tokenURISet);
    }

    function test_RevertMintExceedsMaxSupply() public {
        vm.prank(owner);
        nft.setMaxSupply(1);
        uint256 tokenId2 = 2;
        (CryptoartNFT.MintValidationData memory data1, CryptoartNFT.TokenURISet memory tokenURISet1) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);
        (CryptoartNFT.MintValidationData memory data2, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, tokenId2, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.startPrank(user1);
        nft.mint{value: TOKEN_PRICE}(data1, tokenURISet1);
        vm.expectRevert(abi.encodeWithSelector(Error.Mint_ExceedsTotalSupply.selector, 2, 1));
        nft.mint{value: TOKEN_PRICE}(data2, tokenURISet);
        vm.stopPrank();
    }

    // ============ Claim Tests ============

    function test_ClaimHappyPath() public {
        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeClaim, authoritySignerPrivateKey);

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

        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

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

        mintNFT(user1, tokenId100, TOKEN_PRICE, TOKEN_PRICE);
        mintNFT(user2, tokenId101, TOKEN_PRICE, TOKEN_PRICE);

        testAssertions.assertTokenOwnership(nft, tokenId100, user1);
        testAssertions.assertTokenOwnership(nft, tokenId101, user2);

        // Create tokens array with mixed ownership
        uint256[] memory tradedTokenIds = new uint256[](2);
        tradedTokenIds[0] = tokenId100;
        tradedTokenIds[1] = tokenId101;

        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_NotOwned.selector, tokenId101, user1));
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
    }

    function test_RevertMintWithTradeEmptyArray() public {
        uint256[] memory tradedTokenIds = new uint256[](0);

        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_EmptyArray.selector));
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
    }

    function test_RevertMintWithTradeArrayTooLarge() public {
        uint256[] memory tradedTokenIds = new uint256[](51); // max batch size is 50
        for (uint256 i = 0; i < tradedTokenIds.length; i++) {
            tradedTokenIds[i] = 100 + i;
        }

        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

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

        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

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

        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

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
        mintNFT(user1, 100, TOKEN_PRICE, TOKEN_PRICE);

        // Create duplicate array
        uint256[] memory burnTokenIds = new uint256[](2);
        burnTokenIds[0] = 100;
        burnTokenIds[1] = 100;

        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, mintTypeOpenMint, authoritySignerPrivateKey);

        // Attempt to burn with duplicate tokens
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_DuplicateTokenIds.selector, burnTokenIds[0]));
        nft.burnAndMint{value: TOKEN_PRICE}(burnTokenIds, burnTokenIds.length, data, tokenURISet);
    }
}
