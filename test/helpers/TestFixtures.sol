// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/src/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {ERC1967Proxy} from "@openzeppelin-contracts-5.0.2/proxy/ERC1967/ERC1967Proxy.sol";

contract TestFixtures {
    function deployProxyWithNFTInitialized(
        address _owner,
        address _authoritySigner,
        address _nftReceiver,
        uint256 _maxSupply,
        string memory _baseURI
    ) public returns (CryptoartNFT) {
        // Deploy implementation
        CryptoartNFT implementation = new CryptoartNFT();

        // Initialize data
        bytes memory initData = abi.encodeWithSelector(
            CryptoartNFT.initialize.selector, _owner, _authoritySigner, _nftReceiver, _maxSupply, _baseURI
        );

        // Create proxy pointing to implementation and initData
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        // Return proxy as implementation type
        return CryptoartNFT(address(proxy));
    }
}
