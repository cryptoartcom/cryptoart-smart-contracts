# CryptoartNFTMockUpgrade
[Git Source](https://github.com/cryptoartcom/cryptoart-smart-contracts/blob/f2a750c4b24c985c039cfd827f6eb92a8a383dad/src/mock/CryptoartNFTMockUpgrade.sol)

**Inherits:**
Initializable, [IERC7160](/src/interfaces/IERC7160.sol/interface.IERC7160.md), IERC4906, ERC721BurnableUpgradeable, ERC721RoyaltyUpgradeable, ERC721EnumerableUpgradeable, ERC721PausableUpgradeable, OwnableUpgradeable, NoncesUpgradeable, [IStory](/src/interfaces/IStory.sol/interface.IStory.md), ReentrancyGuardTransientUpgradeable

**Author:**
Cryptoart Team

Mock contract for testing upgrades FROM CryptoartNFT. Includes sample new variables and functions.

**Note:**
oz-upgrades-from: CryptoartNFT


## State Variables
### MAX_BATCH_SIZE

```solidity
uint256 private constant MAX_BATCH_SIZE = 50;
```


### MAX_ROYALTY_PERCENTAGE

```solidity
uint256 private constant MAX_ROYALTY_PERCENTAGE = 1000;
```


### DEFAULT_ROYALTY_PERCENTAGE

```solidity
uint96 public constant DEFAULT_ROYALTY_PERCENTAGE = 500;
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
mapping(uint256 tokenId => string[URIS_PER_TOKEN]) private _tokenURIs;
```


### _pinnedURIIndex

```solidity
mapping(uint256 tokenId => uint256 pinnedURIIndex) private _pinnedURIIndex;
```


### _hasPinnedTokenURI

```solidity
mapping(uint256 tokenId => bool hasPinnedTokenURI) private _hasPinnedTokenURI;
```


### mintingPaused

```solidity
bool public mintingPaused;
```


### version

```solidity
uint256 public version;
```


## Functions
### constructor

**Note:**
oz-upgrades-unsafe-allow: constructor


```solidity
constructor();
```

### initialize

Initializes the upgradeable contract (Version 1).


```solidity
function initialize(
    address contractOwner,
    address contractAuthoritySigner,
    address _nftReceiver,
    uint256 _maxSupply,
    string calldata baseURI_
) external initializer;
```

### initializeV2

Initializes the upgradeable contract (Version 2).


```solidity
function initializeV2() external reinitializer(2);
```

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


```solidity
function mint(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
    external
    payable
    nonReentrant
    whenNotPaused;
```

### claim


```solidity
function claim(MintValidationData calldata data, TokenURISet calldata tokenUriSet)
    external
    payable
    nonReentrant
    whenNotPaused;
```

### mintWithTrade


```solidity
function mintWithTrade(
    uint256[] calldata tradedTokenIds,
    MintValidationData calldata data,
    TokenURISet calldata tokenUriSet
) external payable nonReentrant whenNotPaused validBatchSize(tradedTokenIds);
```

### _batchTransferToNftReceiver


```solidity
function _batchTransferToNftReceiver(uint256[] calldata tradedTokenIds) private;
```

### _transferToNftReceiver


```solidity
function _transferToNftReceiver(uint256 tokenId, address _nftReceiver) private;
```

### burnAndMint


```solidity
function burnAndMint(
    uint256[] calldata tokenIds,
    uint256 requiredBurnCount,
    MintValidationData calldata data,
    TokenURISet calldata tokenUriSet
) external payable nonReentrant whenNotPaused;
```

### batchBurn


```solidity
function batchBurn(uint256[] calldata tokenIds) external whenNotPaused;
```

### _batchBurn


```solidity
function _batchBurn(uint256[] calldata tokenIds) private validBatchSize(tokenIds);
```

### burn


```solidity
function burn(uint256 tokenId) public override whenNotPaused;
```

### tokenURIs


```solidity
function tokenURIs(uint256 tokenId)
    external
    view
    override
    onlyIfTokenExists(tokenId)
    returns (uint256 index, string[URIS_PER_TOKEN] memory uris, bool pinned);
```

### updateMetadata


```solidity
function updateMetadata(uint256 tokenId, string calldata newRedeemableURI, string calldata newNotRedeemableURI)
    external
    whenNotPaused
    onlyOwner
    onlyIfTokenExists(tokenId);
```

### pinTokenURI


```solidity
function pinTokenURI(uint256 tokenId, uint256 index) external whenNotPaused onlyOwner onlyIfTokenExists(tokenId);
```

### markAsRedeemable


```solidity
function markAsRedeemable(uint256 tokenId, bytes calldata signature, uint256 deadline)
    external
    whenNotPaused
    onlyTokenOwner(tokenId);
```

### hasPinnedTokenURI


```solidity
function hasPinnedTokenURI(uint256 tokenId) external view onlyIfTokenExists(tokenId) returns (bool pinned);
```

### unpinTokenURI


```solidity
function unpinTokenURI(uint256) external pure;
```

### addCollectionStory


```solidity
function addCollectionStory(string calldata creatorName, string calldata story) external whenNotPaused onlyOwner;
```

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


```solidity
function addStory(uint256 tokenId, string calldata collectorName, string calldata story)
    external
    whenNotPaused
    onlyTokenOwner(tokenId);
```

### toggleStoryVisibility


```solidity
function toggleStoryVisibility(uint256 tokenId, string calldata storyId, bool visible) external whenNotPaused;
```

### incrementNonce

Allows a user to increment their nonce, invalidating previous signatures. Added per audit L-3


```solidity
function incrementNonce() external;
```

### pause


```solidity
function pause() external onlyOwner;
```

### unpause


```solidity
function unpause() external onlyOwner;
```

### updateRoyalties


```solidity
function updateRoyalties(address payable newReceiver, uint96 newPercentage) external onlyOwner;
```

### setTokenRoyalty


```solidity
function setTokenRoyalty(uint256 tokenId, address receiver, uint96 feeNumerator) external onlyOwner;
```

### setBaseURI


```solidity
function setBaseURI(string calldata newBaseURI) external onlyOwner;
```

### updateAuthoritySigner


```solidity
function updateAuthoritySigner(address newAuthoritySigner) external onlyOwner nonZeroAddress(newAuthoritySigner);
```

### updateNftReceiver


```solidity
function updateNftReceiver(address newNftReceiver) external onlyOwner nonZeroAddress(newNftReceiver);
```

### withdraw


```solidity
function withdraw() external onlyOwner;
```

### setMaxSupply


```solidity
function setMaxSupply(uint128 newMaxSupply) external onlyOwner;
```

### toggleMintingPause


```solidity
function toggleMintingPause() external onlyOwner;
```

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
    returns (string memory);
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
event NonceIncremented(address indexed user, uint256 nextNonce);
```

### InitializedV2

```solidity
event InitializedV2();
```

### MintingPauseToggled

```solidity
event MintingPauseToggled(bool isPaused);
```

## Errors
### Admin_MintingPaused

```solidity
error Admin_MintingPaused();
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

