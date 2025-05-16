# CryptoartNFT
[Git Source](https://github.com/cryptoartcom/cryptoart-smart-contracts/blob/f2a750c4b24c985c039cfd827f6eb92a8a383dad/src/CryptoartNFT.sol)

**Inherits:**
[IERC7160](/src/interfaces/IERC7160.sol/interface.IERC7160.md), IERC4906, ERC721BurnableUpgradeable, ERC721RoyaltyUpgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable, OwnableUpgradeable, NoncesUpgradeable, [IStory](/src/interfaces/IStory.sol/interface.IStory.md), ReentrancyGuardTransientUpgradeable

**Author:**
Cryptoart Team

Manages the Cryptoart NFT collection, supporting voucher-based minting,
pairing with physical items (via IERC7160), story inscriptions (IStory),
burning, trading, and ERC2981 royalties. Uses OpenZeppelin upgradeable contracts.


## State Variables
### MAX_BATCH_SIZE

```solidity
uint256 private constant MAX_BATCH_SIZE = 50;
```


### DEFAULT_ROYALTY_PERCENTAGE
Default royalty percentage basis points (2.5%).


```solidity
uint96 public constant DEFAULT_ROYALTY_PERCENTAGE = 250;
```


### MAX_ROYALTY_PERCENTAGE

```solidity
uint256 private constant MAX_ROYALTY_PERCENTAGE = 1000;
```


### URIS_PER_TOKEN

```solidity
uint8 private constant URIS_PER_TOKEN = 2;
```


### URI_REDEEMABLE_INDEX

```solidity
uint8 private constant URI_REDEEMABLE_INDEX = 0;
```


### URI_NOT_REDEEMABLE_INDEX

```solidity
uint8 private constant URI_NOT_REDEEMABLE_INDEX = 1;
```


### authoritySigner
Address authorized to sign minting and unpairing vouchers.


```solidity
address public authoritySigner;
```


### nftReceiver
Address receiving NFTs during mint-by-trade operations.


```solidity
address public nftReceiver;
```


### maxSupply
Maximum number of NFTs that can be minted.


```solidity
uint256 public maxSupply;
```


### baseURI
Base URI prepended to token URIs.


```solidity
string public baseURI;
```


### _tokenURIs

```solidity
mapping(uint256 tokenId => string[URIS_PER_TOKEN] tokenURIs) private _tokenURIs;
```


### _pinnedURIIndex

```solidity
mapping(uint256 tokenId => uint256 pinnedURIIndex) private _pinnedURIIndex;
```


### _hasPinnedTokenURI

```solidity
mapping(uint256 tokenId => bool hasPinnedTokenURI) private _hasPinnedTokenURI;
```


## Functions
### constructor

Locks the contract, preventing any future re-initialization.

*See OpenZeppelin Initializable documentation.*

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the upgradeable contract.

*Sets initial owner, signer, receiver, supply, base URI, and default royalties. Can only be called once.*


```solidity
function initialize(
    address contractOwner,
    address contractAuthoritySigner,
    address _nftReceiver,
    uint256 _maxSupply,
    string calldata baseURI_
) external initializer;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`contractOwner`|`address`|The initial owner of the contract.|
|`contractAuthoritySigner`|`address`|The initial address authorized to sign vouchers.|
|`_nftReceiver`|`address`|The initial address to receive traded NFTs.|
|`_maxSupply`|`uint256`|The maximum number of NFTs allowed.|
|`baseURI_`|`string`|The initial base URI for token metadata.|


### onlyTokenOwner


```solidity
modifier onlyTokenOwner(uint256 tokenId);
```

### onlyIfTokenExists


```solidity
modifier onlyIfTokenExists(uint256 tokenId);
```

### validBatchSize


```solidity
modifier validBatchSize(uint256[] calldata tokenIds);
```

### nonZeroAddress


```solidity
modifier nonZeroAddress(address _address);
```

### mint

Mints a new token using a signed voucher and payment.

*Requires a valid signature from the authority signer and sufficient payment.*


```solidity
function mint(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
    external
    payable
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`MintValidationData`|Mint validation data including recipient, tokenId, price, type, and signature.|
|`tokenUriSet`|`TokenURISet`|Initial URIs (redeemable/non-redeemable) for the token.|


### claim

Claims a new token using a signed voucher and payment.

*Functionally similar to mint, distinguished by event emission.*


```solidity
function claim(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
    external
    payable
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`data`|`MintValidationData`|Mint validation data including recipient, tokenId, price, type, and signature.|
|`tokenUriSet`|`TokenURISet`|Initial URIs (redeemable/non-redeemable) for the token.|


### mintWithTrade

Mints a new token by trading in existing tokens, using a signed voucher and payment.

*Transfers specified `tradedTokenIds` from sender to `nftReceiver`.*


```solidity
function mintWithTrade(
    uint256[] calldata tradedTokenIds,
    MintValidationData calldata data,
    TokenURISet calldata tokenUriSet
) external payable nonReentrant whenNotPaused validBatchSize(tradedTokenIds);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tradedTokenIds`|`uint256[]`|Array of token IDs owned by the sender to be traded.|
|`data`|`MintValidationData`|Mint validation data including recipient, tokenId, price, type, and signature.|
|`tokenUriSet`|`TokenURISet`|Initial URIs (redeemable/non-redeemable) for the new token.|


### _batchTransferToNftReceiver


```solidity
function _batchTransferToNftReceiver(uint256[] calldata tradedTokenIds) private;
```

### _transferToNftReceiver


```solidity
function _transferToNftReceiver(uint256 tokenId, address _nftReceiver) private;
```

### burnAndMint

Mints a new token by burning existing tokens, using a signed voucher and payment.

*Burns the specified `tokenIds` owned by the sender.*


```solidity
function burnAndMint(uint256[] calldata tokenIds, MintValidationData calldata data, TokenURISet calldata tokenUriSet)
    external
    payable
    nonReentrant
    whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenIds`|`uint256[]`|Array of token IDs owned by the sender to be burned.|
|`data`|`MintValidationData`|Mint validation data including recipient, tokenId, price, type, and signature.|
|`tokenUriSet`|`TokenURISet`|Initial URIs (redeemable/non-redeemable) for the new token.|


### batchBurn

Burns multiple tokens owned by the sender.

*Reverts if the array is empty, exceeds max batch size, or contains duplicates.*


```solidity
function batchBurn(uint256[] calldata tokenIds) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenIds`|`uint256[]`|Array of token IDs to burn.|


### _batchBurn


```solidity
function _batchBurn(uint256[] calldata tokenIds) private validBatchSize(tokenIds);
```

### burn

Burns a single token.

*Overrides ERC721Burnable.burn. Requires caller to be owner or approved. Resets token royalty.*


```solidity
function burn(uint256 tokenId) public override whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID to burn.|


### tokenURIs


```solidity
function tokenURIs(uint256 tokenId)
    external
    view
    override
    onlyIfTokenExists(tokenId)
    returns (uint256 index, string[URIS_PER_TOKEN] memory uris, bool isPinned);
```

### updateMetadata

Updates both URIs for a given token. Owner only.

*Allows administrative correction or update of metadata URIs. Emits MetadataUpdate.*


```solidity
function updateMetadata(uint256 tokenId, string calldata newRedeemableURI, string calldata newNotRedeemableURI)
    external
    whenNotPaused
    onlyOwner
    onlyIfTokenExists(tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID to update.|
|`newRedeemableURI`|`string`|The new URI for the redeemable state.|
|`newNotRedeemableURI`|`string`|The new URI for the non-redeemable state.|


### pinTokenURI


```solidity
function pinTokenURI(uint256 tokenId, uint256 index) external whenNotPaused onlyIfTokenExists(tokenId) onlyOwner;
```

### markAsRedeemable

Marks a token as redeemable (pins URI index 0) by the token owner. Requires signature.

*Requires a valid signature from the authority signer*


```solidity
function markAsRedeemable(uint256 tokenId, bytes calldata signature, uint256 deadline)
    external
    onlyTokenOwner(tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID to mark as redeemable.|
|`signature`|`bytes`|A signature from the authority signer authorizing the unpairing.|
|`deadline`|`uint256`||


### hasPinnedTokenURI


```solidity
function hasPinnedTokenURI(uint256 tokenId) external view onlyIfTokenExists(tokenId) returns (bool);
```

### unpinTokenURI


```solidity
function unpinTokenURI(uint256) external pure;
```

### triggerMetadataUpdate


```solidity
function triggerMetadataUpdate(uint256 _tokenId) external onlyOwner;
```

### addCollectionStory

Function to let the creator add a story to the collection they have created

*Depending on the implementation, this function may be restricted in various ways, such as
limiting the number of times the creator may write a story.*


```solidity
function addCollectionStory(string calldata creatorName, string calldata story) external whenNotPaused onlyOwner;
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


```solidity
function addCreatorStory(uint256 tokenId, string calldata creatorName, string calldata story)
    external
    whenNotPaused
    onlyOwner;
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


```solidity
function addStory(uint256 tokenId, string calldata collectorName, string calldata story)
    external
    whenNotPaused
    onlyTokenOwner(tokenId);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token id to which the story is attached|
|`collectorName`|`string`|String representation of the collectors's name|
|`story`|`string`|The story written and attached to the token id|


### toggleStoryVisibility

Emits an event signaling a change in visibility for a story. Token owner or admin only.

*Off-chain listeners interpret this event to control story display.*


```solidity
function toggleStoryVisibility(uint256 tokenId, string calldata storyId, bool visible) external whenNotPaused;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID the story belongs to.|
|`storyId`|`string`|An identifier for the specific story (derived off-chain from event logs).|
|`visible`|`bool`|The desired visibility state.|


### incrementNonce

Allows a user to increment their nonce, invalidating any previous off-chain signatures


```solidity
function incrementNonce() external;
```

### pause

Pauses the contract, halting mint, burn, and transfer operations. Owner only.

*Uses OpenZeppelin Pausable module.*


```solidity
function pause() external onlyOwner;
```

### unpause

Unpauses the contract, resuming normal operations. Owner only.

*Uses OpenZeppelin Pausable module.*


```solidity
function unpause() external onlyOwner;
```

### updateRoyalties

Updates the default royalty receiver and percentage. Owner only.

*Royalty percentage must not exceed MAX_ROYALTY_PERCENTAGE (10%).*


```solidity
function updateRoyalties(address payable newReceiver, uint96 newPercentage) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newReceiver`|`address payable`|The new address to receive default royalties.|
|`newPercentage`|`uint96`|The new default royalty percentage in basis points.|


### setTokenRoyalty

Sets a specific royalty for an individual token. Owner only.

*Overrides the default royalty for the specified tokenId.*


```solidity
function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`tokenId`|`uint256`|The token ID to set royalty for.|
|`receiver`|`address`|The address to receive royalties for this token.|
|`feeNumerator`|`uint96`|The royalty amount in basis points for this token.|


### setBaseURI

Updates the base URI for token metadata. Owner only.


```solidity
function setBaseURI(string calldata newBaseURI) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newBaseURI`|`string`|The new base URI string.|


### updateAuthoritySigner

Updates the address authorized to sign vouchers. Owner only.

*Cannot be set to the zero address.*


```solidity
function updateAuthoritySigner(address newAuthoritySigner) external onlyOwner nonZeroAddress(newAuthoritySigner);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newAuthoritySigner`|`address`|The new address for the authority signer.|


### updateNftReceiver

Updates the address that receives traded-in NFTs. Owner only.

*Cannot be set to the zero address.*


```solidity
function updateNftReceiver(address newNftReceiver) external onlyOwner nonZeroAddress(newNftReceiver);
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newNftReceiver`|`address`|The new address for the NFT receiver.|


### withdraw

Withdraws the entire ETH balance of the contract to the owner. Owner only.

*Reverts if the balance is zero or if the transfer fails.*


```solidity
function withdraw() external onlyOwner;
```

### setMaxSupply

Sets the maximum supply of NFTs. Owner only.


```solidity
function setMaxSupply(uint128 newMaxSupply) external onlyOwner;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`newMaxSupply`|`uint128`|The new maximum supply value.|


### _coreMint


```solidity
function _coreMint(MintValidationData calldata data, TokenURISet calldata tokenUriSet) private;
```

### _validateMintAuthorization


```solidity
function _validateMintAuthorization(MintValidationData calldata data, TokenURISet calldata uriParams) private;
```

### _validatePayment


```solidity
function _validatePayment(uint256 tokenPrice) private view;
```

### _validateTokenRequirements


```solidity
function _validateTokenRequirements(uint256 tokenId) private view;
```

### _validateSignature


```solidity
function _validateSignature(MintValidationData calldata data, TokenURISet calldata uriParams) private;
```

### _isValidSignature


```solidity
function _isValidSignature(bytes32 contentHash, bytes calldata signature) private view returns (bool);
```

### _setTokenURIs

Sets base URIs for the token


```solidity
function _setTokenURIs(
    uint256 tokenId,
    string calldata uriWhenRedeemable,
    string calldata uriWhenNotRedeemable,
    uint256 initialURIIndex
) private;
```

### _refundExcessPayment


```solidity
function _refundExcessPayment(uint256 tokenPrice) private;
```

### _tokenExists


```solidity
function _tokenExists(uint256 _tokenId) private view returns (bool);
```

### _validateUnpairAuthorization


```solidity
function _validateUnpairAuthorization(address minter, uint256 tokenId, bytes calldata signature, uint256 deadline)
    private;
```

### _getTokenURIIndex


```solidity
function _getTokenURIIndex(uint256 tokenId) private view returns (uint256);
```

### supportsInterface

*See [IERC165-supportsInterface](/src/mock/CryptoartNFTMockUpgrade.sol/contract.CryptoartNFTMockUpgrade.md#supportsinterface).*


```solidity
function supportsInterface(bytes4 interfaceId)
    public
    view
    override(IERC165, ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721RoyaltyUpgradeable)
    returns (bool);
```

### tokenURI


```solidity
function tokenURI(uint256 tokenId)
    public
    view
    override(ERC721Upgradeable)
    onlyIfTokenExists(tokenId)
    returns (string memory fullURI);
```

### _baseURI


```solidity
function _baseURI() internal view override returns (string memory);
```

### _update


```solidity
function _update(address to, uint256 tokenId, address auth)
    internal
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable)
    returns (address);
```

### _increaseBalance


```solidity
function _increaseBalance(address account, uint128 amount)
    internal
    override(ERC721Upgradeable, ERC721EnumerableUpgradeable);
```

## Events
### Initialized
Emitted when the contract is initialized.


```solidity
event Initialized(address indexed contractOwner, address indexed contractAuthoritySigner);
```

### BaseURISet
Emitted when the base URI is updated.


```solidity
event BaseURISet(string newBaseURI);
```

### MaxSupplySet
Emitted when the maximum supply is updated.


```solidity
event MaxSupplySet(uint256 indexed newMaxSupply);
```

### RoyaltiesUpdated
Emitted when default royalties are updated.


```solidity
event RoyaltiesUpdated(address indexed receiver, uint256 indexed newPercentage);
```

### AuthoritySignerUpdated
Emitted when the authority signer address is updated.


```solidity
event AuthoritySignerUpdated(address indexed newAuthoritySigner);
```

### NftReceiverUpdated
Emitted when the NFT receiver address is updated.


```solidity
event NftReceiverUpdated(address indexed newNftReceiver);
```

### ToggleStoryVisibility
Emitted when a story's visibility is toggled.


```solidity
event ToggleStoryVisibility(uint256 indexed tokenId, string indexed storyId, bool visible);
```

### Minted
Emitted on a standard mint.


```solidity
event Minted(address indexed recipient, uint256 indexed tokenId);
```

### MintedByBurning
Emitted when a token is minted by burning other tokens.


```solidity
event MintedByBurning(uint256 tokenId, uint256[] burnedTokenIds);
```

### Claimed
Emitted on a claim operation.


```solidity
event Claimed(uint256 indexed tokenId);
```

### Burned
Emitted when a token is burned.


```solidity
event Burned(uint256 indexed tokenId);
```

### MintedByTrading
Emitted when a token is minted by trading in other tokens.


```solidity
event MintedByTrading(uint256 newTokenId, uint256[] tradedTokenIds);
```

### NonceIncremented
Emitted when a user increments their nonce for the purpose of invalidating a signature


```solidity
event NonceIncremented(address user, uint256 nextAvailableNonce);
```

## Structs
### MintValidationData
Data required for validating mint operations via signature.


```solidity
struct MintValidationData {
    address recipient;
    uint256 tokenId;
    uint256 tokenPrice;
    MintType mintType;
    uint256 requiredBurnOrTradeCount;
    uint256 deadline;
    bytes signature;
}
```

### TokenURISet
URI set provided during minting, containing redeemable/non-redeemable URIs.


```solidity
struct TokenURISet {
    string uriWhenRedeemable;
    string uriWhenNotRedeemable;
    uint8 initialURIIndex;
}
```

## Enums
### MintType
Type of mint operation being performed.


```solidity
enum MintType {
    OpenMint,
    Claim,
    Trade,
    Burn
}
```

