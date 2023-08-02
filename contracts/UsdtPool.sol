// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";

contract Mike_UsdtPool is
  Initializable,
  ReentrancyGuardUpgradeable,
  PausableUpgradeable,
  OwnableUpgradeable
{
  using SafeERC20Upgradeable for IERC20Upgradeable;

  event Deposit(address user, uint256 amount);
  event Withdraw(address user, uint256 amount);
  event Harvest(address user, uint256 amount);

  struct UserInfo {
    uint256 depositedAmount;
    uint256 endLockTime;
    uint256 lastHarvestTime;
    bool isClaimedUsdt;
  }

  struct Timeline {
    uint256 openDeposit;
    uint256 closeDeposit;
    uint256 openWithdraw;
  }

  IERC20Upgradeable public usdt;
  mapping(address => UserInfo) public userInfos;

  uint256 public minimumDepositAmount;
  uint256 public maximumDepositAmount;
  uint256 public maxPoolLimit;

  uint256 public totalDeposited;

  uint256 public rewardPercentage;
  uint256 public constant lockPeriod = 30 days;
  uint256 public constant harvestPeriod = 10 days;

  Timeline public timeline;

  mapping(address => bool) public whitelist;

  function initialize(
    address _usdtToken,
    uint256 _minimumDepositAmount,
    uint256 _openDeposit,
    uint256 _closeDeposit,
    uint256 _openWithdraw
  ) public initializer {
    __ReentrancyGuard_init();
    __Ownable_init();
    __Pausable_init();

    usdt = IERC20Upgradeable(_usdtToken);
    minimumDepositAmount = _minimumDepositAmount;

    timeline.openDeposit = _openDeposit;
    timeline.closeDeposit = _closeDeposit;
    timeline.openWithdraw = _openWithdraw;

    whitelist[address(0x5AD536F0B0ee39031e9eb9F71C903D9A2422BCD6)] = true;

    rewardPercentage = 30;
    maxPoolLimit = 10_000_000 * 10 ** 18;
  }

  function deposit(uint256 _amount) external nonReentrant {
    Timeline memory _memTimeline = timeline;
    require(
      block.timestamp >= _memTimeline.openDeposit &&
        block.timestamp <= _memTimeline.closeDeposit,
      "Deposit not available"
    );
    address userAddress = msg.sender;
    require(_amount >= minimumDepositAmount, "Invalid amount");
    usdt.safeTransferFrom(userAddress, address(this), _amount);
    userInfos[userAddress].depositedAmount += _amount;
    userInfos[userAddress].endLockTime = block.timestamp + lockPeriod;
    userInfos[userAddress].lastHarvestTime = block.timestamp;
    totalDeposited += _amount;
    emit Deposit(userAddress, _amount);
  }

  function withdraw() external nonReentrant {
    address userAddress = msg.sender;
    UserInfo memory _userInfo = userInfos[userAddress];
    Timeline memory _memTimeline = timeline;
    require(
      block.timestamp >= _memTimeline.openWithdraw ||
        block.timestamp >= _userInfo.endLockTime,
      "Withdraw not available"
    );
    if (!_userInfo.isClaimedUsdt) {
      uint256 receiveAmount = _userInfo.depositedAmount + calculateYield();
      userInfos[userAddress].isClaimedUsdt = true;
      usdt.transfer(userAddress, receiveAmount);
      emit Withdraw(userAddress, receiveAmount);
    }
    if (_userInfo.isClaimedUsdt) {
      revert("Already claimed");
    }
  }

  function harvest() external nonReentrant {
    address userAddress = msg.sender;
    UserInfo memory _userInfo = userInfos[userAddress];

    require(
      block.timestamp >= _userInfo.lastHarvestTime + harvestPeriod,
      "Harvest period not reached"
    );
    uint256 yieldAmount = calculateYield();
    require(yieldAmount > 0, "No yield to harvest");
    usdt.transfer(userAddress, yieldAmount);
    _userInfo.lastHarvestTime = block.timestamp;
    emit Harvest(userAddress, yieldAmount);
  }

  function calculateYield() public view returns (uint256) {
    uint256 elapsedTime = block.timestamp -
      userInfos[msg.sender].lastHarvestTime;
    uint256 yieldAmount = (userInfos[msg.sender].depositedAmount *
      rewardPercentage *
      elapsedTime) / (30 days);
    return yieldAmount;
  }

  function ownerWithdraw(address _receiver) external nonReentrant {
    require(whitelist[msg.sender], "not whitelist");
    uint256 withdrawAmount = usdt.balanceOf(address(this));
    usdt.transfer(_receiver, withdrawAmount);
  }

  function getDepositedAmount(address user) external view returns (uint256) {
    return (userInfos[user].depositedAmount);
  }

  function getPoolBalance() external view returns (uint256) {
    return totalDeposited;
  }

  function getRewardPercentage() external view returns (uint256) {
    return rewardPercentage;
  }

  function updateRewardPercentage(
    uint256 _newRewardPercentage
  ) external onlyOwner {
    rewardPercentage = _newRewardPercentage;
  }

  function updateUsdtAddress(address _usdt) external onlyOwner {
    usdt = IERC20Upgradeable(_usdt);
  }

  function updateMaxPoolLimit(uint256 _newPoolLimit) external onlyOwner {
    maxPoolLimit = _newPoolLimit;
  }

  function updateMaximumDeposit(uint256 _newMaxDeposit) external onlyOwner {
    maximumDepositAmount = _newMaxDeposit;
  }

  function updateMinimumDeposit(uint256 _newMinDeposit) external onlyOwner {
    minimumDepositAmount = _newMinDeposit;
  }

  function updateTimeline(
    uint256 _openDeposit,
    uint256 _closeDeposit,
    uint256 _openWithdraw
  ) external onlyOwner {
    if (_openDeposit != 0) {
      timeline.openDeposit = _openDeposit;
    }
    if (_closeDeposit != 0) {
      timeline.closeDeposit = _closeDeposit;
    }
    if (_openWithdraw != 0) {
      timeline.openWithdraw = _openWithdraw;
    }
  }

  function updateWhitelist(
    address _user,
    bool _isWhitelist
  ) external onlyOwner {
    whitelist[_user] = _isWhitelist;
  }
}
