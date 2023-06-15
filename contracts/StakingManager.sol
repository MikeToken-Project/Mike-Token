// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IMikeToken.sol";

interface IMikeTreasury {
    function mint(address recipient, uint256 amount) external;
}

contract StakingManager is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        //
        // We do some fancy math here. Basically, any point in time, the amount of Mike Token
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accMikePerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accMikePerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken; // Address of LP token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool. Mikes to distribute per block.
        uint256 lastRewardBlock; // Last block number that Mikes distribution occurs.
        uint256 accMikePerShare; // Accumulated Mikes per share, times 1e12. See below.
        uint128 withdrawFeeBP; // Withdraw fee in basis points 10000
        uint128 harvestFeeBP; // Harvest fee in basis points 10000
    }

    // The Mike TOKEN!
    IMikeToken public mike;
    IMikeTreasury public mikeTreasury;
    // Dev address.
    address public devAddress;
    // Deposit Fee address
    address public feeAddress;
    // Mike tokens created per block.
    uint256 public mikePerBlock;
    // Bonus multiplier for early mike makers.
    uint256 public BONUS_MULTIPLIER = 1;
    // Max harvest interval: 14 days.
    uint256 public MAXIMUM_HARVEST_INTERVAL = 14 days;
    // TODO config max allocation
    uint256 public MAX_STAKING_ALLOCATION;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when MKT mining starts.
    uint256 public startBlock;
    // Total locked up rewards
    uint256 public totalLockedUpRewards;

    uint256 public stakingMinted;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event Harvest(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(
        address indexed user,
        uint256 indexed pid,
        uint256 amount
    );
    event EmissionRateUpdated(
        address indexed caller,
        uint256 previousAmount,
        uint256 newAmount
    );
    event ReferralCommissionPaid(
        address indexed user,
        address indexed referrer,
        uint256 commissionAmount
    );
    event RewardLockedUp(
        address indexed user,
        uint256 indexed pid,
        uint256 amountLockedUp
    );

    constructor(
        IMikeToken _mike,
        IMikeTreasury _mikeTreasury,
        uint256 _startBlock,
        uint256 _mikePerBlock
    ) {
        mike = _mike;
        mikeTreasury = _mikeTreasury;
        startBlock = _startBlock;
        mikePerBlock = _mikePerBlock;

        devAddress = msg.sender;
        // marketing wallet
        feeAddress = 0xC94DbFcd4dcdE2815aA0346f21A47c12c50bD14d;
    }

    function updateMultiplier(uint256 multiplierNumber) public onlyOwner {
        BONUS_MULTIPLIER = multiplierNumber;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _lpToken,
        uint128 _withdrawFeeBP,
        uint128 _harvestFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        require(
            _withdrawFeeBP <= 10000,
            "add: invalid withdraw fee basis points"
        );
        require(
            _harvestFeeBP <= 10000,
            "add: invalid harvest fee basis points"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accMikePerShare: 0,
                withdrawFeeBP: _withdrawFeeBP,
                harvestFeeBP: _harvestFeeBP
            })
        );
    }

    // Update the given pool's Mike allocation point and withdraw, harvest fee. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        uint128 _withdrawFeeBP,
        uint128 _harvestFeeBP,
        bool _withUpdate
    ) public onlyOwner {
        require(
            _withdrawFeeBP <= 10000,
            "set: invalid withdraw fee basis points"
        );
        require(
            _harvestFeeBP <= 10000,
            "set: invalid harvest fee basis points"
        );
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].withdrawFeeBP = _withdrawFeeBP;
        poolInfo[_pid].harvestFeeBP = _harvestFeeBP;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(
        uint256 _from,
        uint256 _to
    ) public view returns (uint256) {
        return _to.sub(_from).mul(BONUS_MULTIPLIER);
    }

    // View function to see pending Mikes on frontend.
    function pendingMike(
        uint256 _pid,
        address _user
    ) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accMikePerShare = pool.accMikePerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(
                pool.lastRewardBlock,
                block.number
            );
            uint256 mikeReward = multiplier
                .mul(mikePerBlock)
                .mul(pool.allocPoint)
                .div(totalAllocPoint);
            accMikePerShare = accMikePerShare.add(
                mikeReward.mul(1e12).div(lpSupply)
            );
        }
        uint256 pending = user.amount.mul(accMikePerShare).div(1e12).sub(
            user.rewardDebt
        );
        return pending;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0 || pool.allocPoint == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 mikeReward = multiplier
            .mul(mikePerBlock)
            .mul(pool.allocPoint)
            .div(totalAllocPoint);

        stakingMinted = stakingMinted.add(
            mikeReward.add(mikeReward.div(10))
        );
        mikeTreasury.mint(address(this), mikeReward);
        pool.accMikePerShare = pool.accMikePerShare.add(
            mikeReward.mul(1e12).div(lpSupply)
        );
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MikeStakingManager for Mike allocation.
    function deposit(
        uint256 _pid,
        uint256 _amount
    ) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount >0) {
            uint256 pending = user.amount.mul(pool.accMikePerShare).div(1e12).sub(user.rewardDebt);
            if (pending > 0) {
                uint256 harvestFee = pending.mul(pool.harvestFeeBP).div(10000);
                safeMikeTransfer(feeAddress, harvestFee);
                safeMikeTransfer(msg.sender, pending.sub(harvestFee));
            }
        }
        if (_amount > 0) {
            pool.lpToken.transferFrom(
                address(msg.sender),
                address(this),
                _amount
            );
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accMikePerShare).div(1e12);
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MikeStakingManager.
    function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accMikePerShare).div(1e12).sub(user.rewardDebt);
        if (pending > 0) {
            uint256 harvestFee = pending.mul(pool.harvestFeeBP).div(10000);
            safeMikeTransfer(feeAddress, harvestFee);
            safeMikeTransfer(msg.sender, pending.sub(harvestFee));
        }
        if (_amount > 0) {
            user.amount = user.amount.sub(_amount);
            uint256 withdrawFee = _amount.mul(pool.withdrawFeeBP).div(10000);
            pool.lpToken.safeTransfer(feeAddress, withdrawFee);
            pool.lpToken.safeTransfer(address(msg.sender), _amount.sub(withdrawFee));
        }
        user.rewardDebt = user.amount.mul(pool.accMikePerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        uint256 amount = user.amount;
        user.amount = 0;
        user.rewardDebt = 0;
        pool.lpToken.safeTransfer(address(msg.sender), amount);
        emit EmergencyWithdraw(msg.sender, _pid, amount);
    }

    // Safe mike transfer function, just in case if rounding error causes pool to not have enough Mikes.
    function safeMikeTransfer(address _to, uint256 _amount) internal {
        uint256 mikeBal = mike.balanceOf(address(this));
        if (_amount > mikeBal) {
            mikeTreasury.mint(address(this), _amount);
            mike.transfer(_to, _amount);
        } else {
            mike.transfer(_to, _amount);
        }
    }

    // Update dev address by the previous dev.
    function setDevAddress(address _devAddress) public {
        require(msg.sender == devAddress, "setDevAddress: FORBIDDEN");
        require(_devAddress != address(0), "setDevAddress: ZERO");
        devAddress = _devAddress;
    }

    function setFeeAddress(address _feeAddress) public {
        require(msg.sender == feeAddress, "setFeeAddress: FORBIDDEN");
        require(_feeAddress != address(0), "setFeeAddress: ZERO");
        feeAddress = _feeAddress;
    }

    // Pancake has to add hidden dummy pools in order to alter the emission, here we make it simple and transparent to all.
    function updateEmissionRate(uint256 _mikePerBlock) public onlyOwner {
        massUpdatePools();
        emit EmissionRateUpdated(
            msg.sender,
            mikePerBlock,
            _mikePerBlock
        );
        mikePerBlock = _mikePerBlock;
    }
}
