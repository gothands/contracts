import "@nomiclabs/hardhat-waffle";
import { HardhatUserConfig } from "hardhat/config";
import { HttpNetworkUserConfig } from "hardhat/types";
import secrets from "./secrets.json";
import "@nomicfoundation/hardhat-verify";

import "@typechain/hardhat";
import "hardhat-deploy";
import "hardhat-abi-exporter";
import "hardhat-gas-reporter";
import "@nomiclabs/hardhat-ethers";

require('dotenv').config();

// dynamically changes endpoints for local tests
const zkSyncTestnet =
  process.env.NODE_ENV == "test"
    ? {
        url: "http://localhost:3050",
        ethNetwork: "http://localhost:8545",
        zksync: true,
      }
    : {
        url: "https://testnet.era.zksync.dev",
        ethNetwork: "goerli",
        zksync: true,
        verifyURL: "https://testnet-explorer.zksync.dev/contract_verification",
      };

module.exports = {
  zksolc: {
    version: "1.3.5",
    compilerSource: "binary",
    settings: {},
  },
  defaultNetwork: "localhost",
  etherscan: {
    apiKey: {
     "base-goerli": "PLACEHOLDER_STRING",
     "arbitrumGoerli": process.env.ARBISCAN_API_KEY as string,
    },
    customChains: [
      {
        network: "base-goerli",
        chainId: 84531,
        urls: {
         apiURL: "https://api-goerli.basescan.org/api",
         browserURL: "https://goerli.basescan.org"
        }
      }
    ]
  },

  networks: {
    arbitrumGoerli: {
      url: "https://goerli-rollup.arbitrum.io/rpc",
      chainId: 421613,
      accounts: secrets.privateKeyArbitrumGoerli ? [secrets.privateKeyArbitrumGoerli] : [],
    },
    hardhat: {},
    // load test network details
    zkSyncTestnet,
  },
  solidity: {
    version: "0.8.17",
  },
};
