// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/src/Script.sol";
import {console} from "forge-std/src/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployCryptoartNFT is Script {
    function run() external {
        // Load configuration from environment variables
        address owner = vm.envAddress("OWNER_ADDRESS");
        address authoritySigner = vm.envAddress("AUTHORITY_SIGNER");
        address nftReceiver = vm.envAddress("NFT_RECEIVER");
        uint256 maxSupply = vm.envUint("MAX_SUPPLY");
        string memory baseURI = vm.envString("BASE_URI");

        vm.startBroadcast();

        // Deploy the implementation contract
        CryptoartNFT implementation = new CryptoartNFT();

        // Prepare initialization data
        bytes memory initData = abi.encodeWithSelector(
            CryptoartNFT.initialize.selector,
            owner,
            authoritySigner,
            nftReceiver,
            maxSupply,
            baseURI
        );

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        vm.stopBroadcast();

        console.log("Proxy deployed at:", address(proxy));
        console.log("Implementation deployed at:", address(implementation));
    }
}