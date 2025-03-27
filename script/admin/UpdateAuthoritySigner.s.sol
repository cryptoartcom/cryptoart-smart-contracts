// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {console} from "forge-std/src/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";

contract UpdateAuthoritySigner is Script {
    address public proxyAddress = vm.envOr("PROXY_ADDRESS", address(0));
    address public newAuthoritySigner = vm.envOr("NEW_AUTHORITY_SIGNER", address(0));
    
    function run() public {
        require(proxyAddress != address(0), "Proxy address not set");
        require(newAuthoritySigner != address(0), "New authority signer not set");
        
        CryptoartNFT nft = CryptoartNFT(proxyAddress);
        
        console.log("Current authority signer:", nft.authoritySigner());
        console.log("Updating authority signer to:", newAuthoritySigner);
        
        vm.startBroadcast();
        
        nft.updateAuthoritySigner(newAuthoritySigner);
        
        vm.stopBroadcast();
        
        console.log("Authority signer successfully updated");
    }
}