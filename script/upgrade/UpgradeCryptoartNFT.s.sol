// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {Upgrades, Options} from "openzeppelin-foundry-upgrades/Upgrades.sol";

contract UpgradeCryptoartNFT is Script {
    address existingTransparentProxy = vm.envAddress("EXISTING_PROXY_ADDRESS");
    uint256 proxyAdminPrivateKey = vm.envUint("PROXY_ADMIN_PRIVATE_KEY");
 
    /**
     * @notice Upgrades a proxy contract to a pre-deployed implementation address.
     * @param currentImplementationName The name of the CURRENT implementation. Used for validation baseline.
     * @param newImplementationName The name of the NEW implementation. 
     * @param newImplementationAddress the address where the new implementation contract has already been deployed.
     * @param initializerCalldata Optional bytes data to call a function (like initializeV2) in the new 
        implementation during the upgrade transaction. Use abi.encodeWithSelector(...) or "" for none.
     */   
    function run(
        string memory currentImplementationName,
        string memory newImplementationName,
        address newImplementationAddress,
        bytes memory initializerCalldata
    ) public {
        if (newImplementationAddress == address(0)) {
            revert("New implementation address cannot be zero");
        }
        
        console.log("--- Starting Proxy Upgrade ---");
        console.log("Proxy to upgrade:", existingTransparentProxy);
        console.log("Current Implementation Name:", currentImplementationName);
        console.log("New Implementation Name:", newImplementationName);
        console.log("New Implementation Address:", newImplementationAddress);
        if (initializerCalldata.length > 0) {
            console.log("Initializer Call Data:", vm.toString(initializerCalldata));
        } else {
            console.log("No Initializer Call Data provided.");
        }
        
        // Setting the options for validating the upgrade
        Options memory opts;
        opts.referenceContract = currentImplementationName;
        
        console.log("Validating storage layout...");
        Upgrades.validateUpgrade(newImplementationName, opts);
        console.log("Validation Successful.");
        
        console.log("Broadcasting upgrade transaction...");
        vm.startBroadcast(proxyAdminPrivateKey);
        Upgrades.upgradeProxy(
            existingTransparentProxy, 
            newImplementationName,
            initializerCalldata
        );
        vm.stopBroadcast();

        console.log("--- Upgrade Complete ---");
        console.log("Proxy", existingTransparentProxy, "now points to implementation:", newImplementationAddress);
    }
}
