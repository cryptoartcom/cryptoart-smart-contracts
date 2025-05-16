// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title TestAssertions
 * @dev Contract with common test assertions for CryptoartNFT
 * Note: Changed from library to contract to inherit Test
 */
contract TestAssertions is Test {
    function assertTokenOwnership(CryptoartNFT nft, uint256 tokenId, address expectedOwner) public view {
        assertEq(nft.ownerOf(tokenId), expectedOwner, "Token owner does not match expected owner");
    }

    function assertTokenURIData(
        CryptoartNFT nft,
        uint256 tokenId,
        CryptoartNFT.TokenURISet memory expected,
        string memory baseURI
    ) public view {
        // Verify token metadata is set correctly
        (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(tokenId);
        assertEq(uris[0], expected.uriWhenRedeemable);
        assertEq(uris[1], expected.uriWhenNotRedeemable);
        assertEq(index, expected.initialURIIndex);
        assertTrue(pinned);

        // Verify token URI
        string memory expectedURI = string.concat(baseURI, expected.uriWhenRedeemable);
        assertEq(nft.tokenURI(tokenId), expectedURI);
    }
}
