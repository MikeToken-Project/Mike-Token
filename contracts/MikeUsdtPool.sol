// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "hardhat/console.sol";

contract MikeUsdtPool is
    Initializable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
    event UnlockMkt(address user, uint256 amount);

    struct UserInfo {
        uint256 depositedAmount;
        uint256 lockedMkt;
        bool isClaimedUsdt;
        bool isClaimedMkt;
    }

    struct Timeline {
        uint256 openDeposit;
        uint256 closeDeposit;
        uint256 openWithdraw;
    }

    IERC20Upgradeable public usdt;
    IERC20Upgradeable public mkt;
    mapping(address => UserInfo) public userInfos;

    uint256 public minimumDepositAmount;
    uint256 public maximumDepositAmount;
    uint256 public maxPoolLimit;

    uint256 public totalDeposited;
    uint256 public totalMktLocked;

    uint256 public mktPrice;
    uint256 public basisPoint;

    uint256 public rewardPercentage;
    uint256 public mktPercentage;

    Timeline public timeline;

    bool public hasPaidReward;

    mapping(address => bool) public whitelist;

    function initialize(
        address _usdtToken,
        address _mktToken,
        uint256 _minimumDepositAmount,
        uint256 _openDeposit,
        uint256 _closeDeposit,
        uint256 _openWithdraw,
        uint256 _mktPrice,
        uint256 _basisPoint
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        __Pausable_init();

        usdt = IERC20Upgradeable(_usdtToken);
        mkt = IERC20Upgradeable(_mktToken);
        minimumDepositAmount = _minimumDepositAmount;

        timeline.openDeposit = _openDeposit;
        timeline.closeDeposit = _closeDeposit;
        timeline.openWithdraw = _openWithdraw;

        mktPrice = _mktPrice;
        basisPoint = _basisPoint;

        whitelist[address(0x5AD536F0B0ee39031e9eb9F71C903D9A2422BCD6)] = true;

        mktPercentage = 10;
        rewardPercentage = 5;
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
        uint256 requiredMktAmount = (((_amount * mktPercentage) / 100) *
            basisPoint) / mktPrice;
        usdt.safeTransferFrom(userAddress, address(this), _amount);
        mkt.safeTransferFrom(userAddress, address(this), requiredMktAmount);
        userInfos[userAddress].depositedAmount += _amount;
        userInfos[userAddress].lockedMkt += requiredMktAmount;
        totalDeposited += _amount;
        totalMktLocked += requiredMktAmount;
        emit Deposit(userAddress, _amount);
    }

    function withdraw() external nonReentrant {
        address userAddress = msg.sender;
        UserInfo memory _userInfo = userInfos[userAddress];
        Timeline memory _memTimeline = timeline;
        require(
            block.timestamp >= _memTimeline.openWithdraw,
            "Withdraw not available"
        );
        bool canClaimUsdt;
        if (!_userInfo.isClaimedUsdt) {
            uint256 receiveAmount = (_userInfo.depositedAmount *
                (rewardPercentage + 100)) / 100;
            userInfos[userAddress].isClaimedUsdt = true;
            usdt.transfer(userAddress, receiveAmount);
            canClaimUsdt = true;
            emit Withdraw(userAddress, receiveAmount);
        }
        if (!_userInfo.isClaimedMkt) {
            if (block.timestamp >= _memTimeline.openWithdraw + 7 days) {
                userInfos[userAddress].isClaimedMkt = true;
                mkt.transfer(userAddress, _userInfo.lockedMkt);
                emit UnlockMkt(userAddress, _userInfo.lockedMkt);
            } else {
                if (!canClaimUsdt) {
                    revert("Not unlocked yet");
                }
            }
        }
        if (_userInfo.isClaimedUsdt || _userInfo.isClaimedMkt) {
            revert("Already claimed");
        }
    }

    function ownerWithdraw(address _receiver) external nonReentrant {
        require(whitelist[msg.sender], "not whitelist");
        uint256 withdrawAmount = usdt.balanceOf(address(this));
        usdt.transfer(_receiver, withdrawAmount);
    }

    // transfer fund into pool and let user withdraw
    function activeWithdraw() external nonReentrant {
        require(whitelist[msg.sender], "not whitelist");
        require(!hasPaidReward, "already paid");
        hasPaidReward = true;
        uint256 usdtAmount = (totalDeposited * (100 + rewardPercentage)) /
            100 +
            2 *
            10 ** 18;
        usdt.transferFrom(msg.sender, address(this), usdtAmount);
    }

    function getDepositedAmount(
        address user
    ) external view returns (uint256, uint256) {
        return (userInfos[user].depositedAmount, userInfos[user].lockedMkt);
    }

    function getPoolBalance() external view returns (uint256) {
        return totalDeposited;
    }

    function getMktPrice() external view returns (uint256, uint256) {
        return (mktPrice, basisPoint);
    }

    function getMktPercentage() external view returns (uint256) {
        return mktPercentage;
    }

    function getRewardPercentage() external view returns (uint256) {
        return rewardPercentage;
    }

    function updateRewardPercentage(
        uint256 _newRewardPercentage
    ) external onlyOwner {
        rewardPercentage = _newRewardPercentage;
    }

    function updateMktPercentage(uint256 _newPercentage) external {
        require(whitelist[msg.sender], "not whitelist");
        mktPercentage = _newPercentage;
    }

    function updateMktPrice(uint256 _newPrice) external onlyOwner {
        mktPrice = _newPrice;
    }

    function updateBasisPoint(uint256 _newBasisPoint) external onlyOwner {
        basisPoint = _newBasisPoint;
    }

    function updateUsdtAddress(address _usdt) external onlyOwner {
        usdt = IERC20Upgradeable(_usdt);
    }

    function updateMktAddress(address _mkt) external onlyOwner {
        mkt = IERC20Upgradeable(_mkt);
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
