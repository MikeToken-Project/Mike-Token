const { ethers, upgrades } = require("hardhat");
const {verifyContract} = require("./utils");

async function main() {
    // Upgrading
    const mikeTokenFactory = await ethers.getContractFactory("MikeToken");
    const deployTx = await mikeTokenFactory.deploy()
    await deployTx.deployed()
    console.log("Mike token address", deployTx.address)
    await verifyContract(deployTx.address, [])
}

main();