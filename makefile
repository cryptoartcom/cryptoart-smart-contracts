# ==============================================================================
# Makefile for CryptoartNFT Foundry Project
# ==============================================================================

# Load environment variables from .env file
-include .env

# Declare phony targets
.PHONY: all test clean deploy help install snapshot format anvil updateAuthoritySigner upgradeCryptoartNFT mintNFT

# ==============================================================================
# Variables & Configuration
# ==============================================================================

# Help: Display detailed usage instructions
help:
	@echo "======================================================================"
	@echo "CryptoartNFT Makefile"
	@echo "======================================================================"
	@echo "This Makefile wraps complex 'forge' commands into simple 'make' targets."
	@echo "Saves from typing long, error-prone commands."
	@echo "Run 'make <target>' to execute tasks. Below are the key commands and how to use them:"
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "Basic Commands"
	@echo "----------------------------------------------------------------------"
	@echo "  make anvil          Start a local Anvil node (test blockchain) with a fixed mnemonic."
	@echo "                      - Use this first for local testing."
	@echo "  make build          Compile all contracts (runs 'forge build')."
	@echo "  make test           Run all tests (runs 'forge test')."
	@echo "  make clean          Remove build artifacts (runs 'forge clean')."
	@echo "  make install        Install dependencies (runs 'forge install')."
	@echo "  make update         Update dependencies (runs 'forge update')."
	@echo "  make format         Format code (runs 'forge fmt')."
	@echo "  make snapshot       Generate a gas usage snapshot (runs 'forge snapshot')."
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "Deploying Contracts (e.g., CryptoartNFT)"
	@echo "----------------------------------------------------------------------"
	@echo "  make deploy [NETWORK=<network>]"
	@echo "    Deploys the CryptoartNFT contract behind a proxy to the specified network."
	@echo "    - NETWORK options: 'localhost' (default), 'base-sepolia', 'sepolia'."
	@echo "    - Requires a .env file with network-specific vars (see README or .env.example)."
	@echo ""
	@echo "    Steps to Deploy Locally:"
	@echo "      1. Start Anvil: 'make anvil' (in one terminal)."
	@echo "      2. Open a new terminal in the same directory."
	@echo "      3. Ensure .env has LOCAL_NODE_URL=http://127.0.0.1:8545 and keys (e.g., DEPLOYER_PRIVATE_KEY)."
	@echo "      4. Run: 'make deploy' (deploys to localhost)."
	@echo "      5. Note the proxy address from the output (e.g., 0xYourProxyAddress)."
	@echo "         - Save it to .env as TRANSPARENT_PROXY_ADDRESS for later use."
	@echo ""
	@echo "    Steps to Deploy to Testnet (e.g., Sepolia):"
	@echo "      1. Ensure .env has SEPOLIA_URL, SEPOLIA_API_KEY, and DEPLOYER_PRIVATE_KEY."
	@echo "      2. Run: 'make deploy NETWORK=sepolia'."
	@echo "      3. Wait for deployment and verification (check output for success)."
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "Upgrading Contracts"
	@echo "----------------------------------------------------------------------"
	@echo "  make upgradeCryptoartNFT [NETWORK=<network>]"
	@echo "    Upgrades the deployed proxy to a new implementation (e.g., CryptoartNFTUpgrade)."
	@echo "        - Requires a prior proxy deployment (TRANSPARENT_PROXY_ADDRESS in .env)."
	@echo "        - This will deploy the new implementation contract for you, no need to do that separately"
	@echo ""
	@echo "    Steps:"
	@echo "      1. Run: 'make upgradeCryptoartNFT NETWORK=<some network>'."
	@echo "      2. Wait for deployment and verification (check output for success)."
	@echo ""
	@echo "----------------------------------------------------------------------"
	@echo "Minting an NFT"
	@echo "----------------------------------------------------------------------"
	@echo ""
	@echo "  make mintNFT  TOKENID=<id> PRICE=<price> [optional args] [NETWORK=<network>] [MINTTYPE=<some mint type value>] [URI_REDEEMABLE=<some URI string>] [URI_NOT_REDEEMABLE=<some URI string>] [REDEEMABLE_DEFAULT_INDEX=<either 0 or 1>]"
	@echo "    Mints an NFT on localhost (requires a deployed contract)."
	@echo "    - Required: TOKENID (e.g., 1), PRICE (in wei, e.g., 100000000000000000 for 0.1 ETH)."
	@echo "    - Optional: NETWORK, MINTTYPE, URI_REDEEMABLE, URI_NOT_REDEEMABLE, REDEEMABLE_DEFAULT_INDEX."
	@echo ""
	@echo "    Steps to mint locally:"
	@echo "      1. Deploy the contract: 'make deploy' (if not already done)."
	@echo "      2. Update .env with TRANSPARENT_PROXY_ADDRESS from deployment."
	@echo "      3. Run: 'make mintNFT TOKENID=1 PRICE=100000000000000000'."
	@echo "      4. For a free mint with custom URIs:"
	@echo "         'make mintNFT TOKENID=2 PRICE=0 MINTTYPE=1 URI_REDEEMABLE=\"ipfs://redeemable\" URI_NOT_REDEEMABLE=\"ipfs://not_redeemable\"'."
	@echo ""
	@echo "    Steps to mint to Testnet (e.g., Sepolia):"
	@echo "      1. Ensure .env has SEPOLIA_URL, and DEPLOYER_ADDRESS."
	@echo "      2. Run: 'make mintNFT TOKENID=<insert some token id> PRICE=<insert some token price> NETWORK=sepolia'."
	@echo "      3. Wait for verification (check output for success)."
	@echo ""

# Default anvil private key (override if needed)
DEFAULT_ANVIL_KEY := 0x0

# Default network (override with NETWORK=<network>)
NETWORK ?= localhost

# Network-specific arguments
ifeq ($(NETWORK),localhost)
	NETWORK_ARGS := --rpc-url $(LOCAL_NODE_URL) --broadcast
else ifeq ($(NETWORK),base-sepolia)
	NETWORK_ARGS := --rpc-url $(BASE_SEPOLIA_URL) -vvvv 
else ifeq ($(NETWORK),sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_URL) --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast -vvvv --verify --account cryptoart-deployer-testnet --sender $(DEPLOYER_ADDRESS) 
endif

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
deployTestnet:
	@echo "Deploying to $(NETWORK)..."
	@forge clean && forge build && forge script script/DeployCryptoartNFT.s.sol:DeployCryptoartNFT --legacy $(NETWORK_ARGS)

# deployMainnet:
# 	@echo "Deploying to $(NETWORK)..."
# 	@forge clean && forge build && forge script script/DeployCryptoartNFT.s.sol:DeployCryptoartNFT --legacy --account cryptoart-deployer --sender <WALLET ADDRESS HERE> --rpc-url $(MAINNET_URL) --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast --verify -vvvv 

# Update authority signer
updateAuthoritySigner:
	@echo "Updating authority signer on $(NETWORK)..."
	@forge script script/admin/UpdateAuthoritySigner.s.sol:UpdateAuthoritySigner --private-key $(OWNER_PRIVATE_KEY) $(NETWORK_ARGS)

# Upgrade CryptoartNFT

# TODO: There's something wrong with this command but I'm not sure what.  I couldn't get it to work but when I manually entered the forge script command, it worked.  Just remember to:
# 1. make sure the env vars are correct
# 2. make sure the --broadcast flag is set
# 3. do forge cache clean, forge clean, forge build first
# 4. add the --verify flag and etherscan-api-key for verification
# Heres the command I used that worked:
# forge script script/UpgradeCryptoartNFT.s.sol:UpgradeCryptoartNFT --sig "run(string,string,bytes)" "CryptoartNFT.sol" "CryptoartNFT.sol" "0x" --rpc-url https://eth-sepolia.g.alchemy.com/v2/<api-key-here> --private-key <proxy-admin-private-key-here> --broadcast

upgradeCryptoartNFT:
	@echo "Upgrading CryptoartNFT..."
	$(eval CURRENT_ARTIFACT_NAME := CryptoartNFT.sol)
	$(eval NEW_ARTIFACT_NAME := CryptoartNFT.sol)
	# $(eval INIT_DATA := $(shell cast calldata "")) # Any additional functions such as another Initalizer to be called needs to be added here in the form of a function signature
	@forge clean && forge build && \
	forge script script/UpgradeCryptoartNFT.s.sol:UpgradeCryptoartNFT \
		--sig "run(string,string,bytes)" \
			"$(CURRENT_ARTIFACT_NAME)" \
			"$(NEW_ARTIFACT_NAME)" \
			"0x" \ # No data if not running any additional initializer functions
		$(NETWORK_ARGS)

# Mint an NFT
mintNFT: check_env_mint check_args_mint
	@echo "Minting Token ID $(TOKENID) for $(DEPLOYER_ADDRESS) at price $(PRICE) wei..."
	$(eval MINTTYPE_VALUE := $(or $(MINTTYPE),0))
	$(eval URI_REDEEMABLE := $(or $(URI_REDEEMABLE),""))
	$(eval URI_NOT_REDEEMABLE := $(or $(URI_NOT_REDEEMABLE),""))
	$(eval REDEEMABLE_DEFAULT_INDEX := $(or $(REDEEMABLE_DEFAULT_INDEX),0))
	$(eval DEADLINE := $(or $(DEADLINE),2000000000))
	@forge script script/MintCryptoartNFT.s.sol:MintCryptoartNFT \
	 	--private-key $(DEPLOYER_PRIVATE_KEY) \
	  	--sig "run(address,uint256,uint8,uint256,string,string,uint8,uint256)" \
		  	'$(DEPLOYER_ADDRESS)' \
			'$(TOKENID)' \
			'$(MINTTYPE_VALUE)' \
		  	'$(PRICE)' \
			'$(URI_REDEEMABLE)' \
			'$(URI_NOT_REDEEMABLE)' \
			'$(REDEEMABLE_DEFAULT_INDEX)' \
			'$(DEADLINE)' \
		$(NETWORK_ARGS)

# Check required environment variables for mintNFT
check_env_mint:
ifndef TRANSPARENT_PROXY_ADDRESS
	$(error TRANSPARENT_PROXY_ADDRESS is not set. Please deploy V1 first and set it in .env)
endif
ifndef AUTHORITY_SIGNER_PRIVATE_KEY
	$(error AUTHORITY_SIGNER_PRIVATE_KEY is not set in .env)
endif
ifndef DEPLOYER_PRIVATE_KEY
	$(error DEPLOYER_PRIVATE_KEY is not set in .env)
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
