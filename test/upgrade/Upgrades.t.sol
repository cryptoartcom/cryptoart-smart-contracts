// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "openzeppelin-foundry-upgrades/Upgrades.sol";
import {console} from "forge-std/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {CryptoartNFTMockUpgrade} from "../../src/mock/CryptoartNFTMockUpgrade.sol";
import {CryptoartNFTBase} from "../CryptoartNFTBase.t.sol";
import "./MockSigningUtils.sol";

contract UpgradesTest is CryptoartNFTBase {
    function test_TransparentProxyUpgrade() public {
        // To enable code coverage reports with forge coverage, use the following deployment
        // pattern in your tests: instantiate your implementation contracts directly and use
        // the UnsafeUpgrades library.
        address implementation = address(new CryptoartNFT());
        address proxy = UnsafeUpgrades.deployTransparentProxy(
            implementation,
            proxyAdmin,
            abi.encodeCall(CryptoartNFT.initialize, (owner, authoritySigner, nftReceiver, MAX_SUPPLY, BASE_URI))
        );

        // Get the instance of the contract
        CryptoartNFT instance = CryptoartNFT(proxy);

        // Get implementation address of the proxy
        address implAddrV1 = Upgrades.getImplementationAddress(proxy);

        // Get the admin address of the proxy
        address adminAddr = Upgrades.getAdminAddress(proxy);

        // Ensure the admin address is valid
        assertFalse(adminAddr == address(0));

        // Log the initial value
        console.log("----------------------------------");
        console.log("Value before upgrade --> ", instance.DEFAULT_ROYALTY_PERCENTAGE());
        console.log("----------------------------------");

        assertEq(instance.DEFAULT_ROYALTY_PERCENTAGE(), 250);

        vm.expectEmit();
        emit CryptoartNFTMockUpgrade.InitializedV2();

        // Upgrade the proxy to the new implementation
        Upgrades.upgradeProxy(
            proxy, "CryptoartNFTMockUpgrade.sol", abi.encodeCall(CryptoartNFTMockUpgrade.initializeV2, ()), proxyAdmin
        );

        // Get the new implementation address after upgrade
        address implAddrV2 = Upgrades.getImplementationAddress(proxy);

        // Verify admin address remains unchanged
        assertEq(Upgrades.getAdminAddress(proxy), adminAddr);

        // Verify implementation address has changed
        assertFalse(implAddrV1 == implAddrV2);

        // Get the upgraded instance of the contract
        CryptoartNFTMockUpgrade upgradeInstance = CryptoartNFTMockUpgrade(proxy);

        assertEq(upgradeInstance.DEFAULT_ROYALTY_PERCENTAGE(), 500);
        assertEq(upgradeInstance.version(), 2);
        assertEq(upgradeInstance.mintingPaused(), false);

        // Log and verify updated value
        console.log("----------------------------------");
        console.log("Value after upgrade --> ", instance.DEFAULT_ROYALTY_PERCENTAGE());
        console.log("----------------------------------");

        // Test new Minting Pause logic in mint function
        MockSigningUtils mockSigningUtils = new MockSigningUtils();
        CryptoartNFTMockUpgrade.TokenURISet memory tokenURISet = mockSigningUtils.createTokenURISet(TOKEN_ID);
        uint256 deadline = block.timestamp + DEFAULT_EXPIRATION;

        bytes memory signature = mockSigningUtils.createMintSignature(
            user1,
            TOKEN_ID,
            authoritySignerPrivateKey,
            tokenURISet,
            TOKEN_PRICE,
            upgradeInstance.nonces(user1),
            deadline,
            address(upgradeInstance)
        );
        CryptoartNFTMockUpgrade.MintValidationData memory data = CryptoartNFTMockUpgrade.MintValidationData({
            recipient: user1,
            tokenId: TOKEN_ID,
            tokenPrice: TOKEN_PRICE,
            mintType: CryptoartNFTMockUpgrade.MintType.OpenMint,
            requiredBurnOrTradeCount: REQUIRED_MINT_CLAIM_COUNT,
            deadline: deadline,
            signature: signature
        });

        vm.prank(owner);
        upgradeInstance.toggleMintingPause();

        vm.expectRevert(abi.encodeWithSelector(CryptoartNFTMockUpgrade.Admin_MintingPaused.selector));
        vm.prank(user1);
        upgradeInstance.mint{value: TOKEN_PRICE}(data, tokenURISet);

        vm.prank(owner);
        upgradeInstance.toggleMintingPause();

        vm.expectEmit(true, true, false, false);
        emit CryptoartNFTMockUpgrade.Minted(user1, TOKEN_ID);

        vm.prank(user1);
        upgradeInstance.mint{value: TOKEN_PRICE}(data, tokenURISet);

        assertEq(upgradeInstance.ownerOf(TOKEN_ID), user1);
    }
}
