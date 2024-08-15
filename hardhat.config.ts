import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

import * as dotenv from "dotenv";
dotenv.config();

const INFURA_API_KEY = process.env.INFURA_API_KEY;
const ACCOUNT_KEY = process.env.SEPOLIA_ACCOUNT_KEY
	? [process.env.SEPOLIA_ACCOUNT_KEY]
	: [""];
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

const config: HardhatUserConfig = {
	solidity: {
		version: "0.8.20",
		settings: {
			optimizer: {
				enabled: true,
				runs: 200,
			},
			viaIR: true,
		},
		compilers: [
			{
				version: "0.8.20",
				settings: {
					optimizer: {
						enabled: true,
						runs: 200,
					},
					viaIR: true,
				},
			},
		],
	},
	defaultNetwork: "hardhat",
	networks: {
		sepolia: {
			url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
			accounts: ACCOUNT_KEY,
		},
		// for mainnet
		"base-mainnet": {
			url: "https://mainnet.base.org",
			accounts: ACCOUNT_KEY,
			gasPrice: 1000000000,
		},
		// for testnet
		"base-sepolia": {
			url: "https://sepolia.base.org",
			accounts: ACCOUNT_KEY,
			gasPrice: 1000000000,
		},
		hardhat: {
			accounts: {
				accountsBalance: "10000000000000000000000", // 10,000 ETH
			},
		},
	},
	etherscan: {
		apiKey: {
			sepolia: ETHERSCAN_API_KEY,
			"base-sepolia": process.env.BASE_SEPOLIA_ETHERSCAN_API_KEY as string,
		},
		customChains: [
			{
				network: "base-sepolia",
				chainId: 84532,
				urls: {
					apiURL: "https://api-sepolia.basescan.org/api",
					browserURL: "https://sepolia.basescan.org",
					// apiURL: "https://base-sepolia.blockscout.com/api",
					// browserURL: "https://base-sepolia.blockscout.com",
				},
			},
		],
	},
};

export default config;
