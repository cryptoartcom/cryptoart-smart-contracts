// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {ECDSA} from "@openzeppelin-contracts-5.0.2/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.0.2/utils/cryptography/MessageHashUtils.sol";

contract CryptoartNFTTest is Test {
    CryptoartNFT nft;

    // Test accounts
    address public owner = makeAddr("owner");
    address public authoritySigner = makeAddr("authoritySigner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Test key for authoritySigner (for creating signatures)
    uint256 public authoritySignerPrivateKey = 0xA11CE;

    // Test parameters
    string public constant BASE_URI = "ipfs://";
    uint128 public constant MAX_SUPPLY = 10000;

    function setUp() public {
        // Fund our test accounts
        vm.deal(owner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);

        nft = new CryptoartNFT();

        // Set authority signer address to match private key for testing
        authoritySigner = vm.addr(authoritySignerPrivateKey);

        // Initialize the contract properly
        nft.initialize(owner, authoritySigner, MAX_SUPPLY);

        // Set the base URI
        vm.prank(owner);
        nft.setBaseURI(BASE_URI);
    }

    // ==========================================================================
    // Test Initialization
    // ==========================================================================
    
    function test_OwnerAndAuthoritySignerIsSet() public view {
        assertEq(nft.owner(), owner);
        assertEq(nft.authoritySigner(), authoritySigner);
    }

    function test_BaseUriIsSet() public view {
        assertEq(nft.baseURI(), BASE_URI);
    }

    function test_DefaultRoyaltyIsSet() public view {
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 10000);
        assertEq(receiver, owner);
        assertEq(royaltyAmount, 250); // 2.5% of 10000
    }
    
    function test_MaxSupplyIsSet() public view {
        assertEq(nft.maxSupply(), MAX_SUPPLY);
    }
    
    // ==========================================================================
    // Test Admin Controls
    // ==========================================================================
    
    function test_PauseAndUnpause() public {
        vm.startPrank(owner);
        nft.pause();
        assertTrue(nft.paused());
        nft.unpause();
        assertFalse(nft.paused());
        vm.stopPrank();
    }
    
    function test_UpdateRoyalties() public {
        address newReceiver = makeAddr("newReceiver");
        uint96 newPercentage = 500; // 5%
        
        vm.prank(owner);
        nft.updateRoyalties(payable(newReceiver), newPercentage);
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 10_000);

        assertEq(receiver, newReceiver);
        assertEq(royaltyAmount, 500); // 5% of 10,000
    }
    
    function test_UpdateAuthoritySigner() public {
        address newAuthoritySigner = makeAddr("newAuthoritySigner");
        vm.prank(owner);
        nft.updateAuthoritySigner(newAuthoritySigner);
        
        assertEq(newAuthoritySigner, nft.authoritySigner());
    } 
    
    function test_UpdateNftReceiver() public {
        address newNftReceiver = makeAddr("newNftReceeiver");
        vm.prank(owner);
        nft.updateNftReceiver(newNftReceiver);
        
        assertEq(newNftReceiver, nft.nftReceiver());
    }
    
    function test_SetMaxSupply() public {
        uint128 newMaxSupply = 100_000;
        vm.prank(owner);
        nft.setMaxSupply(newMaxSupply);
        
        assertEq(newMaxSupply, nft.maxSupply());
    }
}
