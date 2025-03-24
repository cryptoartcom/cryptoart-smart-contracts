// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {Error} from "../../src/libraries/Error.sol";

contract MetadataManagementTest is CryptoartNFTBase {
    using Strings for uint256;
    
    CryptoartNFT.TokenURISet testTokenURISet;

    function setUp() public override {
        super.setUp();
        testTokenURISet = signingUtils.createTokenURISet(TOKEN_ID);
    }

    function test_TokenURIsReturnsCorrectData() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);

        // Verify token metadata is set correctly
        (uint256 index, string[2] memory uris, bool pinned) = nft.tokenURIs(TOKEN_ID);
        assertEq(uris[0], testTokenURISet.uriWhenRedeemable);
        assertEq(uris[1], testTokenURISet.uriWhenNotRedeemable);
        assertEq(index, testTokenURISet.redeemableDefaultIndex);
        assertTrue(pinned);

        // Verify token URI
        string memory expectedURI = string.concat(BASE_URI, testTokenURISet.uriWhenRedeemable);
        assertEq(nft.tokenURI(TOKEN_ID), expectedURI);
    }

    function test_UpdateMetadataByOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        string memory newRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newRedeemable.json"));
        string memory newNotRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newNonRedeemable.json"));
        
        vm.expectEmit(true, false, false, true);
        emit MetadataUpdate(TOKEN_ID);
        vm.prank(owner);
        nft.updateMetadata(TOKEN_ID, newRedeemableURI, newNotRedeemableURI);
    }
    
    function test_RevertUpdateMetadataByOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        string memory newRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newRedeemable.json"));
        string memory newNotRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newNonRedeemable.json"));
        
        vm.expectRevert();
        vm.prank(user1);
        nft.updateMetadata(TOKEN_ID, newRedeemableURI, newNotRedeemableURI);
    }
    
    function test_RevertUpdateMetadataForNonexistentToken() public {
        // mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        string memory newRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newRedeemable.json"));
        string memory newNotRedeemableURI = string(abi.encodePacked("token-", TOKEN_ID.toString(), "-newNonRedeemable.json"));
        
        vm.expectRevert(abi.encodeWithSelector(Error.Token_DoesNotExist.selector, TOKEN_ID));
        vm.prank(owner);
        nft.updateMetadata(TOKEN_ID, newRedeemableURI, newNotRedeemableURI);
    }
    
    function test_PinTokenURIByOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        uint8 index = 1;
        
        vm.expectEmit(true, false, false, true);
        emit MetadataUpdate(TOKEN_ID);
        emit TokenUriPinned(TOKEN_ID, index);
        vm.prank(owner);
        nft.pinTokenURI(TOKEN_ID, index);
    }
    
    function test_RevertPinTokenURIByNonOwner() public {
        mintNFT(user1, TOKEN_ID, TOKEN_PRICE);
        uint8 index = 1;
        
        vm.prank(user1);
        vm.expectRevert();
        nft.pinTokenURI(TOKEN_ID, index);
        
    }
}
