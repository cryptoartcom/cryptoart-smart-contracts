// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICryptoartNFTEvents {
    event Initialized(address contractOwner, address contractAuthoritySigner);
    event BaseURISet(string newBaseURI);
    event MaxSupplySet(uint256 newMaxSupply);
    event RoyaltiesUpdated(address indexed receiver, uint256 newPercentage);
    event AuthoritySignerUpdated(address newAuthoritySigner);
    event NftReceiverUpdated(address newNftReceiver);
    event ToggleStoryVisibility(uint256 tokenId, string storyId, bool visible);
    event Paused(address account);

    // NFT lifecycle events
    event Minted(address indexed recipient, uint256 tokenId);
    event MintedByBurning(uint256 tokenId, uint256[] burnedTokenIds);
    event Claimed(uint256 tokenId);
    event Burned(uint256 tokenId);
    event MintedByTrading(uint256 newTokenId, uint256[] tradedTokenIds);
}
