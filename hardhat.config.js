require("@nomiclabs/hardhat-waffle");
require("dotenv").config(); // To load environment variables from a .env file

module.exports = {
  solidity: "0.8.0", // Ensure the Solidity version matches your contracts
  networks: {
    // Tron Nile Testnet Configuration
    tronNile: {
      url: "https://nile.trongrid.io", // Use TronGrid's Nile testnet URL
      accounts: [`0x${process.env.PRIVATE_KEY}`], // Use the deployer's private key (from .env)
    },
  },
  etherscan: {
    apiKey: process.env.TRONSCAN_API_KEY, // Optional: Tronscan API key if you want to verify contracts
  },
};
