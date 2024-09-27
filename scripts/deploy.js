async function main() {
  // Get the contract factory for our eCryptoToken
  const eCryptoToken = await ethers.getContractFactory("eCryptoToken");

  // Deploy the contract
  console.log("Deploying eCryptoToken...");
  const token = await eCryptoToken.deploy();

  // Wait for the contract to be deployed
  await token.deployed();

  // Output the address of the deployed contract
  console.log("eCryptoToken deployed to:", token.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
