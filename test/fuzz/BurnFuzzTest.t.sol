// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {Error} from "../../src/libraries/Error.sol";

contract BurnFuzzTest is CryptoartNFTBase {
    function testFuzz_Burn(uint256 tokenId) public {
        mintNFT(user1, tokenId, TOKEN_PRICE, TOKEN_PRICE);

        vm.prank(user1);
        try nft.burn(tokenId) {
            vm.expectRevert();
            nft.ownerOf(tokenId); // Should revert after burn
        } catch {
            assertTrue(false); // Fail if burn unexpectedly reverts
        }
    }

    function testFuzz_BatchBurn(uint8 batchSize) public {
        batchSize = uint8(bound(batchSize, 1, 50));
        vm.deal(user1, 50 ether);
        uint256[] memory tokenIds = mintMultipleTokens(user1, batchSize);

        vm.prank(user1);
        nft.batchBurn(tokenIds);

        // Verify all tokens were burned
        for (uint256 i = 0; i < tokenIds.length; i++) {
            vm.expectRevert();
            nft.ownerOf(tokenIds[i]);
        }
    }

    function testFuzz_BatchBurnWithDuplicates(uint8 batchSize) public {
        batchSize = uint8(bound(batchSize, 2, 50));
        vm.deal(user1, 50 ether);
        uint256[] memory tokenIds = mintMultipleTokens(user1, batchSize);

        // Make a random duplicate
        uint8 duplicatePosition = uint8(bound(uint256(keccak256(abi.encode(batchSize))), 1, batchSize - 1));
        tokenIds[duplicatePosition] = tokenIds[0];

        vm.prank(user1);
        vm.expectRevert();
        nft.batchBurn(tokenIds);
    }
}
