// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {Error} from "../../src/libraries/Error.sol";

contract MetadataFuzzTest is CryptoartNFTBase {
    function testFuzz_UpdateMetadata(string calldata newRedeemableURI, string calldata newNotRedeemableURI) public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);

        // Update metadata as owner
        vm.prank(owner);
        nft.updateMetadata(TOKEN_ID, newRedeemableURI, newNotRedeemableURI);

        // Verify the metadata
        (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertEq(uris[0], newRedeemableURI, "Redeemable URI mismatch");
        assertEq(uris[1], newNotRedeemableURI, "Not redeemable URI mismatch");
        assertEq(index, 0, "Pinned index should remain 0");
        assertTrue(pinned, "Token should remain pinned");
    }

    function testFuzz_PinTokenURI(uint256 index) public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);

        vm.prank(authoritySigner);
        if (index < 2) {
            nft.pinTokenURI(TOKEN_ID, index);
            (uint256 pinnedIndex,, bool pinned) = nft.tokenURIs(TOKEN_ID);
            assertEq(pinnedIndex, index, "Pinned index mismatch");
            assertTrue(pinned, "Token should be pinned");
        } else {
            vm.expectRevert(abi.encodeWithSelector(Error.Token_IndexOutOfBounds.selector, TOKEN_ID, index, 1));
            nft.pinTokenURI(TOKEN_ID, index);
        }
    }

    function testFuzz_MarkAsRedeemable(bytes calldata signatureFuzz) public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;

        // Use a valid signature but allow fuzzing to test invalid ones
        bytes memory validSignature = signingUtils.createRedeemableSignature(
            user1, TOKEN_ID, nft.nonces(user1), deadline, address(nft), authoritySignerPrivateKey
        );

        vm.prank(user1);
        try nft.markAsRedeemable(TOKEN_ID, signatureFuzz, deadline) {
            // If it succeeds with a fuzzed signature, it should only be the valid one
            assertEq(keccak256(signatureFuzz), keccak256(validSignature), "Only valid signature should succeed");
            (uint256 pinnedIndex,, bool pinned) = nft.tokenURIs(TOKEN_ID);
            assertEq(pinnedIndex, 0, "Token should be pinned to redeemable URI (index 0)");
            assertTrue(pinned, "Token should be pinned");
        } catch {
            // Expected to fail for invalid signatures
        }
    }

    function testFuzz_UpdateRoyalties(uint96 royaltyPercentage) public {
        uint256 customTokenPriceToTestRoyaltyCalc = 10_000;
        vm.prank(owner);
        if (royaltyPercentage > 1000) {
            vm.expectRevert();
        }
        nft.updateRoyalties(payable(owner), royaltyPercentage);

        if (royaltyPercentage <= 1000) {
            (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(TOKEN_ID, customTokenPriceToTestRoyaltyCalc);
            assertEq(receiver, owner, "Royalty receiver mismatch");
            assertEq(royaltyAmount, royaltyPercentage, "Royalty amount mismatch");
        }
    }

    function testFuzz_SetTokenRoyalty(uint96 feeNumerator) public {
        uint256 customTokenPriceToTestRoyaltyCalc = 10_000;
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);

        vm.prank(owner);
        if (feeNumerator > 1000) {
            vm.expectRevert();
        }
        nft.setTokenRoyalty(TOKEN_ID, owner, feeNumerator);

        if (feeNumerator <= 1000) {
            (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(TOKEN_ID, customTokenPriceToTestRoyaltyCalc);
            assertEq(receiver, owner, "Token royalty receiver mismatch");
            assertEq(royaltyAmount, feeNumerator, "Token royalty amount mismatch");
        }
    }
}
