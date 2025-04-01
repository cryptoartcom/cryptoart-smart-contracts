-include .env

.PHONY: all test clean deploy fund help install snapshot format anvil deployCryptoartNFT

DEFAULT_ANVIL_KEY := 0x0

help:
	@echo "Usage:"
	@echo "  make deploy [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""
	@echo ""
	@echo "  make fund [ARGS=...]\n    example: make deploy ARGS=\"--network sepolia\""

all: clean remove install update build

# Clean the repo
clean  :; forge clean

# Remove modules
remove :; rm -rf .gitmodules && rm -rf .git/modules/* && rm -rf lib && touch .gitmodules && git add . && git commit -m "modules"

install :; forge install 

# Update Dependencies
update:; forge update

build:; forge build

test :; forge test 

snapshot :; forge snapshot

format :; forge fmt

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

ifeq ($(findstring --network localhost,$(ARGS)), --network localhost)
	NETWORK_ARGS := --rpc-url http://127.0.0.1:8545 --private-key $(PROXY_ADMIN_PRIVATE_KEY) --broadcast -vvvv
endif
	
ifeq ($(findstring --network base-sepolia,$(ARGS)),--network base-sepolia)
	NETWORK_ARGS := --rpc-url $(BASE_SEPOLIA_URL) --private-key $(PROXY_ADMIN_PRIVATE_KEY) --legacy --broadcast --verify --etherscan-api-key $(BASE_SEPOLIA_API_KEY) -vvvv
endif

ifeq ($(findstring --network sepolia,$(ARGS)),--network sepolia)
	NETWORK_ARGS := --rpc-url $(SEPOLIA_URL) --private-key $(PROXY_ADMIN_PRIVATE_KEY) --broadcast --verify --etherscan-api-key $(SEPOLIA_API_KEY) -vvvv
endif

deployCryptoartNFT:
	@forge clean && forge build && forge script script/DeployCryptoartNFT.s.sol:DeployCryptoartNFT $(NETWORK_ARGS)

upgradeCryptoartNFT:
	@forge clean && forge build && forge script script/UpgradeCryptoartNFT.s.sol:UpgradeCryptoartNFT $(NETWORK_ARGS)

updateAuthoritySigner:
	@forge script script/admin/UpdateAuthoritySigner.s.sol:UpdateAuthoritySigner --rpc-url http://127.0.0.1:8545 --private-key $(OWNER_PRIVATE_KEY) --broadcast -vvvv 

upgradeCryptoartNFTMock:
	@echo "STEP 1: Ensure you have deployed CryptoartNFTMockUpgrade and set NEW_IMPL_ADDR environment variable."
	@echo "  Example: forge create test/upgrade/CryptoartNFTMockUpgrade.sol:CryptoartNFTMockUpgrade --rpc-url $(LOCAL_NODE_URL) --private-key $(PROXY_ADMIN_PRIVATE_KEY)"
	@echo "  Then: export NEW_IMPL_ADDR=<deployed_address>"
	@echo "Press Enter after setting NEW_IMPL_ADDR..." && read REPLY
	$(eval CURRENT_ARTIFACT_NAME := "CryptoartNFT")
	$(eval NEW_ARTIFACT_NAME := "CryptoartNFTMockUpgrade")
	$(eval INIT_DATA := $(shell cast calldata "initializeV2()"))
	@echo "STEP 2: Running upgrade script..."
	@forge script script/UpgradeCryptoartNFT.s.sol:UpgradeCryptoartNFT \
	  --rpc-url $(LOCAL_NODE_URL) \
	  --broadcast \
	  --private-key $(PROXY_ADMIN_OWNER_PRIVATE_KEY) \
	  --sig "run(string,string,address,bytes)" \
	  "$(CURRENT_ARTIFACT_NAME)" \
	  "$(NEW_ARTIFACT_NAME)" \
	  "$(NEW_IMPL_ADDR)" \
	  "$(INIT_DATA)" \
	  -vvvv	

mint:
	# @forge script script/interactions.s.sol:MintNFT $(NETWORK_ARGS)

# These two commands are the exact same:
# $ forge script script/DeployCryptoartNFT.s.sol:DeployCryptoartNFT --rpc-url $BASE_SEPOLIA_URL --private-key $PROXY_ADMIN_PRIVATE_KEY --legacy --broadcast --verify --etherscan-api-key $(BASE_SEPOLIA_API_KEY) -vvvv
# $ make deployCryptoartNFT ARGS="--network base-sepolia"

# Minting
# cast send 0x1a8987e126B572c3De795180A86fCAb643543f92 "mintTo(address)" <To address> --private-key 0xac361b57907c5f34bfaef8dc2edb52d0cc68a0388e0d3afe0336db761dea26ec --rpc-url https://rpc.testnet.tomochain.com --value 1ether --legacy

# Cast call examples:
# cast call <CALLING CONTRACT ADDRESS> <FUNCTION SIG> <ARGUMENTS> <RPC URL> --legacy
# cast call 0x1a8987e126B572c3De795180A86fCAb643543f92 "ownerOf(uint256)" 2 --rpc-url https://rpc.testnet.sepolia.com --legacy
# Cast send example
# cast send <CALLING CONTRACT ADDRESS> <FUNCTION SIG> <ARGUMENTS> <RPC URL> <PRIVATE KEY> --legacy
# cast send 0x9f2ae804Ae4A496A4F71ae16a509A67a151Ab787 "setControllers(address, bool)" 0x637D7Ea1f3271cC58DBBbC5585F24D26a9010931 true --rpc-url $SEPOLIA_URL --private-key $PRIVATE_KEY --legacy