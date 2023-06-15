// SPDX-License-Identifier: MIT
pragma solidity ^0.8.6;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/IMikeToken.sol";

contract MikeTreasury is Ownable {
    address public mikeStakingManager;
    IMikeToken public mike;

    uint256 public maxMintAmount = 36_500_000_000_000 * 10 ** 18;
    uint256 public baseMintAmount = 3_000_000_000_000 * 10 ** 18;

    modifier onlyCounterParty() {
        require(mikeStakingManager == msg.sender, "not authorized");
        _;
    }

    constructor(IMikeToken _mike) {
        mike = _mike;
    }

    function myBalance() public view returns (uint256) {
        return mike.balanceOf(address(this));
    }

    function mint(address recipient, uint256 amount) public onlyCounterParty {
        mike.transfer(recipient, amount);
    }

    function setMikeStakingManager(address _newAddress) public onlyOwner {
        mikeStakingManager = _newAddress;
    }

    function setMike(IMikeToken _newMike) public onlyOwner {
        mike = _newMike;
    }

    function setMaxMintAmount(uint256 amount) public onlyOwner {
        maxMintAmount = amount;
    }
}
