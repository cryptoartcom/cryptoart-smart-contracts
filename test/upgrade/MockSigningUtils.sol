// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Test, Vm} from "forge-std/Test.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MessageHashUtils} from "@openzeppelin/contracts/utils/cryptography/MessageHashUtils.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import {CryptoartNFTMockUpgrade} from "./CryptoartNFTMockUpgrade.sol";

/**
 * @title SigningUtils
 * @dev Utility contract for signature creation and validation in tests
 * Note: Changed from library to contract to access vm
 */
contract MockSigningUtils is Test {
    using Strings for uint256;

    function createMintSignature(
        address user,
        uint256 tokenId,
        uint256 signerPrivateKey,
        CryptoartNFTMockUpgrade.TokenURISet memory tokenURISet,
        uint256 tokenPrice,
        uint256 nonce,
        address contractAddress
    ) public pure returns (bytes memory) {
        bytes32 contentHash = keccak256(
            abi.encode(
                user,
                tokenId,
                CryptoartNFTMockUpgrade.MintType.OpenMint,
                tokenPrice,
                tokenURISet.uriWhenRedeemable,
                tokenURISet.uriWhenNotRedeemable,
                tokenURISet.redeemableDefaultIndex,
                nonce,
                contractAddress
            )
        );
        return _generateSignatureFrom(contentHash, signerPrivateKey);
    }

    function _generateSignatureFrom(bytes32 contentHash, uint256 privateKey) internal pure returns (bytes memory) {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(contentHash);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(privateKey, ethSignedMessageHash);
        return abi.encodePacked(r, s, v);
    }

    function createTokenURISet(uint256 tokenId) public pure returns (CryptoartNFTMockUpgrade.TokenURISet memory) {
        return CryptoartNFTMockUpgrade.TokenURISet({
            uriWhenRedeemable: string(abi.encodePacked("token-", tokenId.toString(), "-redeemable.json")),
            uriWhenNotRedeemable: string(abi.encodePacked("token-", tokenId.toString(), "-not-redeemable.json")),
            redeemableDefaultIndex: 0
        });
    }
}
