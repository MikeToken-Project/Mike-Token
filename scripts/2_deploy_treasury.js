const { ethers, upgrades } = require("hardhat");
const {verifyContract} = require("./utils");

async function main() {
    // Upgrading
    const mikeTreasuryFactory = await ethers.getContractFactory("MikeTreasury");
    const deployTx = await mikeTreasuryFactory.deploy(
        // Token mike
        '0x6C62F8a8deDd262beA9351C9bCAA56ADC558d05D'
    )
    await deployTx.deployed()
    console.log("Treasury address", deployTx.address)
    await verifyContract(deployTx.address, [
        // Token mike
        '0x6C62F8a8deDd262beA9351C9bCAA56ADC558d05D'
    ])
}

main();