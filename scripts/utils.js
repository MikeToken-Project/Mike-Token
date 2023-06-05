const hre = require("hardhat");

 async function verifyContract(address, args, contract ) {
    const verifyObj = {address}
    if(args){
        verifyObj.constructorArguments = args
    }
    if(contract){
        verifyObj.contract = contract;
    }
    console.log("verifyObj", verifyObj)
    return hre
        .run("verify:verify", verifyObj)
        .then(() =>
            console.log(
                "Contract address verified:",
                address
            )
        );
}

module.exports = {
     verifyContract: verifyContract
}