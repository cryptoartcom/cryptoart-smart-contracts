// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library Error {
    // Token errors
    error Token_AlreadyMinted(uint256 tokenId);
    error Token_DoesNotExist(uint256 tokenId);
    error Token_NotOwned(uint256 tokenId, address caller);
    error Token_URIAlreadySet(uint256 tokenId);
    error Token_NoURIFound(uint256 tokenId);
    error Token_IndexOutOfBounds(uint256 tokenId, uint256 index, uint256 maxIndex);

    // Batch operation errors
    error Batch_EmptyArray();
    error Batch_MaxSizeExceeded(uint256 size, uint256 maxSize);
    error Batch_DuplicateTokenIds();
    error Batch_InsufficientTokenAmount(uint256 expected, uint256 provided);

    // Mint errors
    error Mint_InsufficientPayment(uint256 required, uint256 provided);
    error Mint_RefundFailed(address recipient, uint256 amount);
    error Mint_ExceedsTotalSupply(uint256 tokenId, uint256 maxSupply);

    // Auth errors
    error Auth_UnauthorizedSigner();

    // Admin errors
    error Admin_RoyaltyTooHigh(uint256 percentage, uint256 maxPercentage);
    error Admin_EmptyBaseURI();
    error Admin_NoWithdrawableFunds();
    error Admin_WithdrawalFailed(address recipient, uint256 amount);
    error Admin_ZeroAddress();
}
