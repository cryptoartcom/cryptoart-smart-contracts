// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

contract LifecycleTest is CryptoartNFTBase {
    using Strings for address;

    function test_NFTLifecycle() public {
        // Step 1: Mint NFT
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);

        // Verify initial token URI (should be redeemable by default)
        CryptoartNFT.TokenURISet memory initialTokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
        testAssertions.assertTokenURIData(nft, TOKEN_ID, initialTokenURISet, BASE_URI);

        // Step 2: user adds a creator story
        string memory creatorStory = "Some NFT creator story about the the art";
        vm.prank(user1);
        vm.expectEmit();
        emit CreatorStory(TOKEN_ID, user1, user1.toHexString(), creatorStory);
        nft.addCreatorStory(TOKEN_ID, "", creatorStory);

        // user adds a story
        string memory story = "Some cool art story";
        vm.prank(user1);
        vm.expectEmit();
        emit Story(TOKEN_ID, user1, user1.toHexString(), story);
        nft.addStory(TOKEN_ID, "", story);

        // Step 3: Transfer NFT to another user
        vm.prank(user1);
        nft.safeTransferFrom(user1, user2, TOKEN_ID);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user2);

        // Step 4: User2 marks as redeemable
        bytes memory redeemSignature = signingUtils.createRedeemableSignature(
            user2, TOKEN_ID, nft.nonces(user2), address(nft), authoritySignerPrivateKey
        );
        vm.prank(user2);
        nft.markAsRedeemable(TOKEN_ID, redeemSignature);

        // Verify token URI is the redeemable version
        string memory expectedRedeemableURI = string.concat(BASE_URI, initialTokenURISet.uriWhenRedeemable);
        assertEq(nft.tokenURI(TOKEN_ID), expectedRedeemableURI);

        // Step 5: burn the NFT
        vm.prank(user2);
        nft.burn(TOKEN_ID);
        vm.expectRevert();
        nft.ownerOf(TOKEN_ID);
    }
}
