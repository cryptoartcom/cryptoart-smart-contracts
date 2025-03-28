# CryptoArt NFT

## Table of Contents

1. [Project Overview](#1-project-overview)
2. [Scope Definition](#2-scope-definition) 
3. [Features Overview](#3-features-overview)
4. [Architecture & Core Mechanisms](#4-architecture--core-mechanisms)
5. [Actors & Roles](#5-actors--roles)
6. [Trust Assumptions & Centralization Risks](#6-trust-assumptions--centralization-risks)
7. [External Dependencies](#7-external-dependencies)
8. [Setup & Testing](#8-setup--testing)
9. [Known Issues](#9-known-issues)

---

## 1. Project Overview

The Cryptoart NFT project aims to create a unique NFT collection on the Base blockchain that bridges digital ownership with physical art pieces. The core concept revolves around "pairable" NFTs:

*   NFTs represent ownership of crypto-related art.
*   Holders can "unpair" (un-redeem) their NFT by destroying the physical piece's authentication mechanism (NFC sticker/QR code) and use an authorized process to reset its metadata to Redeemable = TRUE.This allows the holder to sell the NFT in a redeemable state, enabling future holders to pair it with the same physical numbered art piece. The process removes risks and authentication concerns normally associated with collector-to-collector shipment of physical art.
*   Holders may opt to sell their NFT while it's still paired. Since NFTs can only be paired with one numbered art piece, paired NFTs trade/function like traditional (non-redeemable) NFTs.
*   The collection utilizes scarcity mechanics, allowing users to burn or trade existing NFTs within the collection for potentially more desirable ones.
*   Owners can add "stories" to their NFTs, creating a permanent, on-chain provenance log via emitted events (IStory interface).

The primary smart contract, `CryptoartNFT.sol`, manages the minting, burning, ownership, metadata (including pairing status via IERC7160), royalties (ERC2981), and story inscriptions for the collection. Minting operations are primarily controlled via an off-chain voucher system, requiring signatures from a trusted `authoritySigner`.

The contracts are developed using Foundry and utilize OpenZeppelin's upgradeable contracts (`@openzeppelin-contracts-upgradeable-5.0.2`), deploying behind a proxy.

---

## 2. Scope Definition

The following files are in scope:

```
src/
├── CryptoartNFT.sol            # Main contract implementing ERC721 with extensions
├── interfaces
│   ├── IERC7160.sol            # Interface for multi-metadata extension
│   └── IStory.sol              # Interface for story functionality
└── libraries
    └── Error.sol               # Custom error definitions
```

### Primary Contract: CryptoartNFT.sol

This contract is the core implementation, inheriting from multiple OpenZeppelin contracts and implementing custom interfaces:
- Implements ERC721 with Enumerable, Royalty, and Burnable extensions
- Implements IERC7160 for metadata management
- Implements IERC4906 for metadata updates
- Implements IStory for story functionality
- Includes Ownable, Pausable, and ReentrancyGuard for security and control

---

## 3. Features Overview

- **Signature-Based Voucher System**: Ensures secure, authorized minting through cryptographically verified vouchers
- **Physical/Digital Pairing**: NFTs can be paired with physical art pieces and later unpaired if the physical art is destroyed
- **Story Functionality**: NFT owners can attach stories to enrich the context of their artwork.
- **Scarcity Mechanics**: Supports burning existing tokens to mint new, potentially more valuable tokens
- **Admin Controls**: Owner-managed features for royalties, pausing, and contract configuration

```mermaid
graph TD
    %% External Actors
    Users("Users"):::external
    Admin("Admin/Owner"):::admin
    Signer("Off-Chain Authority Signer"):::offchain
    NFTReceiver("NFT Receiver"):::external 
    %% For specific mint types

    %% On-Chain Components
    subgraph "On-Chain Components"
        Proxy("Proxy/Upgrade Manager"):::onchain
        Contract("CryptoartNFT (Core Contract) - Handles mint, burn, pairing, metadata, etc."):::onchain
    end

    %% Off-Chain Support Components
    OffchainIndexing["Off-chain Indexing/Provenance"]:::offchain

    %% Core Relationships
    Users -->|"Interact (mint, burn, pair, etc.)"| Proxy
    Admin -->|"Admin Functions (pause, upgrades, etc.)"| Proxy
    Proxy -->|"delegatecall"| Contract

    %% Voucher Flow (Simplified & Corrected)
    Users -->|"Request Signature (Off-Chain)"| Signer
    Signer -->|"Issues Signature (Off-Chain)"| Users
    Contract --->|"Verifies Signature using Signer's Key"| Signer

    %% Event Emission
    Contract -->|"Emits Events (Transfer, MetadataUpdate, etc.)"| OffchainIndexing

    %% Specific Mint Interaction (Example)
    Contract -->|"mintWithTrade"| NFTReceiver

    %% Styles
    classDef onchain fill:#6CA6CD,stroke:#000,stroke-width:2px,color:#000;
    classDef offchain fill:#FF8C00,stroke:#000,stroke-width:2px,color:#000;
    classDef admin fill:#32CD32,stroke:#000,stroke-width:2px,color:#000;
    classDef external fill:#FF6B6B,stroke:#000,stroke-width:2px,color:#000;
```

---

## 4. Architecture & Core Mechanisms

The system revolves around the `CryptoartNFT.sol` contract, which inherits these contracts:

*   **ERC721:** Base NFT standard (Enumerable, Burnable).
*   **ERC2981:** NFT Royalty Standard.
*   **IERC7160:** Multi-Metadata for managing pairing status.
*   **IStory:** Interface for adding creator/collector stories.
*   **OwnableUpgradeable:** Access control for administrative functions. (Openzeppelin)
*   **PausableUpgradeable:** Emergency stop mechanism. (Openzeppelin)
*   **NoncesUpgradeable:** Replay protection for signatures. (Openzeppelin)
*   **ReentrancyGuardUpgradeable:** Protection against reentrancy attacks on specific functions. (Openzeppelin)

### Signature-Based Voucher Minting

*   Minting actions (`mint`, `claim`, `mintWithTrade`, `burnAndMint`) require a `MintValidationData` struct containing parameters like `recipient`, `tokenId`, `mintType`, `tokenPrice`, and a cryptographic `signature`.
*   This signature must be generated off-chain by the designated `authoritySigner` address.
*   The signature validates the mint parameters, including the initial metadata URIs (`TokenURISet`) for the specific token.
*   The contract verifies the signature against a hash of the parameters, the contract address, and a unique nonce for the recipient (`_validateSignature`, `_isValidSignature`). The nonce prevents replay attacks using the same signature.
*   Payment is handled within the mint functions, validating `msg.value` against `tokenPrice` and refunding excess ETH.

### Physical/Digital Pairing - NFT Pairing/Redemption (IERC7160)

*   This mechanism manages the "redeemable" status of the NFT, corresponding to whether a physical counterpart can be claimed.
*   Each token stores two URIs (`_tokenURIs` mapping): one for when redeemable (`Redeemable = TRUE`) and one for when not redeemable (`Redeemable = FALSE`).
*   The `_pinnedURIIndices` mapping stores which of the two URIs is currently active, controlled by the `_hasPinnedTokenURI` flag.
*   The `tokenURI` function returns the currently active URI based on the pinned index.
*   **Pairing (Redeeming Physical):** Handled off-chain by Cryptoart.com. The `Owner` can use `pinTokenURI(tokenId, 1)` to set the metadata to the "not redeemable" state (index 1).
*   **Unpairing (Destroying Physical):** The token owner calls `markAsRedeemable(tokenId, signature)`. This requires a signature from the `authoritySigner` (verified via `_validateUnpairAuthorization`) to authorize the state change back to "redeemable" (index 0). This can be an off-chain process where the user proves physical destruction to the authority, who then provides the signature.
*   Metadata updates emit `MetadataUpdate` (ERC4906) and `TokenUriPinned` events.

### Story Inscriptions (IStory)

*   Implements functions (`addCreatorStory`, `addStory`) allowing token owners to emit events containing story text/metadata.
*   Visibility toggling (`toggleStoryVisibility`) emits an event, interpreted off-chain.
*   Right now, story content is stored in event logs, not contract storage. This could potentially change though.

### Scarcity Mechanics

*   `mintWithTrade`: Allows minting a new token by providing a voucher and transferring a specified list of existing NFTs from the sender to the `nftReceiver` address.
*   `burnAndMint`: Allows minting a new token by providing a voucher and burning a specified list and count of existing NFTs owned by the sender.
* `totalSupply`: Limited total supply enforced against a set max supply. Both of these parameters can be adjusted by the contract owner. 

### Royalties (ERC2981)

*   Standard implementation using OpenZeppelin's `ERC721RoyaltyUpgradeable`.
*   Default royalty set during initialization, updatable by the `Owner`.
*   Token-specific royalties can also be set by the `Owner`.

### Upgradeability

*   The contract uses OpenZeppelin Upgradeable libraries (`@openzeppelin-contracts-upgradeable-5.0.2`).
*   It includes an `initializer` function and inherits `Initializable`.

---

## 5. Actors & Roles

*   **Contract Owner (`OwnableUpgradeable`):**
    *   Privileged administrator of the contract.
    *   Can pause/unpause the contract.
    *   Can withdraw all contract ETH balance.
    *   Can update critical parameters: `authoritySigner`, `nftReceiver`, default royalties, `baseURI`, `maxSupply`.
    *   Can update token metadata URIs directly (`updateMetadata`).
    *   Can pin token URIs (`pinTokenURI`).
    *   Can set token-specific royalties.
    *   Can transfer ownership.
    *   *Implicitly:* Controls the upgradeability mechanism via a ProxyAdmin or similar pattern.
*   **Authority Signer (`authoritySigner`):**
    *   A trusted off-chain entity (or key) responsible for signing messages (vouchers) that authorize minting operations.
    *   Also signs messages required for users to "unpair" their NFT (`markAsRedeemable`).
    *   Does *not* have direct on-chain execution privileges but holds gatekeeping power over token creation and state changes related to pairing.
    *   Address is configurable by the `Owner`.
*   **NFT Receiver (`nftReceiver`):**
    *   An address designated to receive NFTs that are traded in during `mintWithTrade` operations.
    *   Configurable by the `Owner`. Assumed to be a controlled wallet/contract.
*   **Users / Collectors:**
    *   Interact with the contract to mint (with a valid voucher and payment), claim, burn, or trade NFTs.
    *   Can call `markAsRedeemable` (with a valid signature from the `authoritySigner`) to change the NFT state after physical destruction.
    *   Can add stories to owned NFTs (`addCreatorStory`, `addStory`).
    *   Can toggle visibility of stories (`toggleStoryVisibility`).
    *   Standard ERC721 interactions (transfer, approve).

---

## 6. Trust Assumptions & Centralization Risks

This system has significant centralization aspects that auditors should be aware of:

1.  **Owner:** The `Owner` role holds extensive power. A compromised or malicious Owner can:
    *   Steal all funds via `withdraw()`.
    *   Halt all operations via `pause()`.
    *   Change the `authoritySigner` to themselves or a colluding address, enabling unauthorized minting/unpairing.
    *   Change the `nftReceiver` to steal traded NFTs.
    *   Modify royalties arbitrarily.
    *   Brick functionality by setting invalid parameters.
    *   Perform contract upgrades (implicitly) to introduce arbitrary logic changes.
    *   **Assumption:** The `Owner` address/entity is highly trusted and secured.
2.  **Authority Signer:** Control over the `authoritySigner` key(s) is paramount. A compromised or malicious signer can:
    *   Authorize the minting of arbitrary NFTs up to `maxSupply`, potentially devaluing the collection or bypassing payment logic (if `tokenPrice` is manipulated in the signed message).
    *   Authorize the "unpairing" (`markAsRedeemable`) of any NFT, breaking the link between digital state and physical reality.
    *   **Assumption:** The `authoritySigner` key(s) are securely managed off-chain, and the signing process is robust against manipulation and unauthorized access. The off-chain service generating these signatures can be assumed to be secure and reliable.
3.  **Off-Chain Voucher/Signature Generation:** The entire minting and unpairing process relies on an off-chain system generating signatures. The security, availability, and correctness of this off-chain system are critical but *out of scope* for this smart contract audit.
4.  **Upgradeability:** The mechanism used for upgrades (e.g., ProxyAdmin owner) introduces trust assumptions regarding who can perform upgrades and the security of that process.
5.  **NFT Receiver:** Less critical, but the destination for traded NFTs relies on the `Owner` setting a correct and secure address.

---

## 7. External Dependencies

*   **@openzeppelin/contracts-upgradeable v5.0.2:**
    *   `access/OwnableUpgradeable.sol`
    *   `token/ERC721/extensions/ERC721BurnableUpgradeable.sol`
    *   `token/ERC721/extensions/ERC721EnumerableUpgradeable.sol`
    *   `token/ERC721/extensions/ERC721RoyaltyUpgradeable.sol`
    *   `utils/NoncesUpgradeable.sol`
    *   `utils/PausableUpgradeable.sol`
    *   `utils/ReentrancyGuardUpgradeable.sol`
*   **@openzeppelin/contracts v5.0.2:** 
    *   `interfaces/IERC4906.sol`
    *   `utils/cryptography/ECDSA.sol`
    *   `utils/cryptography/MessageHashUtils.sol`
    *   `utils/Strings.sol`

**Assumptions about Dependencies:**
*   The OpenZeppelin contracts are assumed to be secure and behave as documented for version 5.0.2.
*   Standard cryptographic primitives (`ECDSA`, `keccak256`) are assumed to be secure.

---

## 8. Setup & Testing

The project uses Foundry for development and testing.

### Environment Setup

1. Install Foundry:
```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

2. Clone the repository:
```bash
git clone https://github.com/cryptoartcom/cryptoart-smart-contracts.git
cd cryptoart-smart-contracts
```

3. Install dependencies:
```bash
forge install
```

4. Compile contracts:
```bash
forge build
```

### Running Tests

```bash
# Run all tests
forge test

# Run tests with gas reporting
forge test --gas-report

# Run tests with verbosity
forge test -vvv

# Check test coverage
forge coverage
```

### Test Coverage

Our test suite includes:
- Unit tests for all contract functions
- Integration tests for key user workflows
- Fuzz tests for mint, burn, and metadata operations

```
test/
├── CryptoartNFTBase.t.sol        # Base test setup
├── fuzz/                         # Fuzz testing
│   ├── BurnFuzzTest.t.sol
│   ├── MetadataFuzzTest.t.sol
│   └── MintFuzzTest.t.sol
├── helpers/                      # Test helpers
│   ├── SigningUtils.sol
│   ├── TestAssertions.sol
│   └── TestFixtures.sol
├── integration/                  # Integration tests
│   ├── FullWorkFlow.t.sol
│   ├── LifecycleTest.t.sol
│   └── RoyaltyMetadataTest.t.sol
└── unit/                         # Unit tests
    ├── Admin.t.sol
    ├── BurnOperationsTest.t.sol
    ├── Initialization.t.sol
    ├── MetadataManagementTest.t.sol
    ├── MintOperationsTest.t.sol
    └── StoryFeaturesTest.t.sol 
```

## 9. Known Issues 

1. The `unpinTokenURI` function is currently a stub. This function is required by the IERC7160 interface but has not been implemented yet.  Per the EIP, its behaviour is flexible, but currently, there's no way to revert a token to an "unpinned" state via this function.

2.  **Centralization:** As noted in [Trust Assumptions & Centralization Risks](#5-trust-assumptions--centralization-risks), the system relies heavily on the `Owner` and the off-chain `authoritySigner`.

3. The contract relies on signature-based validation, which requires careful key management for the authoritySigner role.

4.  **Gas Usage in Batch Operations:** Functions like `_batchBurn`, `_batchTransferToNftReceiver` iterate over arrays. While there's a `MAX_BATCH_SIZE` constant, ensure this limit is appropriate to avoid exceeding block gas limits in practice on the target network (Base). The duplicate check in `_batchBurn` has O(n^2) complexity, which could be very costly for larger batches near the limit, but again, the max batch size constant should restrict this effect.