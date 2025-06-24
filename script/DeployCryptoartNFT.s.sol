// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CryptoartNFT} from "../src/CryptoartNFT.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract DeployCryptoartNFT is Script {
    function run() external {
        address INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN = vm.envAddress("PROXY_ADMIN_OWNER");
        address owner = vm.envAddress("OWNER_ADDRESS");
        address authoritySigner = vm.envAddress("AUTHORITY_SIGNER");
        address nftReceiver = vm.envAddress("NFT_RECEIVER");
        uint256 maxSupply = vm.envUint("MAX_SUPPLY");
        string memory baseURI = vm.envString("BASE_URI");

        console.log("--- Starting Proxy Deployment ---");
        vm.startBroadcast();

        address proxy = Upgrades.deployTransparentProxy(
            "CryptoartNFT.sol",
            INITIAL_OWNER_ADDRESS_FOR_PROXY_ADMIN,
            abi.encodeCall(CryptoartNFT.initialize, (owner, authoritySigner, nftReceiver, maxSupply, baseURI))
        );

        // Get implementation address of the proxy
        address implAddr = Upgrades.getImplementationAddress(proxy);

        vm.stopBroadcast();

        console.log("Proxy deployed at:", address(proxy));
        console.log("Implementation deployed at:", address(implAddr));
    }
}
