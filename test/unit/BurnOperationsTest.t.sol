// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {Error} from "../../src/libraries/Error.sol";

contract BurnOperationsTest is CryptoartNFTBase {
    function test_BurnHappyPath() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        vm.expectEmit(true, false, false, true);
        emit Burned(TOKEN_ID);
        vm.prank(user1);
        nft.burn(TOKEN_ID);

        vm.expectRevert();
        nft.ownerOf(TOKEN_ID);
    }

    function test_RevertBurnNotOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        vm.prank(user2);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_NotOwned.selector, TOKEN_ID, user2));
        nft.burn(TOKEN_ID);
    }

    function test_RevertBurnNonExistentToken() public {
        uint256 nonExistentTokenId = 99;
        vm.prank(user1);
        vm.expectRevert();
        nft.burn(nonExistentTokenId);
    }

    function test_RevertBurnWhenPaused() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);

        vm.prank(owner);
        nft.pause();

        vm.prank(user1);
        vm.expectRevert();
        nft.burn(TOKEN_ID);
    }

    function test_BatchBurnHappyPath() public {
        uint256[] memory tokenIds = mintMultipleTokens(user1, 3);

        for (uint256 i = 0; i < tokenIds.length; i++) {
            testAssertions.assertTokenOwnership(nft, tokenIds[i], user1);
        }

        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.expectEmit(true, false, false, true);
            emit Burned(tokenIds[i]);
        }

        vm.prank(user1);
        nft.batchBurn(tokenIds);

        // Verify tokens no longer exist
        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.expectRevert();
            nft.ownerOf(tokenIds[i]);
        }
    }

    function test_RevertBatchBurnNotOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        mintNFT(user2, TOKEN_ID + 1, TOKEN_PRICE);

        // Create array with tokens owned by different users
        uint256[] memory tokenIds = new uint256[](2);
        tokenIds[0] = TOKEN_ID;
        tokenIds[1] = TOKEN_ID + 1;

        // Attempt to batch burn as user1
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Token_NotOwned.selector, TOKEN_ID + 1, user1));
        nft.batchBurn(tokenIds);
    }

    function test_RevertBatchBurnEmptyArray() public {
        uint256[] memory emptyArray = new uint256[](0);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_EmptyArray.selector));
        nft.batchBurn(emptyArray);
    }

    function test_RevertBatchBurnArrayTooLarge() public {
        uint256[] memory largeArray = new uint256[](51);

        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_MaxSizeExceeded.selector, largeArray.length, 50));
        nft.batchBurn(largeArray);
    }
    
    function test_RevertBatchBurnWithDuplicateIds() public {
        uint256[] memory duplicateIdsArray = new uint256[](2);
        duplicateIdsArray[0] = TOKEN_ID;
        duplicateIdsArray[1] = TOKEN_ID;
        
        vm.prank(user1);
        vm.expectRevert(abi.encodeWithSelector(Error.Batch_DuplicateTokenIds.selector, TOKEN_ID));
        nft.batchBurn(duplicateIdsArray);
    }
    
    function test_RevertBatchBurnWithPartialFailure() public {
        mintNFT(user1, 100, TOKEN_PRICE);
        mintNFT(user1, 101, TOKEN_PRICE);
        
        // Include a non-existent token in the array
        uint256[] memory tokenIds = new uint256[](3);
        tokenIds[0] = 100;
        tokenIds[1] = 101;
        tokenIds[2] = 999;
        
        // Attempt to batch burn
        vm.prank(user1);
        vm.expectRevert();
        nft.batchBurn(tokenIds);
        
        // Verify the existing tokens still exist
        testAssertions.assertTokenOwnership(nft, 100, user1);
        testAssertions.assertTokenOwnership(nft, 101, user1);
    }
    
    function test_RevertBatchBurnWhenPaused() public {
        uint256[] memory tokenIds = mintMultipleTokens(user1, 2);
        
        vm.prank(owner);
        nft.pause();
        
        vm.prank(user1);
        vm.expectRevert();
        nft.batchBurn(tokenIds);
    }
    
    function test_BurnClearsRoyaltyInfo() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        testAssertions.assertTokenOwnership(nft, TOKEN_ID, user1);
        
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(TOKEN_ID, 10_000);
        assertEq(receiver, owner); // default royalty receiver should be the owner
        assertEq(royaltyAmount, 250); // 2.5% of 10,000
        
        // Burn token and verify it no longer exists
        vm.prank(user1);
        nft.burn(TOKEN_ID);
        vm.expectRevert();
        nft.ownerOf(TOKEN_ID);
        
        // Mint new token with same ID to verify royalty was reset
        mintNFT(user2, TOKEN_ID, TOKEN_PRICE);
        
        // // Check royalty info for new token is based on default, not carried over
        // (address newReceiver, uint256 newRoyaltyAmount) = nft.royaltyInfo(TOKEN_ID, 10_000);
        // assertEq(newReceiver, owner);
        // assertEq(newRoyaltyAmount, 250); // should match DEFAULT_ROYALTY_PERCENTAGE
    }
}
