// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";

contract MetadataManagementTest is CryptoartNFTBase {
    
    function setUp() public override {
        super.setUp();
        tokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
    }
   
    function test_TokenURIsReturnsCorrectData() public {
       mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
       
       // Verify token metadata is set correctly 
       (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(TOKEN_ID);
       assertEq(uris[0], tokenURISet.uriWhenRedeemable);
       assertEq(uris[1], tokenURISet.uriWhenNotRedeemable);
       assertEq(index, tokenURISet.redeemableDefaultIndex);
       assertTrue(pinned);
       
       // Verify token URI
       string memory expectedURI = string.concat(BASE_URI, tokenURISet.uriWhenRedeemable);
       assertEq(nft.tokenURI(TOKEN_ID), expectedURI);       
    }
}