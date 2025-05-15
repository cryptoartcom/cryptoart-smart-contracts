# IERC7160
[Git Source](https://github.com/cryptoartcom/cryptoart-smart-contracts/blob/f2a750c4b24c985c039cfd827f6eb92a8a383dad/src/interfaces/IERC7160.sol)

*The ERC-165 identifier for this interface is 0x06e1bc5b.*


## Functions
### tokenURIs

Get all token uris associated with a particular token

*If a token uri is pinned, the index returned SHOULD be the index in the string array*

*This call MUST revert if the token does not exist*


```solidity
function tokenURIs(uint256 tokenId) external view returns (uint256 index, string[2] memory uris, bool pinned);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The identifier for the nft|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`index`|`uint256`|An unisgned integer that specifies which uri is pinned for a token (or the default uri if unpinned)|
|`uris`|`string[2]`|A string array of all uris associated with a token|
|`pinned`|`bool`|A boolean showing if the token has pinned metadata or not|


### pinTokenURI

Pin a specific token uri for a particular token

*This call MUST revert if the token does not exist*

*This call MUST emit a `TokenUriPinned` event*

*This call MAY emit a `MetadataUpdate` event from ERC-4096*


```solidity
function pinTokenURI(uint256 tokenId, uint256 index) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The identifier of the nft|
|`index`|`uint256`|The index in the string array returned from the `tokenURIs` function that should be pinned for the token|


### unpinTokenURI

Unpin metadata for a particular token

*This call MUST revert if the token does not exist*

*This call MUST emit a `TokenUriUnpinned` event*

*This call MAY emit a `MetadataUpdate` event from ERC-4096*

*It is up to the developer to define what this function does and is intentionally left open-ended*


```solidity
function unpinTokenURI(uint256 tokenId) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The identifier of the nft|


### hasPinnedTokenURI

Check on-chain if a token id has a pinned uri or not

*This call MUST revert if the token does not exist*

*Useful for on-chain mechanics that don't require the tokenURIs themselves*


```solidity
function hasPinnedTokenURI(uint256 tokenId) external view returns (bool pinned);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The identifier of the nft|

**Returns**

|Name|Type|Description|
|----|----|-----------|
|`pinned`|`bool`|A bool specifying if a token has metadata pinned or not|


## Events
### TokenUriPinned
*This event emits when a token uri is pinned and is
useful for indexing purposes.*


```solidity
event TokenUriPinned(uint256 indexed tokenId, uint256 indexed index);
```

### TokenUriUnpinned
*This event emits when a token uri is unpinned and is
useful for indexing purposes.*


```solidity
event TokenUriUnpinned(uint256 indexed tokenId);
```

