// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

library Error {
    error TokenAlreadyMinted();
    error TokenAlreadyClaimed();
    error TokenIdArrayCannotBeEmpty();
    error NotEnoughTokensToBurn();
    error CallerIsNotTokenOwner();
    error MaxBatchSizeExceeded();
    error DuplicateTokenIds();
    error ERC721UriQueryForNonexistentToken();
    error IndexOutOfBounds();
    error TokenDoesNotExist();
    error ERC721NoTokenUriFound();
    error TokenUriAlreadySet();
    error NotEnoughEthToMintNFT();
    error FailedToRefundExcessPayment();
    error UnauthorizedSigner();
    error ExceedsTotalSupply();
}
