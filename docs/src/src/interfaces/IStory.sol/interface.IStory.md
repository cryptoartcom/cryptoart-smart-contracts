# IStory
[Git Source](https://github.com/cryptoartcom/cryptoart-smart-contracts/blob/f2a750c4b24c985c039cfd827f6eb92a8a383dad/src/interfaces/IStory.sol)

**Author:**
transientlabs.xyz

*Interface id: 0x2464f17b*

*Previous interface id that is still supported: 0x0d23ecb9*

**Note:**
version: 6.0.0


## Functions
### addCollectionStory

Function to let the creator add a story to the collection they have created

*Depending on the implementation, this function may be restricted in various ways, such as
limiting the number of times the creator may write a story.*

*This function MUST emit the CollectionStory event each time it is called*

*This function MUST implement logic to restrict access to only the creator*


```solidity
function addCollectionStory(string calldata creatorName, string calldata story) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`creatorName`|`string`|String representation of the creator's name|
|`story`|`string`|The story written and attached to the token id|


### addCreatorStory

Function to let the creator add a story to any token they have created

*Depending on the implementation, this function may be restricted in various ways, such as
limiting the number of times the creator may write a story.*

*This function MUST emit the CreatorStory event each time it is called*

*This function MUST implement logic to restrict access to only the creator*

*This function MUST revert if a story is written to a non-existent token*


```solidity
function addCreatorStory(uint256 tokenId, string calldata creatorName, string calldata story) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token id to which the story is attached|
|`creatorName`|`string`|String representation of the creator's name|
|`story`|`string`|The story written and attached to the token id|


### addStory

Function to let collectors add a story to any token they own

*Depending on the implementation, this function may be restricted in various ways, such as
limiting the number of times a collector may write a story.*

*This function MUST emit the Story event each time it is called*

*This function MUST implement logic to restrict access to only the owner of the token*

*This function MUST revert if a story is written to a non-existent token*


```solidity
function addStory(uint256 tokenId, string calldata collectorName, string calldata story) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token id to which the story is attached|
|`collectorName`|`string`|String representation of the collectors's name|
|`story`|`string`|The story written and attached to the token id|


## Events
### CollectionStory
Event describing a collection story getting added to a contract

*This event stories creator stories on chain in the event log that apply to an entire collection*


```solidity
event CollectionStory(address indexed creatorAddress, string creatorName, string story);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`creatorAddress`|`address`|The address of the creator of the collection|
|`creatorName`|`string`|String representation of the creator's name|
|`story`|`string`|The story written and attached to the collection|

### CreatorStory
Event describing a creator story getting added to a token

*This events stores creator stories on chain in the event log*


```solidity
event CreatorStory(uint256 indexed tokenId, address indexed creatorAddress, string creatorName, string story);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token id to which the story is attached|
|`creatorAddress`|`address`|The address of the creator of the token|
|`creatorName`|`string`|String representation of the creator's name|
|`story`|`string`|The story written and attached to the token id|

### Story
Event describing a collector story getting added to a token

*This events stores collector stories on chain in the event log*


```solidity
event Story(uint256 indexed tokenId, address indexed collectorAddress, string collectorName, string story);
```

**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token id to which the story is attached|
|`collectorAddress`|`address`|The address of the collector of the token|
|`collectorName`|`string`|String representation of the collectors's name|
|`story`|`string`|The story written and attached to the token id|

