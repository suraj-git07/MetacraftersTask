// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
const hre = require("hardhat");

async function main() {
  const [owner, funder, creator] = await hre.ethers.getSigners();

  const fundToken = await hre.ethers.getContractFactory("FundToken");
  const fundTokenContract = await fundToken.deploy();

  console.log("Address of FundToken:", fundTokenContract.address);

  const metaTask = await hre.ethers.getContractFactory("CrowdFunding");
  const metaTaskContract = await metaTask.deploy(
    fundTokenContract.address,
    100
  );

  console.log("Address of MetaTask:", metaTaskContract.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
