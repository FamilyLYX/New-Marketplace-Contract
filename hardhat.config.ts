import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import 'ethers';
import dotenv from 'dotenv';

dotenv.config();
const PRIVATE_KEY = process.env.PRIVATE_KEY ?? '';

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: '0.8.20',
        settings: {
          optimizer: {
            enabled: true,
            runs: 1000,
          },
        },
      },
    ],
  },
  networks: {
    lukso: {
      url: 'https://rpc.testnet.lukso.network',
      accounts: [PRIVATE_KEY],
    },
  },
  // solidity: "0.8.17",
};

export default config;
