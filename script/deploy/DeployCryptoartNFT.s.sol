// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/src/Upgrades.sol";

contract DeployCryptoartNFT is Script {
    function run() external {
        // Load configuration from environment variables
        address owner = vm.envAddress("OWNER_ADDRESS");
        address authoritySigner = vm.envAddress("AUTHORITY_SIGNER");
        address nftReceiver = vm.envAddress("NFT_RECEIVER");
        uint256 maxSupply = vm.envUint("MAX_SUPPLY");
        string memory baseURI = vm.envString("BASE_URI");
        uint256 proxyAdminDeployer = vm.envUint("PROXY_ADMIN_PRIVATE_KEY");
        
        // vm.startBroadcast(proxyAdminDeployer);

        // // address proxyAddress = Upgrades
        
        // // Prepare initialization data
        // bytes memory initData = abi.encodeWithSelector(
        //     CryptoartNFT.initialize.selector, owner, authoritySigner, nftReceiver, maxSupply, baseURI
        // );

        // vm.stopBroadcast();

        // console.log("Proxy deployed at:", address(proxy));
        // console.log("Implementation deployed at:", address(implementation));
    }
}
