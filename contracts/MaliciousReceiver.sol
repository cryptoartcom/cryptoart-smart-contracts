// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "./CryptoartNFT.sol";

contract MaliciousReceiver is IERC721Receiver {
    CryptoartNFT public nftContract;
    bytes public mintSignature;
    string public mintType;
    uint256 public tokenPrice;
    string public redeemableTrueURI;
    string public redeemableFalseURI;
    uint256 public redeemableDefaultIndex;
    uint256 public attackTokenId;

    constructor(address _nftContract) {
        nftContract = CryptoartNFT(_nftContract);
    }

    function setMintParams(
        uint256 _tokenId,
        string memory _mintType,
        uint256 _tokenPrice,
        string memory _redeemableTrueURI,
        string memory _redeemableFalseURI,
        uint256 _redeemableDefaultIndex,
        bytes memory _signature
    ) external {
        attackTokenId = _tokenId;
        mintType = _mintType;
        tokenPrice = _tokenPrice;
        redeemableTrueURI = _redeemableTrueURI;
        redeemableFalseURI = _redeemableFalseURI;
        redeemableDefaultIndex = _redeemableDefaultIndex;
        mintSignature = _signature;
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes memory
    ) public override returns (bytes4) {
        // Attempt reentrancy attack during token transfer
        if (address(nftContract).balance >= tokenPrice) {
            try
                nftContract.mint{value: tokenPrice}(
                    attackTokenId,
                    mintType,
                    tokenPrice,
                    redeemableTrueURI,
                    redeemableFalseURI,
                    redeemableDefaultIndex,
                    mintSignature
                )
            {} catch {}
        }
        return this.onERC721Received.selector;
    }

    receive() external payable {}
}
