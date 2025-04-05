# Error
[Git Source](https://github.com/cryptoartcom/cryptoart-smart-contracts/blob/0fa1415149ef9f765c2e91a56b87fffc054d91d6/src/libraries/Error.sol)


## Errors
### Token_AlreadyMinted

```solidity
error Token_AlreadyMinted(uint256 tokenId);
```

### Token_DoesNotExist

```solidity
error Token_DoesNotExist(uint256 tokenId);
```

### Token_NotOwned

```solidity
error Token_NotOwned(uint256 tokenId, address caller);
```

### Token_URIAlreadySet

```solidity
error Token_URIAlreadySet(uint256 tokenId);
```

### Token_NoURIFound

```solidity
error Token_NoURIFound(uint256 tokenId);
```

### Token_IndexOutOfBounds

```solidity
error Token_IndexOutOfBounds(uint256 tokenId, uint256 index, uint256 maxIndex);
```

### Token_InvalidDefaultIndex

```solidity
error Token_InvalidDefaultIndex(uint256 redeemableDefaultIndex);
```

### Batch_EmptyArray

```solidity
error Batch_EmptyArray();
```

### Batch_MaxSizeExceeded

```solidity
error Batch_MaxSizeExceeded(uint256 size, uint256 maxSize);
```

### Batch_DuplicateTokenIds

```solidity
error Batch_DuplicateTokenIds(uint256 tokenId);
```

### Batch_InsufficientTokenAmount

```solidity
error Batch_InsufficientTokenAmount(uint256 expected, uint256 provided);
```

### Mint_InsufficientPayment

```solidity
error Mint_InsufficientPayment(uint256 required, uint256 provided);
```

### Mint_RefundFailed

```solidity
error Mint_RefundFailed(address recipient, uint256 amount);
```

### Mint_ExceedsTotalSupply

```solidity
error Mint_ExceedsTotalSupply(uint256 tokenId, uint256 maxSupply);
```

### Auth_UnauthorizedSigner

```solidity
error Auth_UnauthorizedSigner();
```

### Auth_Unauthorized

```solidity
error Auth_Unauthorized(address msgSender);
```

### Admin_RoyaltyTooHigh

```solidity
error Admin_RoyaltyTooHigh(uint256 percentage, uint256 maxPercentage);
```

### Admin_NoWithdrawableFunds

```solidity
error Admin_NoWithdrawableFunds();
```

### Admin_WithdrawalFailed

```solidity
error Admin_WithdrawalFailed(address recipient, uint256 amount);
```

### Admin_ZeroAddress

```solidity
error Admin_ZeroAddress();
```

