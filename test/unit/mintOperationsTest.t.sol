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
    uint256 public constant EXCESS_PAYMENT = 0.05 ether;

    CryptoartNFT.TokenURISet public tokenURISet = CryptoartNFT.TokenURISet({
        uriWhenRedeemable: string(abi.encodePacked("token-", TOKEN_ID.toString(), "-redeemable.json")),
        uriWhenNotRedeemable: string(abi.encodePacked("token-", TOKEN_ID.toString(), "-not-redeemable.json")),
        redeemableDefaultIndex: 0
    });

    function test_MintHappyPath() public {
        CryptoartNFT.MintType mintType = CryptoartNFT.MintType.OpenMint;
        CryptoartNFT.MintValidationData memory data = _createMintValidationData(mintType);

        vm.expectEmit(true, true, false, true);
        emit Minted(user1, TOKEN_ID);

        vm.prank(user1);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);

        // Verify token ownership
        _assertTokenOwnership(TOKEN_ID, user1);

        // Verify token metadata is set correctly
        (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertEq(uris[0], tokenURISet.uriWhenRedeemable);
        assertEq(uris[1], tokenURISet.uriWhenNotRedeemable);
        assertEq(index, tokenURISet.redeemableDefaultIndex);
        assertTrue(pinned);

        // Verddify token URI
        string memory expectedURI = string.concat(BASE_URI, tokenURISet.uriWhenRedeemable);
        assertEq(nft.tokenURI(TOKEN_ID), expectedURI);

        // Verify total supply
        assertEq(nft.totalSupply(), 1);
    }

    function test_RevertMintInsufficientPayment() public {
        CryptoartNFT.MintType mintType = CryptoartNFT.MintType.OpenMint;
        CryptoartNFT.MintValidationData memory data = _createMintValidationData(mintType);
        uint256 payment = 0.05 ether;

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Mint_InsufficientPayment.selector, data.tokenPrice, payment));
        nft.mint{value: payment}(data, tokenURISet);
    }

    function test_RevertMintInvalidSignature() public {
        CryptoartNFT.MintType mintType = CryptoartNFT.MintType.OpenMint;
        CryptoartNFT.MintValidationData memory data = _createMintValidationData(mintType);

        data.signature = _createBadMintSignature(mintType);

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);
    }

    function test_RevertMintWithTamperedData() public {
        CryptoartNFT.MintType mintType = CryptoartNFT.MintType.OpenMint;
        CryptoartNFT.MintValidationData memory data = _createMintValidationData(mintType);

        // Tamper with data
        data.tokenPrice = data.tokenPrice * 2;

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.mint{value: data.tokenPrice}(data, tokenURISet);
    }

    function _createMintValidationData(CryptoartNFT.MintType mintType)
        internal
        view
        returns (CryptoartNFT.MintValidationData memory data)
    {
        bytes memory signature = _createMintSignature(mintType);
        data = CryptoartNFT.MintValidationData({
            recipient: user1,
            tokenId: TOKEN_ID,
            tokenPrice: TOKEN_PRICE,
            mintType: mintType,
            signature: signature
        });
    }

    function _createMintSignature(CryptoartNFT.MintType mintType) internal view returns (bytes memory) {
        uint256 nonce = nft.nonces(user1);
        bytes32 contentHash = keccak256(
            abi.encode(
                user1,
                TOKEN_ID,
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

    function _createBadMintSignature(CryptoartNFT.MintType mintType) internal view returns (bytes memory) {
        uint256 nonce = nft.nonces(user1);
        bytes32 contentHash = keccak256(
            abi.encode(
                user1,
                TOKEN_ID,
                mintType,
                TOKEN_PRICE,
                tokenURISet.uriWhenRedeemable,
                tokenURISet.uriWhenNotRedeemable,
                tokenURISet.redeemableDefaultIndex,
                nonce,
                address(nft)
            )
        );
        uint256 badPrivateKey = 0xB22222;
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(contentHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(badPrivateKey, ethSignedMessageHash);

        return abi.encodePacked(r, s, v);
    }

    function _assertTokenOwnership(uint256 tokenId, address expectedOwner) internal view {
        assertEq(nft.ownerOf(tokenId), expectedOwner, "Token owner does not match expected owner");
    }
}
