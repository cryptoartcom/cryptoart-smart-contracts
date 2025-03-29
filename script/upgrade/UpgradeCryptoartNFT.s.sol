// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {console} from "forge-std/src/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {ERC1967Utils} from "@openzeppelin-contracts-5.0.2/proxy/ERC1967/ERC1967Utils.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable-5.0.2/access/OwnableUpgradeable.sol";

contract UpgradeCryptoartNFT is Script {
    address public proxyAddress = vm.envOr("PROXY_ADDRESS", address(0));

    function run() public returns (address newImplementation) {
        // // Get the current implementation address for logging
        // address currentImplementation = ERC1967Utils.getImplementation(proxyAddress);
        // console.log("Current implementation:", currentImplementation);

        // vm.startBroadcast();

        // // Deploy new implementation
        // CryptoartNFT newImplementationContract = new CryptoartNFT();
        // newImplementation = address(newImplementationContract);
        // console.log("New implementation deployed at:", newImplementation);

        // // Upgrade the proxy to the new implementation
        // // Note: This must be called by the proxy admin or owner
        // ERC1967Utils.upgradeToAndCall(
        //     proxyAddress,
        //     newImplementation,
        //     bytes("")
        // );

        // console.log("Proxy successfully upgraded to new implementation");

        // vm.stopBroadcast();

        // return newImplementation;
    }
}
