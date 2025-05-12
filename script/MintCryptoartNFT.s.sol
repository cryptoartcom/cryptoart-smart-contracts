// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {CryptoartNFT} from "../src/CryptoartNFT.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title MintCryptoartNFT
 * @notice Script to generate a mint signature and execute a mint transaction.
 * @dev Reads configuration from environment variables:
 *      - TRANSPARENT_PROXY_ADDRESS: Address of the CryptoartNFT proxy.
 *      - AUTHORITY_SIGNER_PRIVATE_KEY: Private key of the designated authority signer.
 *      - MINTER_PRIVATE_KEY: Private key of the user performing the mint and paying.
 */
contract MintCryptoartNFT is Script {
    using Strings for uint256;

    address proxyAddress = vm.envAddress("TRANSPARENT_PROXY_ADDRESS");
    uint256 authoritySignerPrivateKey = vm.envUint("AUTHORITY_SIGNER_PRIVATE_KEY");
    uint256 minterPrivateKey = vm.envUint("MINTER_PRIVATE_KEY");

    /**
     * @notice Executes the minting process.
     * @param recipient The address that will receive the NFT.
     * @param tokenId The ID of the token to mint.
     * @param tokenPrice The price (in wei) required for the mint.
     * @param mintTypeValue The numerical value of the MintType enum (e.g., 0 for OpenMint).
     * @param uriWhenRedeemable Optional: URI for the redeemable state. If empty, uses default.
     * @param uriWhenNotRedeemable Optional: URI for the non-redeemable state. If empty, uses default.
     * @param initialURIIndex Optional: Initial URI index (0 or 1). Defaults to 0.
     */
    function run(
        address recipient,
        uint256 tokenId,
        uint8 mintTypeValue,
        uint256 tokenPrice,
        string memory uriWhenRedeemable,
        string memory uriWhenNotRedeemable,
        uint8 initialURIIndex,
        uint256 deadline
    ) public returns (bool success) {
        require(proxyAddress != address(0), "TRANSPARENT_PROXY_ADDRESS not set");
        require(authoritySignerPrivateKey != 0, "AUTHORITY_SIGNER_PRIVATE_KEY not set");
        require(minterPrivateKey != 0, "MINTER_PRIVATE_KEY not set");
        require(recipient != address(0), "Recipient cannot be zero address");
        
        address minterAddress = vm.addr(minterPrivateKey);
        console.log("Executing Mint Script As (Minter):", minterAddress);
        console.log("Recipient:", recipient);
        console.log("Token ID:", tokenId);
        console.log("Token Price (wei):", tokenPrice);
        console.log("Target Proxy:", proxyAddress);
        console.log("Mint Type (Value):", mintTypeValue);
        console.log("Deadline:", deadline);

        // Get contract instance
        CryptoartNFT nft = CryptoartNFT(proxyAddress);
        
        // Get current nonce for the recipient
        uint256 nonce = nft.nonces(recipient);
        console.log("Nonce for recipient:", nonce);

        // --- Prepare Data Structs ---

        // TokenURI Set
        CryptoartNFT.TokenURISet memory tokenUriSet;
        tokenUriSet.uriWhenRedeemable = bytes(uriWhenRedeemable).length > 0
            ? uriWhenRedeemable
            : string(abi.encodePacked("token-", tokenId.toString(), "-redeemable.json"));
        tokenUriSet.uriWhenNotRedeemable = bytes(uriWhenNotRedeemable).length > 0
            ? uriWhenNotRedeemable
            : string(abi.encodePacked("token-", tokenId.toString(), "-not-redeemable.json"));
        tokenUriSet.initialURIIndex = initialURIIndex;

        // Mint Validation Data without the signature
        CryptoartNFT.MintValidationData memory data;
        data.recipient = recipient;
        data.tokenId = tokenId;
        data.tokenPrice = tokenPrice;
        data.mintType = CryptoartNFT.MintType(mintTypeValue); // cast uint8 to enum
        data.requiredBurnOrTradeCount = 0;
        data.deadline = deadline;
        
        // --- Generate Signature ---
        console.log("Generate Signature using Authority Signer...");

        bytes32 contentHash = keccak256(
            abi.encode(
                data.recipient,
                data.tokenId,
                data.tokenPrice,
                data.mintType,
                data.requiredBurnOrTradeCount,
                tokenUriSet.uriWhenRedeemable,
                tokenUriSet.uriWhenNotRedeemable,
                tokenUriSet.initialURIIndex,
                nonce,
                block.chainid,
                data.deadline,
                proxyAddress
            )
        );

        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(contentHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(authoritySignerPrivateKey, ethSignedMessageHash);
        data.signature = abi.encodePacked(r, s, v);
        console.log("Signature generated");

        // --- Mint Tx ---
        console.log("Broadcasting Mint Tx from Minter: ", minterAddress);
        vm.startBroadcast(minterPrivateKey);

        nft.mint{value: data.tokenPrice}(data, tokenUriSet);

        vm.stopBroadcast();

        // --- Verification ---
        address ownerOfToken = nft.ownerOf(tokenId);
        require(ownerOfToken == recipient, "Verification Failed: Recipient does not own the token after mint.");
        console.log("Mint successful! Token", tokenId, "minted to:", ownerOfToken);

        success = true;
        return success;
    }
}
