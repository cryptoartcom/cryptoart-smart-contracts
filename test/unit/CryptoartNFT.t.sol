// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, console} from "forge-std/src/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {ECDSA} from "@openzeppelin-contracts-5.0.2/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.0.2/utils/cryptography/MessageHashUtils.sol";

contract CryptoartNFTTest is Test {
    CryptoartNFT nft;
    
    // Test accounts
    address public contractOwner = makeAddr("contractOwner");
    address public authoritySigner = makeAddr("authoritySigner");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    
    // Test key for authoritySigner (for creating signatures)
    uint256 public authoritySignerPrivateKey = 0xA11CE;
    
    // Test parameters
    string public constant BASE_URI = "ipfs://";
    
    function setUp() public {
        // Fund our test accounts
        vm.deal(contractOwner, 100 ether);
        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        
        // Deploy contract
        nft = new CryptoartNFT();
        
        // Set authority signer address to match private key for testing
        authoritySigner = vm.addr(authoritySignerPrivateKey);
        
        // Initialize the contract properly
        nft.initialize(contractOwner, authoritySigner);
        
        // Set the base URI
        vm.prank(contractOwner);
        nft.setBaseURI(BASE_URI);
    }
    
    function test_OwnerAndAuthoritySignerIsSet() public {
        assertEq(nft.owner(), contractOwner);
        assertEq(nft.authoritySigner(), authoritySigner);
    }
    
    function test_BaseUriIsSet() public {
        assertEq(nft.baseURI(), BASE_URI);
    }
    
    function test_DefaultRoyaltyIsSet() public {
        (address receiver, uint256 royaltyAmount) = nft.royaltyInfo(1, 10000);
        assertEq(receiver, contractOwner);
        assertEq(royaltyAmount, 250); // 2.5% of 10000
    }
}