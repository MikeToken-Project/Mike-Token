const { ethers, upgrades } = require("hardhat");
const {verifyContract} = require("./utils");

async function main() {
    // Upgrading
    const usdtPoolFactory = await ethers.getContractFactory("MikeUsdtPool");
    const args = [
        // usdt token
        '0x55d398326f99059fF775485246999027B3197955',
        // mkt token
        '0xf542ac438cf8cd4477a1fc7ab88adda5426d55ed',
        // minimum deposit amount = 100
        '1000000000000000000',
        // open deposit
        '1690030800',
        // close deposit
        '1690138800',
        // open withdraw
        '1690743600',
        // mkt price
        '3800',
        // basis point
        '10000000000000'
    ]
    // const instance = await upgrades.deployProxy(usdtPoolFactory, args, {unsafeAllowLinkedLibraries: true});
    // await instance.deployed();
    // const address = instance.address.toString().toLowerCase();
    const upgraded = await upgrades.upgradeProxy('0xf040dbae4472ab519c0e10619ba4bf3835044d6e', usdtPoolFactory, {unsafeAllowLinkedLibraries: true});
    // console.log(`mkt usdt pool address : ${address}`)
}

main();