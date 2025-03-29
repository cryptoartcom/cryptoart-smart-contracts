// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {console} from "forge-std/src/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";

contract UpdateNftReceiver is Script {
    address public proxyAddress = vm.envOr("PROXY_ADDRESS", address(0));
    address public newNftReceiver = vm.envOr("NEW_NFT_RECEIVER", address(0));

    function run() public {
        require(proxyAddress != address(0), "Proxy address not set");
        require(newNftReceiver != address(0), "New NFT receiver not set");

        CryptoartNFT nft = CryptoartNFT(proxyAddress);

        console.log("Current NFT receiver:", nft.nftReceiver());
        console.log("Updating NFT receiver to:", newNftReceiver);

        vm.startBroadcast();

        nft.updateNftReceiver(newNftReceiver);

        vm.stopBroadcast();

        console.log("NFT receiver successfully updated");
    }
}
