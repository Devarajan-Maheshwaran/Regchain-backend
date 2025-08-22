import hre from "hardhat";

async function main() {
  const { ethers } = hre;

  const [deployer] = await ethers.getSigners();
  console.log("Deploying contracts with the account:", deployer.address);

  const RegChain = await ethers.getContractFactory("RegChainAccess");
  const regChain = await RegChain.deploy(deployer.address);

  await regChain.deployed();
  console.log("RegChainAccess deployed to:", regChain.address);
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
