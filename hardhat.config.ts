import * as dotenv from "dotenv";
import { task } from "hardhat/config";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-etherscan";
import "@nomiclabs/hardhat-ethers";
import "hardhat-gas-reporter";
import "hardhat-contract-sizer";
import "solidity-coverage";

dotenv.config();
const privateKey = process.env.PRIVATE_KEY;
const infuraKey = process.env.INFURA_KEY;
const alchemyKey = process.env.ALCHEMY_KEY;

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (args, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

export default {
  mocha: { timeout: 2000000 },
  networks: {
    localhost: {
      hardfork: "istanbul",
    },
    hardhat: {
      allowUnlimitedContractSize: true,
    },
    mainnet: {
      url: `https://eth-mainnet.alchemyapi.io/${alchemyKey}`,
      accounts: [`0x${privateKey}`],
      gas: 8000000,
      gasPrice: 1000000000, // 1gWei
      timeout: 200000,
    },
    kovan: {
      url: `https://eth-kovan.alchemyapi.io/v2/${alchemyKey}`,
      accounts: [`0x${privateKey}`],
      gas: 8000000,
      gasPrice: 1000000000, // 1gWei
      timeout: 200000,
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${infuraKey}`,
      accounts: [`0x${privateKey}`],
      gas: 8000000,
    },
    heco: {
      url: `https://http-mainnet-node.huobichain.com`,
      accounts: [`0x${privateKey}`],
      gas: 8000000,
      gasPrice: 1000000000,
    },
    bsc_test: {
      url: `https://data-seed-prebsc-2-s1.binance.org:8545/`,
      accounts: [`0x${privateKey}`],
      gas: 8000000,
      gasPrice: 20000000000, // 20gWei
    },
    bsc: {
      url: `https://bsc-dataseed.binance.org/`,
      accounts: [`0x${privateKey}`],
      gas: 8000000,
      gasPrice: 10000000000, // 10gWei
    },
  },
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  // TODO: there is an unexpected case when tries to verify contracts, so do not use it at now!!!
  etherscan: {
    apiKey: process.env.ETHERSCAN_KEY,
  },
  gasReporter: {
    currency: "USD",
    enabled: false,
    coinmarketcap: process.env.COINMARKET_API,
  },
};
