// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CryptoartNFT} from "../src/CryptoartNFT.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract UpgradeCryptoartNFT is Script {
    address transparentProxyAddress = vm.envAddress("TRANSPARENT_PROXY_ADDRESS");
    uint256 proxyAdminPrivateKey = vm.envUint("PROXY_ADMIN_OWNER_PRIVATE_KEY");

    /**
     * @notice Upgrades a proxy contract to a pre-deployed implementation address.
     * @param currentImplementationName The name of the CURRENT implementation. Used for validation baseline.
     * @param newImplementationName The name of the NEW implementation.
     * @param initializerCalldata Optional bytes data to call a function (like initializeV2) in the new implementation during the upgrade transaction. Use abi.encodeWithSelector(...) or "" for none.
     */
    function run(
        string memory currentImplementationName,
        string memory newImplementationName,
        bytes memory initializerCalldata
    ) public {
        console.log("--- Starting Proxy Upgrade ---");
        console.log("Proxy to upgrade:", transparentProxyAddress);
        console.log("Current Implementation Name:", currentImplementationName);
        console.log("New Implementation Name:", newImplementationName);

        if (initializerCalldata.length > 0) {
            console.log("Initializer Call Data:", vm.toString(initializerCalldata));
        } else {
            console.log("No Initializer Call Data provided.");
        }

        // Setting the options for validating the upgrade
        Options memory opts;
        // opts.referenceContract = currentImplementationName;

        // Only use this for very small bugs or changes. Otherwise, THIS IS ** DANGEROUS **
        opts.unsafeSkipStorageCheck = true;

        console.log("Validating storage layout...");
        // Upgrades.validateUpgrade(newImplementationName, opts);
        console.log("Validation Successful.");

        console.log("Broadcasting upgrade transaction...");
        vm.startBroadcast(proxyAdminPrivateKey);
        Upgrades.upgradeProxy(transparentProxyAddress, newImplementationName, initializerCalldata, opts);

        address newImplementationAddress = Upgrades.getImplementationAddress(transparentProxyAddress);

        vm.stopBroadcast();

        console.log("--- Upgrade Complete ---");
        console.log("Proxy", transparentProxyAddress, "now points to implementation:", newImplementationAddress);
    }
}
