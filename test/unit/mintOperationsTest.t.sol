// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {Error} from "../../src/libraries/Error.sol";
import {ICryptoartNFTEvents} from "../ICryptoartNFTEvents.sol";
import {ECDSA} from "@openzeppelin-contracts-5.0.2/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.0.2/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

contract MintOperationsTest is CryptoartNFTBase, ICryptoartNFTEvents {
    using Strings for uint256;

    uint256 public constant TOKEN_PRICE = 0.1 ether;
    uint256 public constant TOKEN_ID = 1;

    CryptoartNFT.MintType mintTypeOpenMint = CryptoartNFT.MintType.OpenMint;

    CryptoartNFT.TokenURISet public tokenURISet = CryptoartNFT.TokenURISet({
        uriWhenRedeemable: string(abi.encodePacked("token-", TOKEN_ID.toString(), "-redeemable.json")),
        uriWhenNotRedeemable: string(abi.encodePacked("token-", TOKEN_ID.toString(), "-not-redeemable.json")),
        redeemableDefaultIndex: 0
    });

    function test_MintHappyPath() public {
        vm.expectEmit(true, true, false, true);
        emit Minted(user1, TOKEN_ID);
        _mintNFT(user1, TOKEN_ID, TOKEN_PRICE);

        // Verify token ownership
        _assertTokenOwnership(TOKEN_ID, user1);

        // Verify token metadata is set correctly
        (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertEq(uris[0], tokenURISet.uriWhenRedeemable);
        assertEq(uris[1], tokenURISet.uriWhenNotRedeemable);
        assertEq(index, tokenURISet.redeemableDefaultIndex);
        assertTrue(pinned);

        // Verify token URI
        string memory expectedURI = string.concat(BASE_URI, tokenURISet.uriWhenRedeemable);
        assertEq(nft.tokenURI(TOKEN_ID), expectedURI);

        // Verify total supply
        assertEq(nft.totalSupply(), 1);
    }

    function test_MintWithExcessPayment() public {
        uint256 excessPayment = 0.05 ether + TOKEN_PRICE;
        uint256 balanceBefore = user1.balance;
        _mintNFT(user1, TOKEN_ID, excessPayment);
        assertEq(user1.balance, balanceBefore - TOKEN_PRICE);
    }

    function test_RevertMintInsufficientPayment() public {
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        uint256 payment = 0.05 ether;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Mint_InsufficientPayment.selector, data.tokenPrice, payment));
        nft.mint{value: payment}(data, tokenURISet);
    }

    function test_RevertMintInvalidSignature() public {
        uint256 badPrivateKey = 0xB22222;
        CryptoartNFT.MintValidationData memory data = _createMintValidationData(TOKEN_ID, mintTypeOpenMint, badPrivateKey);

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);
    }

    function test_RevertMintWithTamperedData() public {
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);

        // Tamper with data
        data.tokenPrice = data.tokenPrice * 2;

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);
    }

    function test_RevertMintTokenAlreadyMinted() public {
        _mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        _assertTokenOwnership(TOKEN_ID, user1);

        CryptoartNFT.MintValidationData memory data2 =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_AlreadyMinted.selector, TOKEN_ID));
        nft.mint{value: TOKEN_PRICE}(data2, tokenURISet);
    }

    function test_RevertMintWhenPaused() public {
        vm.prank(owner);
        nft.pause();

        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        vm.prank(user1);
        vm.expectRevert();
        nft.mint{value: TOKEN_PRICE}(data, tokenURISet);
    }

    function test_RevertMintExceedsMaxSupply() public {
        // Deploy a contract and custom data with a max supply of 1
        CryptoartNFT nft2 = _deployProxyWithNFTInitialized(owner, authoritySigner, nftReceiver, 1, BASE_URI);
        uint256 tokenId2 = 2;
        CryptoartNFT.MintValidationData memory data1 = _createCustomMintData(nft2, user1, TOKEN_ID);
        CryptoartNFT.MintValidationData memory data2 = _createCustomMintData(nft2, user1, tokenId2);

        vm.startPrank(user1);
        nft2.mint{value: TOKEN_PRICE}(data1, tokenURISet);
        vm.expectRevert(abi.encodeWithSelector(Error.Mint_ExceedsTotalSupply.selector, 2, 1));
        nft2.mint{value: TOKEN_PRICE}(data2, tokenURISet);
        vm.stopPrank();
    }
    
    function test_ClaimHappyPath() public {
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, CryptoartNFT.MintType.Claim, authoritySignerPrivateKey);
        
        vm.expectEmit(true, false, false, true);
        emit CryptoartNFT.Claimed(TOKEN_ID);
        
        vm.prank(user1);
        nft.claim{value: TOKEN_PRICE}(data, tokenURISet);
        _assertTokenOwnership(TOKEN_ID, user1);
    }
   
    function test_MintWithTradeHappyPath() public {
        uint256[] memory tradedTokenIds = new uint256[](2);
        tradedTokenIds[0] = 2;
        tradedTokenIds[1] = 3;
        tradedTokenIds[1] = 4;
        tradedTokenIds[1] = 5;
        tradedTokenIds[1] = 6;
                
        for (uint256 i = 0; i < tradedTokenIds.length; i++) {
            _mintNFT(user1, tradedTokenIds[i], TOKEN_PRICE);
        }
        
        vm.expectEmit(true, false, false, true);
        emit MintedByTrading(TOKEN_ID, tradedTokenIds);
        
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        
        vm.prank(user1);
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
        _assertTokenOwnership(TOKEN_ID, user1);
        
        for (uint256 i = 0; i < tradedTokenIds.length; i++) {
            _assertTokenOwnership(tradedTokenIds[i], nftReceiver);
        }
    }
    
    function test_RevertMintWithTradeNotOwned() public {
        uint256 tokenId100 = 100;
        uint256 tokenId101 = 101;
        _mintNFT(user1, tokenId100, TOKEN_PRICE);
        _mintNFT(user2, tokenId101, TOKEN_PRICE);
        
        // Create tokens array with mixed ownerhsip
        uint256[] memory tradedTokenIds = new uint256[](2);
        tradedTokenIds[0] = tokenId100;
        tradedTokenIds[1] = tokenId101;
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_NotOwned.selector, tokenId101, user1));
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
    }
    
    function test_RevertMintWithTradeEmptyArray() public {
        uint256[] memory tradedTokenIds = new uint256[](0);
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_EmptyArray.selector));
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
    }
    
    function test_RevertMintWithTradeArrayTooLarge() public {
        uint256[] memory tradedTokenIds = new uint256[](51); // max batch size is 50
        for (uint256 i = 0; i < tradedTokenIds.length; i++) {
            tradedTokenIds[i] = 100 + i;
        }
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_MaxSizeExceeded.selector, 51, 50));
        nft.mintWithTrade{value: TOKEN_PRICE}(tradedTokenIds, data, tokenURISet);
    }
    
    function test_BurnAndMintHappyPath() public {
        // First mint some tokens to burn
        uint256[] memory burnTokenIds = new uint256[](2);
        burnTokenIds[0] = 100;
        burnTokenIds[1] = 101;
        for (uint256 i = 0; i < burnTokenIds.length; i++) {
            _mintNFT(user1, burnTokenIds[i], TOKEN_PRICE);
        }
        
        for (uint256 i = 0; i < burnTokenIds.length; i++) {
            _assertTokenOwnership(burnTokenIds[i], user1);
        }
        
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(TOKEN_ID, mintTypeOpenMint, authoritySignerPrivateKey);
        
        vm.expectEmit(true, false, false, true);
        emit MintedByBurning(TOKEN_ID, burnTokenIds);
        
        // Then burn and mint
        vm.prank(user1);
        nft.burnAndMint{value: TOKEN_PRICE}(burnTokenIds, burnTokenIds.length, data, tokenURISet);
        
       _assertTokenOwnership(TOKEN_ID, user1);
      
       // Verify burned tokens no longer exist
       for (uint256 i = 0; i < burnTokenIds.length; i++) {
           vm.expectRevert();
           nft.ownerOf(burnTokenIds[i]);
       }
    }
    
    function _mintNFT(address user, uint256 tokenId, uint256 paymentValue) internal {
        CryptoartNFT.MintValidationData memory data =
            _createMintValidationData(tokenId, mintTypeOpenMint, authoritySignerPrivateKey);
        vm.prank(user);
        nft.mint{value: paymentValue}(data, tokenURISet);
    }

    function _createMintValidationData(uint256 tokenId, CryptoartNFT.MintType mintType, uint256 authoritySignerPrivateKey)
        internal
        view
        returns (CryptoartNFT.MintValidationData memory data)
    {
        bytes memory signature = _createMintSignature(tokenId, mintType, authoritySignerPrivateKey);
        data = CryptoartNFT.MintValidationData({
            recipient: user1,
            tokenId: tokenId,
            tokenPrice: TOKEN_PRICE,
            mintType: mintType,
            signature: signature
        });
    }

    function _createMintSignature(uint256 tokenId, CryptoartNFT.MintType mintType, uint256 authoritySignerPrivateKey)
        internal
        view
        returns (bytes memory)
    {
        uint256 nonce = nft.nonces(user1);
        bytes32 contentHash = keccak256(
            abi.encode(
                user1,
                tokenId,
                mintType,
                TOKEN_PRICE,
                tokenURISet.uriWhenRedeemable,
                tokenURISet.uriWhenNotRedeemable,
                tokenURISet.redeemableDefaultIndex,
                nonce,
                address(nft)
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(contentHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authoritySignerPrivateKey, ethSignedMessageHash);

        return abi.encodePacked(r, s, v);
    }
    
    function _createCustomMintData(CryptoartNFT nft, address user, uint256 tokenId)
        internal
        view
        returns (CryptoartNFT.MintValidationData memory data)
    {
        // Create signature
        bytes32 contentHash = keccak256(
            abi.encode(
                user,
                tokenId,
                mintTypeOpenMint,
                TOKEN_PRICE,
                tokenURISet.uriWhenRedeemable,
                tokenURISet.uriWhenNotRedeemable,
                tokenURISet.redeemableDefaultIndex,
                nft.nonces(user1),
                address(nft)
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(contentHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authoritySignerPrivateKey, ethSignedMessageHash);
        bytes memory signature = abi.encodePacked(r, s, v);

        data = CryptoartNFT.MintValidationData({
            recipient: user,
            tokenId: tokenId,
            tokenPrice: TOKEN_PRICE,
            mintType: mintTypeOpenMint,
            signature: signature
        });
    }

    function _assertTokenOwnership(uint256 tokenId, address expectedOwner) internal view {
        assertEq(nft.ownerOf(tokenId), expectedOwner, "Token owner does not match expected owner");
    }
}
