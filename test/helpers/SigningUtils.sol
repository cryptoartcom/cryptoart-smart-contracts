// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, Vm} from "forge-std/src/Test.sol";
import {CryptoartNFT} from "../../src/CryptoartNFT.sol";
import {ECDSA} from "@openzeppelin-contracts-5.0.2/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin-contracts-5.0.2/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin-contracts-5.0.2/utils/Strings.sol";

/**
 * @title SigningUtils
 * @dev Utility contract for signature creation and validation in tests
 * Note: Changed from library to contract to access vm
 */
contract SigningUtils is Test {
    using Strings for uint256;

    function createMintSignature(
        address user,
        uint256 tokenId,
        CryptoartNFT.MintType mintType,
        uint256 signerPrivateKey,
        CryptoartNFT.TokenURISet memory tokenURISet,
        uint256 tokenPrice,
        uint256 nonce,
        address contractAddress
    ) public pure returns (bytes memory) {
        bytes32 contentHash = keccak256(
            abi.encode(
                user,
                tokenId,
                mintType,
                tokenPrice,
                tokenURISet.uriWhenRedeemable,
                tokenURISet.uriWhenNotRedeemable,
                tokenURISet.redeemableDefaultIndex,
                nonce,
                contractAddress
            )
        );
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(contentHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(signerPrivateKey, ethSignedMessageHash);

        return abi.encodePacked(r, s, v);
    }

    function createTokenURISet(uint256 tokenId) public pure returns (CryptoartNFT.TokenURISet memory) {
        return CryptoartNFT.TokenURISet({
            uriWhenRedeemable: string(abi.encodePacked("token-", tokenId.toString(), "-redeemable.json")),
            uriWhenNotRedeemable: string(abi.encodePacked("token-", tokenId.toString(), "-not-redeemable.json")),
            redeemableDefaultIndex: 0
        });
    }
}
