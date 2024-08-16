# Cryptoart Contract

15 / Aug / 2024

## Project Mission

The goal of this project is to offer a way for users to mint, claim, burn and trade NFTs using a voucher system inside the Cryptoart ecosystem. The voucher is a signed message by the authority wallet, which could be the owner of the contract, validating all fields of the token are correct. The voucher is a JSON object created by our API that uses the same fields as the mint parameters and chain values.

The contract owner and users can toggle the token metadata between two predefined values using the implementation of `IERC7160`.

Finally, users can create stories for their NFTs and toggle their visibility on our page by emitting events on the contract with the implementation of `IStory`.

All features use events to track the actions and changes on the contract.

## Scope of Audit

Just the CryptoartNFT.sol file. The interfaces are just used to define events and functions.

## Expected Behavior of CryptoartNFT.sol

Users can mint by utilizing a valid voucher issued for their wallet, ensuring each voucher is single-use and exclusive to the designated wallet. Additionally, users can craft stories for their NFTs and switch their metadata from index 0 to 1 using `pinRedeemableTrueTokenUri()`.

This repo is a hardhat enviroment. The contract I would like audited is in contracts. The test scripts are in test and the scripts folder contains scripts to deploy and upgrade the contract using proxy pattern.

### Verified contract is live on Base Sepolia

Implementation contract: `0xacb8e70d2f3e0ed7b153b6717061f7cefd426376`

Proxy contract: `0x55050A8408550a995968a6e72048076FE35dA950`

Hardhat/node commands:

Deploy contract Upgrade contract

```shell
npx hardhat run scripts/deploy.ts --network base-sepolia
npx hardhat run scripts/update-implementation-contract.ts --network base-sepolia
```

Run unit tests:

```shell
npx hardhat test
```

To use the hardhat commands, a .env file will need to be created which defines:

- SEPOLIA_ACCOUNT_KEY: the private key of the account that will deploy the contract
- MINT_ACCOUNT_KEY: the private key of the account that will own the contract and sign vouchers
- WALLET_NUMBER: the wallet number of the account that will own the contract and sign vouchers
- CONTRACT: the contract address
- ETHERSCAN_API_KEY: the etherscan api key for hardhat
- BASE_SEPOLIA_ETHERSCAN_API_KEY: the etherscan api key for base sepolia

## Audit prep checklist

- [x] Documentation (A plain english description of what you are building, and why you are building it. Should indicate the actions and states that should and should not be possible)
  - [x] For the overall system
  - [x] For each unique contract within the system
- [x] Clean code
  - [x] Run a linter (like [EthLint](https://www.ethlint.com/))
  - [x] Fix compiler warnings
  - [x] Remove TODO and FIXME comments
  - [x] Delete unused code
- [x] Testing
  - [x] README gives clear instructions for running tests
  - [x] Testing dependencies are packaged with the code OR are listed including versions
- [x] Automated Analysis
  - [x] OpenZeppelin - Defender
- [x] Frozen code
  - [x] Halt development of the contract code
  - [x] Provide commit hash for the audit to target
