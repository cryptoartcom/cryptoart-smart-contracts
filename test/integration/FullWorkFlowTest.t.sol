// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {IStory} from "../../src/interfaces/IStory.sol";

contract FullWorkFlow is CryptoartNFTBase {
    using Strings for address;

    /// @dev tests full workflow from minting, admin updates, unpairing
    function test_FullWorkFlow() public {
        // --- Mint Workflow ---
        uint256 tokenId = 1;
        (CryptoartNFT.MintValidationData memory mintData, CryptoartNFT.TokenURISet memory tokenURISet) =
            createMintData(user1, tokenId, TOKEN_PRICE, CryptoartNFT.MintType.OpenMint, authoritySignerPrivateKey);

        vm.prank(user1);
        nft.mint{value: TOKEN_PRICE}(mintData, tokenURISet);

        // Verify ownership and initial metadata
        assertEq(nft.ownerOf(tokenId), user1);
        string memory initialRedeemableURI = tokenURISet.uriWhenRedeemable;
        string memory expectedInitialURI = string.concat(BASE_URI, initialRedeemableURI);
        assertEq(nft.tokenURI(tokenId), expectedInitialURI);

        // --- Admin Updates ---
        string memory newRedeemableURI = "ipfs://new-redeemable.json";
        string memory newNotRedeemableURI = "ipfs://new-not-redeemable.json";
        vm.prank(owner);
        nft.updateMetadata(tokenId, newRedeemableURI, newNotRedeemableURI);

        // Verify updated metadata
        (, string[2] memory uris, bool pinned) = nft.tokenURIs(tokenId);
        assertEq(uris[0], newRedeemableURI);
        assertEq(uris[1], newNotRedeemableURI);
        assertTrue(pinned);

        // --- Unpair Workflow ---
        uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;
        bytes memory unpairSignature = signingUtils.createRedeemableSignature(
            user1, tokenId, nft.nonces(user1), deadline, address(nft), authoritySignerPrivateKey
        );

        vm.prank(authoritySigner);
        uint256 nonRedeemableURI = 1;
        nft.pinTokenURI(tokenId, nonRedeemableURI);

        vm.prank(user1);
        nft.markAsRedeemable(tokenId, unpairSignature, deadline);

        // Verify token URI reflects redeemable state
        string memory expectedRedeemableURI = string.concat(BASE_URI, newRedeemableURI);
        assertEq(nft.tokenURI(tokenId), expectedRedeemableURI);

        // --- IStory Workflow ---
        string memory storyContent = "Once upon a time, in a galaxy really, really close by...";
        vm.prank(user1);
        vm.expectEmit();
        emit IStory.Story(tokenId, user1, "user1CollectorName", storyContent);
        nft.addStory(tokenId, "user1CollectorName", storyContent);
    }
}
