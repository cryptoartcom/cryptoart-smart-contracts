import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import "@openzeppelin/hardhat-upgrades";

import * as dotenv from "dotenv";
dotenv.config();

const INFURA_API_KEY = process.env.INFURA_API_KEY;
const SEPOLIA_ACCOUNT_KEY = process.env.SEPOLIA_ACCOUNT_KEY
	? [process.env.SEPOLIA_ACCOUNT_KEY]
	: [""];
const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";

const config: HardhatUserConfig = {
	solidity: "0.8.20",
	defaultNetwork: "hardhat",
	networks: {
		sepolia: {
			url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
			accounts: SEPOLIA_ACCOUNT_KEY,
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
		},
	},
};

export default config;
