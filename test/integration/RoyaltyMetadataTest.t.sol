// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract RoyaltyMetadataTest is CryptoartNFTBase {
    using Strings for uint256;

    function test_RoyaltyAndMetadataInteraction() public {
        // Step 1: update default royalty settings
        address newRoyaltyRecipient = address(0x456);
        uint96 newRoyaltyPercentage = 500; // 5% (500 basis points)
        vm.prank(owner);
        nft.updateRoyalties(payable(newRoyaltyRecipient), newRoyaltyPercentage);

        // Step 2: Mint an NFT to User 1
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        // Check: NFT inherits updated royalty settings
        (address receiver, uint256 royalty) = nft.royaltyInfo(TOKEN_ID, 10_000);
        assertEq(receiver, newRoyaltyRecipient);
        assertEq(royalty, 500);

        // Step 3: Pin token URI
        vm.prank(owner);
        nft.pinTokenURI(TOKEN_ID, 1); // pin to non-redeemable uri

        // Check: tokenURI reflects the pinned metadata
        string memory expectedURI = string.concat(
            nft.baseURI(), string(abi.encodePacked("token-", TOKEN_ID.toString(), "-not-redeemable.json"))
        );
        assertEq(nft.tokenURI(TOKEN_ID), expectedURI);

        // Step 4: burn the NFT
        vm.prank(user1);
        nft.burn(TOKEN_ID);
        vm.expectRevert();
        nft.ownerOf(TOKEN_ID);

        // TokenURI should revert for non-existent token
        vm.expectRevert();
        nft.tokenURI(TOKEN_ID);
    }
}
