import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import '@openzeppelin/hardhat-upgrades';

const INFURA_API_KEY = 'ef5c71f0aa144eb89fbef447df6df86c';
const SEPOLIA_PRIVATE_KEY =
  'bb57627e6c73b139615942280dc9464d9f7e5694a2ff4ab05b2ec3496e02f176';

const config: HardhatUserConfig = {
  solidity: '0.8.20',
  defaultNetwork: 'hardhat',
  networks: {
    sepolia: {
      url: `https://sepolia.infura.io/v3/${INFURA_API_KEY}`,
      accounts: [SEPOLIA_PRIVATE_KEY],
    },
  },
  etherscan: {
    apiKey: {
      sepolia: 'QVK5GU9IX34S142NUV2ITBTF7NQJ8DDJZU',
    },
  },
};

export default config;
