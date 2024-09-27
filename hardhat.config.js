require("@nomiclabs/hardhat-waffle");
require("dotenv").config(); // Load environment variables

module.exports = {
  solidity: {
    version: "0.8.20", // Update to match the version of OpenZeppelin contracts
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    bscTestnet: {
      url: process.env.BSC_TESTNET_RPC, // BSC Testnet URL
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
  },
};
