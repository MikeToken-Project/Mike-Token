const { ethers, upgrades } = require("hardhat");
const {verifyContract} = require("./utils");

async function main() {
    // Upgrading
    const mikeTreasuryFactory = await ethers.getContractFactory("MikeTreasury");
    const deployTx = await mikeTreasuryFactory.deploy(
        // Token mike
        'token address'
    )
    await deployTx.deployed()
    console.log("Treasury address", deployTx.address)
    await verifyContract(deployTx.address, [
        // Token mike
        'token address'
    ])
}

main();