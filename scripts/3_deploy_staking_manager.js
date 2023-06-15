const { ethers, upgrades } = require("hardhat");
const {verifyContract} = require("./utils");

async function main() {
    // Upgrading
    const stakingManagerFactory = await ethers.getContractFactory("StakingManager");
    const args = [
        // Mike token
        'token address',
        // Mike treasury
        'treasury address',
        // Start block
        'start block',
        // Mike per block
        'mike per block'
    ]
    const deployTx = await stakingManagerFactory.deploy(
        ...args
    )
    await deployTx.deployed()
    console.log("Staking manager address", deployTx.address)
    await verifyContract(deployTx.address, args)
}

main();