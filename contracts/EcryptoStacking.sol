// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

contract EcryptoStacking is Ownable(address(msg.sender)), UUPSUpgradeable, Initializable {
    IERC20 public token;

    struct Stake {
        uint256 amount;
        uint256 startTime;
        uint256 duration;
    }

    struct RewardEntry {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Stake[]) public stakes;
    mapping(uint256 => uint256) public rewardRates;
    mapping(uint256 => RewardEntry) public dailyRewards;
    address public feeWallet;
    address public adminWallet;
    address[] public stakersList;

    uint256 public totalStaked;
    uint256 private lastUpdateTime;
    uint256 public rewardEntryCount;

    uint256 public totalStakedThirty;
    uint256 public totalStakedNinety;
    uint256 public totalStakedOneEighty;
    uint256 public totalStakedThreeSixty;

    mapping(address => uint256) public totalRewardWithdrawan;

    uint256 public constant PRECISION = 1e18;

    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 amount, uint256 timestamp);

    function initialize(
        address _tokenAddress,
        address _feeWallet,
        address _adminWallet,
        address _owner
    ) public initializer {
        token = IERC20(_tokenAddress);
        feeWallet = _feeWallet;
        adminWallet = _adminWallet;
        rewardRates[30] = 2 * PRECISION / 100; // 2% reward rate
        rewardRates[90] = 10 * PRECISION / 100; // 10% reward rate
        rewardRates[180] = 22 * PRECISION / 100; // 22% reward rate
        rewardRates[365] = 50 * PRECISION / 100; // 50% reward rate
        lastUpdateTime = block.timestamp;

        _transferOwnership(_owner);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier onlyAdmin() {
        require(msg.sender == adminWallet, "Only admin can call this");
        _;
    }

    function stake(uint256 _amount, uint256 _duration) external {
        require(_amount > 0, "Cannot stake 0");
        require(
                _duration == 30 ||
                _duration == 90 ||
                _duration == 180 ||
                _duration == 365,
            "Invalid duration"
        );

        if (_duration == 30) totalStakedThirty += _amount;
        else if (_duration == 90) totalStakedNinety += _amount;
        else if (_duration == 180) totalStakedOneEighty += _amount;
        else totalStakedThreeSixty += _amount;

        token.transferFrom(msg.sender, address(this), _amount);

        stakes[msg.sender].push(Stake(_amount, block.timestamp, _duration));
        totalStaked += _amount;

        if (stakes[msg.sender].length == 1) {
            stakersList.push(msg.sender);
        }

        emit Staked(msg.sender, _amount, _duration);
    }

    function unstake(uint256 _index) external {
        require(_index < stakes[msg.sender].length, "Invalid index");

        Stake storage userStake = stakes[msg.sender][_index];
        require(userStake.amount > 0, "Nothing to unstake");

        require(
            block.timestamp >=
                userStake.startTime + (userStake.duration * 1 minutes),
            "Staking period not complete"
        );

        if (userStake.duration == 30) totalStakedThirty -= userStake.amount;
        else if (userStake.duration == 90) totalStakedNinety -= userStake.amount;
        else if (userStake.duration == 180) totalStakedOneEighty -= userStake.amount;
        else totalStakedThreeSixty -= userStake.amount;

        totalStaked -= userStake.amount;

        stakes[msg.sender][_index] = stakes[msg.sender][
            stakes[msg.sender].length - 1
        ];
        stakes[msg.sender].pop();

        token.transfer(msg.sender, userStake.amount);
        emit Unstaked(msg.sender, userStake.amount);
    }

    function withdrawStakingReward() external {
        Stake[] memory userStakes = stakes[msg.sender];
        uint256 totalReward = 0;
        uint256 totalWithdrawn = totalRewardWithdrawan[msg.sender];

        for (uint256 j = 0; j < userStakes.length; j++) {
            totalReward += calculateReward(msg.sender, j);
        }

        require(totalReward > totalWithdrawn, "No reward available");

        uint256 withdrawableReward = totalReward - totalWithdrawn;

        totalRewardWithdrawan[msg.sender] += withdrawableReward;
        token.transfer(msg.sender, withdrawableReward / PRECISION);
        emit RewardPaid(msg.sender, withdrawableReward / PRECISION);
    }

    function calculateReward(
        address _staker,
        uint256 _index
    ) public view returns (uint256) {
        Stake storage userStake = stakes[_staker][_index];
        uint256 daysTotalDurationAmt;

        if (userStake.duration == 30) daysTotalDurationAmt = totalStakedThirty;
        else if (userStake.duration == 90) daysTotalDurationAmt = totalStakedNinety;
        else if (userStake.duration == 180) daysTotalDurationAmt = totalStakedOneEighty;
        else if (userStake.duration == 365) daysTotalDurationAmt = totalStakedThreeSixty;
        else return 0;

        uint256 userPoolSharePercent = (userStake.amount * PRECISION) /
            daysTotalDurationAmt;

        uint256 totalReward = 0;

        for (uint256 i = 1; i <= rewardEntryCount; i++) {
            RewardEntry memory rewardEntry = dailyRewards[i];

            if (rewardEntry.timestamp >= userStake.startTime) {
                uint256 userShare = (rewardEntry.amount *
                    userPoolSharePercent) / PRECISION;
                totalReward += userShare;
            }
        }

        return totalReward;
    }

    function addDailyReward(uint256 _amount) external onlyAdmin {
        require(_amount > 0, "Amount must be greater than 0");

        rewardEntryCount++;
        dailyRewards[rewardEntryCount] = RewardEntry({
            amount: _amount * PRECISION,
            timestamp: block.timestamp
        });

        emit RewardAdded(_amount * PRECISION, block.timestamp);
    }

    function getUserStakes(
        address _user
    ) external view returns (Stake[] memory) {
        return stakes[_user];
    }
}
