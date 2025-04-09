// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";

/**
 * @title UpdateAuthoritySigner Script
 * @notice Updates the authority signer address on the CryptoartNFT contract via its proxy.
 * @dev Reads required addresses and the owner's private key from environment variables.
 *      Ensure the following environment variables are set:
 *      - PROXY_ADDRESS: The address of the CryptoartNFT proxy contract.
 *      - NEW_AUTHORITY_SIGNER: The address to set as the new authority signer.
 *      - OWNER_PRIVATE_KEY: The private key of the current owner of the CryptoartNFT contract.
 */
contract UpdateAuthoritySigner is Script {
    address transparentProxyAddress = vm.envAddress("TRANSPARENT_PROXY_ADDRESS");
    address newAuthoritySigner = vm.envAddress("AUTHORITY_SIGNER");
    uint256 ownerPrivateKey = vm.envUint("OWNER_PRIVATE_KEY");

    function run() public returns (bool success) {
        require(newAuthoritySigner != address(0), "NEW_AUTHORITY_SIGNER cannot be the zero address.");
        require(ownerPrivateKey != 0, "OWNER_PRIVATE_KEY environment variable not set or invalid.");

        // Derive owner address from private key for checks and logging
        address designatedOwnerAddress = vm.addr(ownerPrivateKey);

        console.log("Executing Script As:", designatedOwnerAddress);
        console.log("Transparent Proxy Address:", transparentProxyAddress);
        console.log("New Authority Signer Address:", newAuthoritySigner);

        CryptoartNFT nft = CryptoartNFT(transparentProxyAddress);

        // Pre-flight check 1: Ensure the provided private key corresponds to the *current* contract owner
        address currentOwner = nft.owner();
        require(
            currentOwner == designatedOwnerAddress,
            "Error: Private key provided does not match the current contract owner."
        );
        console.log("Owner check passed. Current owner:", currentOwner);

        // Pre-flight check 2: Prevent setting the same address
        address currentSigner = nft.authoritySigner();
        console.log("Current authority signer:", currentSigner);
        if (currentSigner == newAuthoritySigner) {
            console.log("New authority signer is the same as the current one. No update needed.");
            return true; // Indicate success as no action was required
        }

        // --- Transaction Execution ---
        console.log("Broadcasting transaction to update authority signer...");
        vm.startBroadcast(ownerPrivateKey);

        nft.updateAuthoritySigner(newAuthoritySigner);

        vm.stopBroadcast();

        // --- Post-flight Verification ---
        address updatedSigner = nft.authoritySigner();
        require(
            updatedSigner == newAuthoritySigner,
            "Verification Failed: Authority signer address did not update correctly."
        );
        console.log("Successfully updated authority signer to:", updatedSigner);

        success = true;
        return success;
    }
}
