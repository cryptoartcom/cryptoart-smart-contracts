// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";

/**
 * @title UpdateNftReceiver Script
 * @notice Updates the NFT receiver address on the CryptoartNFT contract via its proxy.
 * @dev This address receives NFTs during 'mintWithTrade' operations.
 *      Reads required addresses and the owner's private key from environment variables.
 *      Ensure the following environment variables are set:
 *      - PROXY_ADDRESS: The address of the CryptoartNFT proxy contract.
 *      - NEW_NFT_RECEIVER: The address to set as the new NFT receiver.
 *      - OWNER_PRIVATE_KEY: The private key of the current owner of the CryptoartNFT contract.
 */
contract UpdateNftReceiver is Script {
    address proxyAddress = vm.envAddress("PROXY_ADDRESS");
    address newNftReceiver = vm.envAddress("NEW_NFT_RECEIVER");
    uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");

    function run() public returns (bool success) {
        require(newNftReceiver != address(0), "NEW_NFT_RECEIVER cannot be the zero address.");
        require(ownerPrivateKey != 0, "OWNER_PRIVATE_KEY environment variable not set or invalid.");

        // Derive owner address from private key for checks and logging
        address designatedOwnerAddress = vm.addr(ownerPrivateKey);

        console.log("Executing Script As:", designatedOwnerAddress);
        console.log("Target Proxy Address:", proxyAddress);
        console.log("New NFT Receiver Address:", newNftReceiver);

        CryptoartNFT nft = CryptoartNFT(proxyAddress);

        // Pre-flight check 1: Ensure the provided private key corresponds to the *current* contract owner
        address currentOwner = nft.owner();
        require(
            currentOwner == designatedOwnerAddress,
            "Error: Private key provided does not match the current contract owner."
        );
        console.log("Owner check passed. Current owner:", currentOwner);

        // Pre-flight check 2: Prevent setting the same address
        address currentReceiver = nft.nftReceiver();
        console.log("Current NFT receiver:", currentReceiver);
        if (currentReceiver == newNftReceiver) {
            console.log("New NFT receiver is the same as the current one. No update needed.");
            return true;
        }

        // --- Transaction Execution ---
        console.log("Broadcasting transaction to update NFT receiver...");
        vm.startBroadcast(ownerPrivateKey);

        nft.updateNftReceiver(newNftReceiver);

        vm.stopBroadcast();

        // --- Post-flight Verification ---
        address updatedReceiver = nft.nftReceiver();
        require(
            updatedReceiver == newNftReceiver, "Verification Failed: NFT receiver address did not update correctly."
        );
        console.log("Successfully updated NFT receiver to:", updatedReceiver);

        success = true;
        return success;
    }
}
