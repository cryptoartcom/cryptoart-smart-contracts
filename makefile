# ==============================================================================
# Makefile for CryptoartNFT Foundry Project
# ==============================================================================

# Load environment variables from .env file
-include .env

# Declare phony targets
.PHONY: all test clean deploy help install snapshot format anvil updateAuthoritySigner upgradeCryptoartNFTMock mintNFT

# ==============================================================================
# Variables & Configuration
# ==============================================================================

# Default anvil private key (override if needed)
DEFAULT_ANVIL_KEY := 0x0

# Default network (override with NETWORK=<network>)
NETWORK ?= localhost

# Network-specific arguments
ifeq ($(NETWORK),localhost)
	NETWORK_ARGS := --rpc-url $(LOCAL_NODE_URL) --private-key $(PROXY_ADMIN_OWNER_PRIVATE_KEY) --broadcast
else ifeq ($(NETWORK),base-sepolia)
	NETWORK_ARGS := --rpc-url $(BASE_SEPOLIA_URL) --private-key $(PROXY_ADMIN_OWNER_PRIVATE_KEY) --legacy --broadcast --verify --etherscan-api-key $(BASE_SEPOLIA_API_KEY) -vvvv
else ifeq ($(NETWORK),sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_URL) --private-key $(PROXY_ADMIN_OWNER_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(SEPOLIA_API_KEY) -vvvv
endif

# Help: Display usage instructions
help:
	@echo "Usage:"
	@echo "  make deploy [NETWORK=localhost|base-sepolia|sepolia]"
	@echo "  make mintNFT TOKENID=<id> PRICE=<price> [MINTTYPE=<type>] [URI_REDEEMABLE=<uri>] [URI_NOT_REDEEMABLE=<uri>] [REDEEMABLE_DEFAULT_INDEX=<index>]"
	@echo "  make test"
	@echo "  make clean"
	@echo "  make install"
	@echo "  make update"
	@echo "  make build"
	
# ==============================================================================
# Standard Foundry Commands
# ==============================================================================

# Default target when running just `make`
all: build

# Clean build artifacts and cache
clean:
	@echo "Cleaning build artifacts and cache..."
	@forge clean

# Install / Update Dependencies
install:
	@echo "Installing dependencies..."
	@forge install
update:
	@echo "Updating dependencies..."
	@forge update

# Compile contracts
build:
	@echo "Building contracts..."
	@forge build

# Run tests
test: build
	@echo "Running tests..."
	@forge test

# Generate gas snapshot
snapshot: build
	@echo "Generating gas snapshot..."
	@forge snapshot

# Format code
format:
	@echo "Formatting code..."
	@forge fmt

# Start local Anvil node with a deterministic mnemonic
anvil:
	@echo "Starting Anvil node..."
	@anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

# ==============================================================================
# Deployment & Upgrade Commands
# ==============================================================================

# Deploy initial V1 contract using ProxyAdmin's key
deploy:
	@echo "Deploying to $(NETWORK)..."
	@forge clean && forge build && forge script script/DeployCryptoartNFT.s.sol:DeployCryptoartNFT $(NETWORK_ARGS)

# Update authority signer
updateAuthoritySigner:
	@echo "Updating authority signer on $(NETWORK)..."
	@forge script script/admin/UpdateAuthoritySigner.s.sol:UpdateAuthoritySigner $(NETWORK_ARGS) --private-key $(OWNER_PRIVATE_KEY) -vvvv

# Upgrade CryptoartNFTMock (requires NEW_IMPL_ADDR)
upgradeCryptoartNFTMock:
	@echo "Upgrading CryptoartNFTMock..."
	@echo "Ensure NEW_IMPL_ADDR is set after deploying CryptoartNFTMockUpgrade."
	@echo "Press Enter after setting NEW_IMPL_ADDR..." && read REPLY
	$(eval CURRENT_ARTIFACT_NAME := CryptoartNFT.sol)
	$(eval NEW_ARTIFACT_NAME := CryptoartNFTMockUpgrade.sol)
	$(eval INIT_DATA := $(shell cast calldata "initializeV2()"))
	@forge script script/UpgradeCryptoartNFT.s.sol:UpgradeCryptoartNFT \
	  --rpc-url $(LOCAL_NODE_URL) \
	  --broadcast \
	  --private-key $(PROXY_ADMIN_OWNER_PRIVATE_KEY) \
	  --sig "run(string,string,address,bytes)" \
	  "$(CURRENT_ARTIFACT_NAME)" \
	  "$(NEW_ARTIFACT_NAME)" \
	  "$(NEW_IMPL_ADDR)" \
	  "$(INIT_DATA)"

# Mint an NFT
mintNFT: check_env_mint check_args_mint
	@echo "Minting Token ID $(TOKENID) for $(MINTER_ADDRESS) at price $(PRICE) wei..."
	$(eval MINTTYPE_VALUE := $(or $(MINTTYPE),0))
	$(eval URI_REDEEMABLE := $(or $(URI_REDEEMABLE),""))
	$(eval URI_NOT_REDEEMABLE := $(or $(URI_NOT_REDEEMABLE),""))
	$(eval REDEEMABLE_DEFAULT_INDEX := $(or $(REDEEMABLE_DEFAULT_INDEX),0))
	@forge script script/MintCryptoartNFT.s.sol:MintCryptoartNFT \
	  --rpc-url $(LOCAL_NODE_URL) \
	  --broadcast \
	  --private-key $(MINTER_PRIVATE_KEY) \
	  --sig "run(address,uint256,uint256,uint8,string,string,uint8)" \
	  '$(MINTER_ADDRESS)' \
	  '$(TOKENID)' \
	  '$(PRICE)' \
	  '$(MINTTYPE_VALUE)' \
	  '$(URI_REDEEMABLE)' \
	  '$(URI_NOT_REDEEMABLE)' \
	  '$(REDEEMABLE_DEFAULT_INDEX)'

# Check required environment variables for mintNFT
check_env_mint:
ifndef TRANSPARENT_PROXY_ADDRESS
	$(error TRANSPARENT_PROXY_ADDRESS is not set. Please deploy V1 first and set it in .env)
endif
ifndef AUTHORITY_SIGNER_PRIVATE_KEY
	$(error AUTHORITY_SIGNER_PRIVATE_KEY is not set in .env)
endif
ifndef MINTER_PRIVATE_KEY
	$(error MINTER_PRIVATE_KEY is not set in .env)
endif
ifndef LOCAL_NODE_URL
	$(error LOCAL_NODE_URL is not set in .env)
endif

# Check required arguments for mintNFT
check_args_mint:
ifndef TOKENID
	$(error TOKENID is not set. Use: make mintNFT TOKENID=1 ...)
endif
ifndef PRICE
	$(error PRICE (in wei) is not set. Use: make mintNFT PRICE=10000 ...)
endif