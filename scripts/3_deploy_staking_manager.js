const { ethers, upgrades } = require("hardhat");
const {verifyContract} = require("./utils");

async function main() {
    // Upgrading
    const stakingManagerFactory = await ethers.getContractFactory("StakingManager");
    const args = [
        // Mike token
        '0x6C62F8a8deDd262beA9351C9bCAA56ADC558d05D',
        // Mike treasury
        '0x5063A5910784940039C0b48d5cc044893AeCd680',
        // Start block
        '31692119',
        // Mike per block
        '100000000000000000'
    ]
    const deployTx = await stakingManagerFactory.deploy(
        ...args
    )
    await deployTx.deployed()
    console.log("Staking manager address", deployTx.address)
    await verifyContract(deployTx.address, args)
}

main();