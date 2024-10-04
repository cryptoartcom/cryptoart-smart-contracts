# Smart Contract documentation

## State Variables

```ts
/// @dev The base value for calculating royalty percentages. 10000 represents 100%.
uint256 private constant ROYALTY_BASE = 10000;

/// @dev The current royalty percentage. 250 represents 2.5%.
uint256 public royaltyPercentage;

/// @dev The address that receives royalty payments.
address payable public royaltyReceiver;

/// @dev The base URI for token metadata from Pinata IPFS
string public baseURI;

/// @dev Mapping to track burned tokens. Used for maintaining upgrade compatibility.
mapping(address => uint256) public \_\_burn_gap;

/// @dev Unused variable to maintain storage layout for upgrades.
address private \_\_gap;

/// @dev The address authorized to sign minting transactions.
address public \_authoritySigner;

/// @dev Mapping from token ID to an array of token URIs (IERC7160).
mapping(uint256 => string[]) private \_tokenURIs;

/// @dev Mapping from token ID to the index of the pinned URI (IERC7160).
mapping(uint256 => uint256) private \_pinnedURIIndices;

/// @dev Mapping from token ID to a boolean indicating if the token has a pinned URI (IERC7160).
mapping(uint256 => bool) private \_hasPinnedTokenURI;

/// @dev The total number of tokens minted. Used for internal tracking.
uint256 private \_totalSupply;
```

## Events

```ts
/// @dev Emitted when royalty settings are updated.
/// @param receiver The new address to receive royalties.
/// @param newPercentage The new royalty percentage.
event RoyaltiesUpdated(address indexed receiver, uint256 newPercentage);

/// @dev Emitted when a new token is minted.
/// @param tokenId The ID of the newly minted token.
event Minted(uint256 tokenId);

/// @dev Emitted when a token is claimed.
/// @param tokenId The ID of the claimed token.
event Claimed(uint256 tokenId);

/// @dev Emitted when a new token is minted by burning other tokens.
/// @param tokenId The ID of the newly minted token.
/// @param burnedTokenIds An array of token IDs that were burned to mint the new token.
event MintedByBurning(uint256 tokenId, uint256[] burnedTokenIds);

/// @dev Emitted when a token is burned.
/// @param tokenId The ID of the burned token.
event Burned(uint256 tokenId);

/// @dev Emitted when a new token is minted by trading in other tokens.
/// @param newTokenId The ID of the newly minted token.
/// @param tradedTokenIds An array of token IDs that were traded in for the new token.
event MintedByTrading(uint256 newTokenId, uint256[] tradedTokenIds);

/// @dev Emitted when a token's metadata is updated.
/// @param \_tokenId The ID of the token whose metadata was updated.
event MetadataUpdate(uint256 \_tokenId);

/// @dev Emitted when a token's URI is pinned to a specific index.
/// @param tokenId The ID of the token.
/// @param index The index of the URI that was pinned.
event TokenUriPinned(uint256 tokenId, uint256 index);

/// @dev Emitted when a creator adds a story to a token. Not used but implemented for the standard
/// @param tokenId The ID of the token.
/// @param creator The address of the creator.
/// @param creatorName The name of the creator.
/// @param story The content of the story.
event CreatorStory(uint256 tokenId, address creator, string creatorName, string story);

/// @dev Emitted when a collector adds a story to a token.
/// @param tokenId The ID of the token.
/// @param collector The address of the collector.
/// @param collectorName The name of the collector.
/// @param story The content of the story.
event Story(uint256 tokenId, address collector, string collectorName, string story);

/// @dev Emitted when the visibility of a story attached to a token is toggled.
/// @param tokenId The ID of the token the story is attached to.
/// @param storyId The unique identifier of the story.
/// @param visible The new visibility status of the story.
event ToggleStoryVisibility(uint256 tokenId, string storyId, bool visible);
```

## Functions

```ts
/// @notice Initializes the contract
/// @param contractOwner The address that will own the contract
/// @param contractAuthoritySigner The address authorized to sign minting transactions
function initialize(
address contractOwner,
address contractAuthoritySigner
) external initializer {
// ...
}

/// @notice Checks if the contract supports a given interface
/// @param interfaceId The interface identifier, as specified in ERC-165
/// @return bool True if the contract supports the interface, false otherwise
function supportsInterface(
bytes4 interfaceId
) public view virtual override(IERC165, ERC721URIStorageUpgradeable) returns (bool) {
// ...
}

/// @notice Provides royalty information for a token
/// @param \_salePrice The sale price of the token
/// @return receiver The address that should receive the royalties
/// @return royaltyAmount The royalty amount to be paid
function royaltyInfo(
uint256,
uint256 \_salePrice
) external view override returns (address receiver, uint256 royaltyAmount) {
// ...
}

/// @notice Updates the royalty settings
/// @param newReceiver The new address to receive royalties
/// @param newPercentage The new royalty percentage
function updateRoyalties(
address payable newReceiver,
uint256 newPercentage
) external onlyOwner {
// ...
}

/// @notice Sets the base URI for computing {tokenURI}
/// @param newBaseURI The new base URI to be set from Pinata IPFS
function setBaseURI(string memory newBaseURI) external onlyOwner {
// ...
}

/// @notice Updates the metadata URI for a specific token
/// @param \_tokenId The ID of the token to update
/// @param \_newMetadataURI The new metadata URI
function updateMetadata(
uint256 \_tokenId,
string memory \_newMetadataURI
) external onlyOwner {
// ...
}

/// @notice Triggers a metadata update event for a specific token. This can help marketplaces to be synchronized
/// @param \_tokenId The ID of the token to update
function triggerMetadataUpdate(uint256 \_tokenId) public onlyOwner {
// ... existing code ...
}

/// @notice Returns the base URI for token metadata
/// @return string The base URI
function \_baseURI() internal view virtual override returns (string memory) {
// ...
}

/// @notice Mints a new token
/// @param \_tokenId The ID of the token to mint
/// @param mintType The type of minting operation (openMint or whitelist)
/// @param tokenPrice The price to mint the token
/// @param redeemableTrueURI The URI for the redeemable true state
/// @param redeemableFalseURI The URI for the redeemable false state
/// @param redeemableDefaultIndex The default index for the redeemable state
/// @param signature The signature authorizing the mint
function mint(
uint256 \_tokenId,
string memory mintType,
uint256 tokenPrice,
string memory redeemableTrueURI,
string memory redeemableFalseURI,
uint256 redeemableDefaultIndex,
bytes memory signature
) external payable {
// ...
}

/// @notice Claims a token
/// @param \_tokenId The ID of the token to claim
/// @param tokenPrice The price to claim the token
/// @param redeemableTrueURI The URI for the redeemable true state
/// @param redeemableFalseURI The URI for the redeemable false state
/// @param redeemableDefaultIndex The default index for the redeemable state
/// @param signature The signature authorizing the claim
function claimable(
uint256 \_tokenId,
uint256 tokenPrice,
string memory redeemableTrueURI,
string memory redeemableFalseURI,
uint256 redeemableDefaultIndex,
bytes memory signature
) external payable {
// ...
}

/// @notice Mints a new token by trading in existing tokens
/// @param \_mintedTokenId The ID of the new token to mint
/// @param tradedTokenIds An array of token IDs to trade in
/// @param mintType The type of minting operation (openMint or whitelist)
/// @param tokenPrice The price to mint the token
/// @param redeemableTrueURI The URI for the redeemable true state
/// @param redeemableFalseURI The URI for the redeemable false state
/// @param redeemableDefaultIndex The default index for the redeemable state
/// @param signature The signature authorizing the mint
function mintWithTrade(
uint256 \_mintedTokenId,
uint256[] memory tradedTokenIds,
string memory mintType,
uint256 tokenPrice,
string memory redeemableTrueURI,
string memory redeemableFalseURI,
uint256 redeemableDefaultIndex,
bytes memory signature
) external payable {
// ...
}

/// @notice Checks if a token does not exist
/// @param \_tokenId The ID of the token to check
/// @return bool True if the token does not exist, false otherwise
function \_tokenNotExists(uint256 \_tokenId) internal view returns (bool) {
// ...
}

/// @notice Burns a token
/// @param tokenId The ID of the token to burn
function burn(uint256 tokenId) public virtual {
// ...
}

/// @notice Burns multiple tokens
/// @param tokenIds An array of token IDs to burn
function batchBurn(uint256[] memory tokenIds) public virtual {
// ...
}

/// @notice Burns tokens and mints a new one
/// @param tokenIds An array of token IDs to burn
/// @param \_tokenId The ID of the new token to mint
/// @param mintType The type of minting operation (burn)
/// @param tokenPrice The price to mint the token
/// @param burnsToUse The number of tokens to burn
/// @param redeemableTrueURI The URI for the redeemable true state
/// @param redeemableFalseURI The URI for the redeemable false state
/// @param redeemableDefaultIndex The default index for the redeemable state
/// @param signature The signature authorizing the mint
function burnAndMint(
uint256[] memory tokenIds,
uint256 \_tokenId,
string memory mintType,
uint256 tokenPrice,
uint256 burnsToUse,
string memory redeemableTrueURI,
string memory redeemableFalseURI,
uint256 redeemableDefaultIndex,
bytes memory signature
) external payable {
// ...
}

/// @notice Validates an authorized mint
/// @param minter The address attempting to mint
/// @param tokenId The ID of the token to mint
/// @param mintType The type of minting operation
/// @param tokenPrice The price to mint the token
/// @param tokenList The number of tokens involved (for burning or trading)
/// @param redeemableTrueURI The URI for the redeemable true state
/// @param redeemableFalseURI The URI for the redeemable false state
/// @param redeemableDefaultIndex The default index for the redeemable state
/// @param signature The signature authorizing the mint
function \_validateAuthorizedMint(
address minter,
uint256 tokenId,
string memory mintType,
uint256 tokenPrice,
uint256 tokenList,
string memory redeemableTrueURI,
string memory redeemableFalseURI,
uint256 redeemableDefaultIndex,
bytes memory signature
) internal {
// ...
}

/// @notice Recovers the signer's address from a signature
/// @param contentHash The hash of the content that was signed
/// @param signature The signature to verify
/// @return address The address that signed the message
function \_signatureWallet(
bytes32 contentHash,
bytes memory signature
) private pure returns (address) {
// ...
}

/// @notice Updates the authority signer address
/// @param newAuthoritySigner The new address to be set as the authority signer
function updateAuthoritySigner(
address newAuthoritySigner
) external onlyOwner {
// ...
}

/// @notice Withdraws the contract's balance to the owner
function withdraw() external onlyOwner {
// ...
}

/// @notice Gets the index of the current token URI
/// @param tokenId The ID of the token
/// @return uint256 The index of the current token URI
function \_getTokenURIIndex(
uint256 tokenId
) internal view returns (uint256) {
// ...
}

/// @notice Gets the URI for a given token
/// @param tokenId The ID of the token
/// @return string The URI for the token
function tokenURI(
uint256 tokenId
) public view virtual override returns (string memory) {
// ...
}

/// @notice Gets all URIs for a given token
/// @param tokenId The ID of the token
/// @return index The index of the current URI
/// @return uris An array of all URIs for the token
/// @return pinned Whether the current URI is pinned
function tokenURIs(
uint256 tokenId
) external view returns (uint256 index, string[] memory uris, bool pinned) {
// ...
}

/// @notice Pins a specific URI for a token
/// @param tokenId The ID of the token
/// @param index The index of the URI to pin
function pinTokenURI(uint256 tokenId, uint256 index) external onlyOwner {
// ...
}

/// @notice Pins the redeemable true URI for a token
/// @param tokenId The ID of the token
/// @param signature The signature authorizing the operation
function pinRedeemableTrueTokenUri(
uint256 tokenId,
bytes memory signature
) external {
// ...
}

/// @notice Unpins the URI for a token (not implemented)
/// @param tokenId The ID of the token
function unpinTokenURI(uint256 tokenId) external pure {
// ...
}

/// @notice Checks if a token has a pinned URI
/// @param tokenId The ID of the token
/// @return pinned Whether the token has a pinned URI
function hasPinnedTokenURI(
uint256 tokenId
) external view returns (bool pinned) {
// ...
}

/// @notice Sets the URIs for a token
/// @param tokenId The ID of the token
/// @param redeemableTrueURI The URI for the redeemable true state
/// @param redeemableFalseURI The URI for the redeemable false state
/// @param redeemableDefaultIndex The default index for the redeemable state
function setUri(
uint256 tokenId,
string memory redeemableTrueURI,
string memory redeemableFalseURI,
uint256 redeemableDefaultIndex
) private {
// ...
}

/// @notice Validates an authorized unpair operation
/// @param minter The address attempting to unpair
/// @param tokenId The ID of the token
/// @param signature The signature authorizing the operation
function \_validateAuthorizedUnpair(
address minter,
uint256 tokenId,
bytes memory signature
) internal {
// ...
}

/// @notice Adds a creator story to a token. Not currently used on the project
/// @param tokenId The ID of the token
/// @param creatorName The name of the creator
/// @param story The content of the story
function addCreatorStory(
uint256 tokenId,
string calldata creatorName,
string calldata story
) external {
// ...
}

/// @notice Adds a collector story to a token
/// @param tokenId The ID of the token
/// @param collectorName The name of the collector
/// @param story The content of the story
function addStory(
uint256 tokenId,
string calldata collectorName,
string calldata story
) external {
// ...
}

/// @notice Toggles the visibility of a story
/// @param tokenId The ID of the token
/// @param storyId The ID of the story
/// @param visible The new visibility status
function toggleStoryVisibility(
uint256 tokenId,
string calldata storyId,
bool visible
) external {
// ...
}

/// @notice Adds a collection story (not implemented)
/// @param creatorName The name of the creator
/// @param story The content of the story
function addCollectionStory(
string calldata creatorName,
string calldata story
) external override {}

/// @notice Gets the total supply of tokens
/// @return uint256 The total number of tokens
function totalSupply() external view returns (uint256) {
// ...
}

/// @notice Sets the total supply of tokens
/// @param newTotalSupply The new total supply
function setTotalSupply(uint256 newTotalSupply) external onlyOwner {
// ...
}

/// @notice Handles payment for minting and refunds excess ETH
/// @param tokenPrice The price required to mint the token
function _handlePaymentAndRefund(uint256 tokenPrice) private {
    // ...
}
```
