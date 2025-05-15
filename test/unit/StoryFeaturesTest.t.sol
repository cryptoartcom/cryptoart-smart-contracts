// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";
import {IStory} from "../../src/interfaces/IStory.sol";
import {Error} from "../../src/libraries/Error.sol";

contract StoryFeaturesTest is CryptoartNFTBase {
    using Strings for address;

    function test_addCollectionStory() public {
        string memory collectionStory = "Some cool story for the NFT collection";
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit IStory.CollectionStory(owner, "someCreatorName", collectionStory);
        nft.addCollectionStory("someCreatorName", collectionStory);
    }

    function test_RevertaddCollectionStoryIfNonOwner() public {
        string memory collectionStory = "Some cool story for the NFT collection";
        vm.prank(user1);
        vm.expectRevert();
        nft.addCollectionStory("", collectionStory);
    }

    function test_addCreatorStory() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        string memory creatorStory = "Some cool creator story";
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit IStory.CreatorStory(TOKEN_ID, owner, "someCreatorName", creatorStory);
        nft.addCreatorStory(TOKEN_ID, "someCreatorName", creatorStory);
    }

    function test_RevertaddCreatoryStoryIfNotOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        string memory creatorStory = "Some cool creator story";
        vm.prank(user1);
        vm.expectRevert();
        nft.addCreatorStory(TOKEN_ID, "", creatorStory);
    }

    function test_addStory() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit IStory.Story(TOKEN_ID, user1, "someCreatorName", "Story");
        nft.addStory(TOKEN_ID, "someCreatorName", "Story");
    }

    function test_RevertaddStoryIfNotTokenOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_NotOwned.selector, TOKEN_ID, user2));
        nft.addStory(TOKEN_ID, "", "Story");
    }

    function test_toggleVisibility_tokenOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        vm.prank(user1);
        vm.expectEmit(true, true, false, true);
        emit CryptoartNFT.ToggleStoryVisibility(TOKEN_ID, "story1", true);
        nft.toggleStoryVisibility(TOKEN_ID, "story1", true);
    }

    function test_toggleVisibility_contractOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        vm.prank(owner);
        vm.expectEmit(true, true, false, true);
        emit CryptoartNFT.ToggleStoryVisibility(TOKEN_ID, "story1", false);
        nft.toggleStoryVisibility(TOKEN_ID, "story1", false);
    }

    function test_ReverttoggleVisibilityIfNotAuthorized() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE, TOKEN_PRICE);
        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(Error.Auth_Unauthorized.selector, user2));
        nft.toggleStoryVisibility(TOKEN_ID, "story1", true);
    }
}
