// import {Test} from "forge-std/Test.sol";
// import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
// import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

// contract TestFixtures {
//     function deployProxyWithNFTInitialized(
//         address _owner,
//         address _authoritySigner,
//         address _nftReceiver,
//         uint256 _maxSupply,
//         string memory _baseURI
//     ) public returns (CryptoartNFT) {
//         // Deploy implementation
//         CryptoartNFT implementation = new CryptoartNFT();

//         // Initialize data
//         bytes memory initData = abi.encodeWithSelector(
//             CryptoartNFT.initialize.selector, _owner, _authoritySigner, _nftReceiver, _maxSupply, _baseURI
//         );

//         // Create proxy pointing to implementation and initData
//         ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

//         // Return proxy as implementation type
//         return CryptoartNFT(address(proxy));
//     }
// }

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {Upgrades} from "openzeppelin-foundry-upgrades/Upgrades.sol";

/**
 * @title TestFixtures
 * @notice Provides helper functions to set up contracts for testing,
 *         specifically deploying CryptoartNFT behind a Transparent Upgradeable Proxy.
 */
contract TestFixtures is Test {
    /**
     * @notice Deploys CryptoartNFT behind a correctly configured Transparent Upgradeable Proxy.
     * @param _proxyAdminOwner The address that will own the ProxyAdmin contract (controls upgrades).
     * @param _owner The initial owner for the CryptoartNFT logic contract (passed to initialize).
     * @param _authoritySigner The initial authority signer for CryptoartNFT (passed to initialize).
     * @param _nftReceiver The initial NFT receiver for CryptoartNFT (passed to initialize).
     * @param _maxSupply The maximum supply for CryptoartNFT (passed to initialize).
     * @param _baseURI The base URI for CryptoartNFT (passed to initialize).
     * @return nftProxy The CryptoartNFT contract instance interacted with via the proxy address.
     */
    function deployTransparentProxyWithNFTInitialized(
        address _proxyAdminOwner,
        address _owner,
        address _authoritySigner,
        address _nftReceiver,
        uint256 _maxSupply,
        string memory _baseURI
    ) public returns (CryptoartNFT nftProxy) {
        bytes memory initData =
            abi.encodeCall(CryptoartNFT.initialize, (_owner, _authoritySigner, _nftReceiver, _maxSupply, _baseURI));

        address proxyAddress = Upgrades.deployTransparentProxy("CryptoartNFT.sol", _proxyAdminOwner, initData);

        nftProxy = CryptoartNFT(proxyAddress);
    }
}
