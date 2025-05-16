// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/utils/Strings.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {Error} from "../../src/libraries/Error.sol";
import {SigningUtils} from "../helpers/SigningUtils.sol";
import {IERC4906} from "@openzeppelin/contracts/interfaces/IERC4906.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {IERC7160} from "../../src/interfaces/IERC7160.sol";

contract MetadataManagementTest is CryptoartNFTBase, SigningUtils {
    using Strings for uint256;

    CryptoartNFT.TokenURISet testTokenURISet;

    function setUp() public override {
        super.setUp();
        testTokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
    }

    function test_TokenURIsReturnsCorrectData() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);

        // Verify token metadata is set correctly
        (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertEq(uris[0], testTokenURISet.uriWhenRedeemable);
        assertEq(uris[1], testTokenURISet.uriWhenNotRedeemable);
        assertEq(index, testTokenURISet.initialURIIndex);
        assertTrue(pinned);

        // Verify token URI
        string memory expectedURI = string.concat(BASE_URI, testTokenURISet.uriWhenRedeemable);
        assertEq(nft.tokenURI(TOKEN_ID), expectedURI);
    }

    function test_UpdateMetadataByOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        string memory newRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newRedeemable.json"));
        string memory newNotRedeemableURI =
            string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newNonRedeemable.json"));

        vm.expectEmit(true, false, false, true);
        emit IERC4906.MetadataUpdate(TOKEN_ID);
        vm.prank(owner);
        nft.updateMetadata(TOKEN_ID, newRedeemableURI, newNotRedeemableURI);
        (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertEq(index, 0);
        assertTrue(pinned);
        assertEq(uris[0], newRedeemableURI);
        assertEq(uris[1], newNotRedeemableURI);
    }

    function test_RevertUpdateMetadataByOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        string memory newRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newRedeemable.json"));
        string memory newNotRedeemableURI =
            string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newNonRedeemable.json"));

        vm.expectRevert();
        vm.prank(user1);
        nft.updateMetadata(TOKEN_ID, newRedeemableURI, newNotRedeemableURI);
    }

    function test_RevertUpdateMetadataForNonexistentToken() public {
        // mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        string memory newRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newRedeemable.json"));
        string memory newNotRedeemableURI =
            string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newNonRedeemable.json"));

        vm.expectRevert(abi.encodeWithSelector(Error.Token_DoesNotExist.selector, TOKEN_ID));
        vm.prank(owner);
        nft.updateMetadata(TOKEN_ID, newRedeemableURI, newNotRedeemableURI);
    }

    function test_PinTokenURIByOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        uint8 index = 1;

        vm.expectEmit(true, false, false, true);
        emit IERC7160.TokenUriPinned(TOKEN_ID, index);
        vm.expectEmit();
        emit IERC4906.MetadataUpdate(TOKEN_ID);
        vm.prank(owner);
        nft.pinTokenURI(TOKEN_ID, index);
        (,, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertTrue(pinned);

        assertTrue(nft.hasPinnedTokenURI(TOKEN_ID));
    }

    function test_RevertPinTokenURIByNonOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        uint8 index = 1;

        vm.prank(user1);
        vm.expectRevert();
        nft.pinTokenURI(TOKEN_ID, index);
    }

    function test_MarkAsRedeemable() public {
        // Create data
        uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;
        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, CryptoartNFT.MintType.OpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        nft.mint{value: TOKEN_PRICE}(data, tokenURISet);

        bytes memory signature = createRedeemableSignature(
            user1, TOKEN_ID, nft.nonces(user1), deadline, address(nft), authoritySignerPrivateKey
        );

        vm.prank(owner);
        uint256 nonRedeemableURI = 1;
        nft.pinTokenURI(TOKEN_ID, nonRedeemableURI);

        // Emit events and check asserts
        vm.expectEmit(true, false, false, true);
        emit IERC7160.TokenUriPinned(TOKEN_ID, 0);
        vm.expectEmit();
        emit IERC4906.MetadataUpdate(TOKEN_ID);
        vm.prank(user1);
        nft.markAsRedeemable(TOKEN_ID, signature, deadline);
        (uint256 index,, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertEq(index, 0);
        assertTrue(pinned);

        // Revert if not token owner
        vm.prank(user2);
        vm.expectRevert();
        nft.markAsRedeemable(TOKEN_ID, signature, deadline);
    }

    function test_RevertMarkAsRedeemableWithInvalidSignature() public {
        // Create data
        uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;
        uint256 badPrivateKey = 0xB22222;
        (CryptoartNFT.MintValidationData memory data, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, TOKEN_ID, TOKEN_PRICE, CryptoartNFT.MintType.OpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        nft.mint{value: TOKEN_PRICE}(data, tokenURISet);

        bytes memory signature =
            createRedeemableSignature(user1, TOKEN_ID, nft.nonces(user1), deadline, address(nft), badPrivateKey);

        vm.prank(owner);
        uint256 nonRedeemableURI = 1;
        nft.pinTokenURI(TOKEN_ID, nonRedeemableURI);

        vm.prank(user1);
        vm.expectRevert(Error.Auth_UnauthorizedSigner.selector);
        nft.markAsRedeemable(TOKEN_ID, signature, deadline);
    }

    function test_TokenMetadataAfterTransfer() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        (uint256 initialIndex, string[2] memory initialUris, bool initialPinned) = nft.tokenURIs(TOKEN_ID);

        vm.prank(user1);
        nft.transferFrom(user1, user2, TOKEN_ID);
        assertEq(nft.ownerOf(TOKEN_ID), user2);

        // Verify metadata persists after transfer
        (uint256 postTransferIndex, string[2] memory postTransferUris, bool postTransferPinned) =
            nft.tokenURIs(TOKEN_ID);

        // Metadata should remain the same after transfer
        assertEq(initialIndex, postTransferIndex);
        assertEq(initialUris[0], postTransferUris[0]);
        assertEq(initialUris[1], postTransferUris[1]);
        assertEq(initialPinned, postTransferPinned);

        // Verify token URI is consistent
        string memory expectedURI = string.concat(BASE_URI, postTransferUris[postTransferIndex]);
        assertEq(nft.tokenURI(TOKEN_ID), expectedURI);
    }

    function test_RevertMetadataOperationsForBurnedToken() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);

        // Burn the token
        vm.prank(user1);
        nft.burn(TOKEN_ID);

        // Test tokenURIs revert for burned token
        vm.expectRevert();
        nft.tokenURIs(TOKEN_ID);

        // Test pinTokenURI reverts for burned token
        vm.expectRevert();
        nft.pinTokenURI(TOKEN_ID, 0);

        // Test updateMetadata reverts for burned token
        vm.expectRevert();
        nft.updateMetadata(TOKEN_ID, "new-redeemable.json", "new-not-redeemable.json");

        // Test markAsRedeemable reverts for burned token (even with valid signature)
        uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;
        bytes memory signature = createRedeemableSignature(
            user1, TOKEN_ID, nft.nonces(user1), deadline, address(nft), authoritySignerPrivateKey
        );

        vm.prank(user1);
        vm.expectRevert(); // Since the token doesn't exist, the onlyTokenOwner modifier will revert first
        nft.markAsRedeemable(TOKEN_ID, signature, deadline);
    }
}
