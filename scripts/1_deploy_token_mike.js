const { ethers, upgrades } = require("hardhat");
const {verifyContract} = require("./utils");

async function main() {
    // Upgrading
    const bep20Mintable = await ethers.getContractFactory("MikeToken");
    const deployTx = await bep20Mintable.deploy()
    await deployTx.deployed()
    console.log("Mike token address", deployTx.address)
    await verifyContract(deployTx.address, [])
}

main();