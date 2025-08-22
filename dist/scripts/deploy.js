"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
const hardhat_1 = require("hardhat");
async function main() {
    const [deployer] = await hardhat_1.ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);
    const RegChain = await hardhat_1.ethers.getContractFactory("RegChainAccess");
    const regChain = await RegChain.deploy(deployer.address); // pass admin wallet here
    await regChain.deployed();
    console.log("RegChainAccess deployed to:", regChain.address);
}
main()
    .then(() => process.exit(0))
    .catch((error) => {
    console.error(error);
    process.exit(1);
});
