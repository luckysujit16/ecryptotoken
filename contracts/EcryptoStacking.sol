// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol"; // Add this

contract EcryptoStacking is
    Ownable(address(msg.sender)),
    UUPSUpgradeable,
    Initializable
{
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

    event Staked(address indexed user, uint256 amount, uint256 duration);
    event Unstaked(address indexed user, uint256 amount);
    event RewardPaid(address indexed user, uint256 reward);
    event RewardAdded(uint256 amount, uint256 timestamp);

    // Initialization function
    function initialize(
        address _tokenAddress,
        address _feeWallet,
        address _adminWallet,
        address _owner // Pass owner
    ) public initializer {
        token = IERC20(_tokenAddress);
        feeWallet = _feeWallet;
        adminWallet = _adminWallet;
        rewardRates[30] = 2;
        rewardRates[90] = 18;
        rewardRates[180] = 30;
        rewardRates[365] = 50;
        lastUpdateTime = block.timestamp;

        // Transfer ownership
        _transferOwnership(_owner);
    }

    // Ensure the contract is upgradeable
    function _authorizeUpgrade(address) internal override onlyOwner {}

    modifier onlyAdmin() {
        require(msg.sender == adminWallet, "Only admin can call this");
        _;
    }

    // Stake tokens
    function stake(uint256 _amount, uint256 _duration) external {
        require(_amount > 0, "Cannot stake 0");
        require(
            _duration == 30 ||
                _duration == 90 ||
                _duration == 180 ||
                _duration == 365,
            "Invalid duration"
        );

        // Update total staked amounts based on duration
        if (_duration == 30) totalStakedThirty += _amount;
        else if (_duration == 90) totalStakedNinety += _amount;
        else if (_duration == 180) totalStakedOneEighty += _amount;
        else totalStakedThreeSixty += _amount;

        token.transferFrom(msg.sender, address(this), _amount);

        // Add the new stake
        stakes[msg.sender].push(Stake(_amount, block.timestamp, _duration));
        totalStaked += _amount;

        // Add user to the list if they are staking for the first time
        if (stakes[msg.sender].length == 1) {
            stakersList.push(msg.sender);
        }

        emit Staked(msg.sender, _amount, _duration);
    }

    // Unstake tokens based on index
    function unstake(uint256 _index) external {
        require(_index < stakes[msg.sender].length, "Invalid index");

        Stake storage userStake = stakes[msg.sender][_index];
        require(userStake.amount > 0, "Nothing to unstake");

        // Ensure the staking duration is complete
        require(
            block.timestamp >=
                userStake.startTime + (userStake.duration * 10 seconds),
            "Staking period not complete"
        );

        // Update total staked amounts based on duration
        if (userStake.duration == 30) {
            totalStakedThirty -= userStake.amount;
        } else if (userStake.duration == 90) {
            totalStakedNinety -= userStake.amount;
        } else if (userStake.duration == 180) {
            totalStakedOneEighty -= userStake.amount;
        } else {
            totalStakedThreeSixty -= userStake.amount;
        }

        totalStaked -= userStake.amount;

        // Store the unstake amount
        uint256 unstakeAmount = userStake.amount;

        // Remove the stake from the array
        stakes[msg.sender][_index] = stakes[msg.sender][
            stakes[msg.sender].length - 1
        ];
        stakes[msg.sender].pop();

        emit Unstaked(msg.sender, unstakeAmount);

        // Secure token transfer
        bool success = token.transfer(msg.sender, unstakeAmount);
        require(success, "Token transfer failed");
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
        emit RewardPaid(msg.sender, withdrawableReward);

        token.transfer(msg.sender, withdrawableReward);
    }

    function getAllReward(address _staker) public view returns (uint256) {
        Stake[] memory userStakes = stakes[_staker];
        uint256 totalReward = 0;

        for (uint256 j = 0; j < userStakes.length; j++) {
            totalReward += calculateReward(_staker, j);
        }
        return totalReward;
    }

    function calculateReward(
        address _staker,
        uint256 _index
    ) public view returns (uint256) {
        Stake storage userStake = stakes[_staker][_index];
        uint256 daysTotalDurationAmt;
        uint256 rewardRate;

        // Determine the total staked amount based on the duration
        if (userStake.duration == 30) {
            daysTotalDurationAmt = totalStakedThirty;
            rewardRate = rewardRates[30];
        } else if (userStake.duration == 90) {
            daysTotalDurationAmt = totalStakedNinety;
            rewardRate = rewardRates[90];
        } else if (userStake.duration == 180) {
            daysTotalDurationAmt = totalStakedOneEighty;
            rewardRate = rewardRates[180];
        } else if (userStake.duration == 365) {
            daysTotalDurationAmt = totalStakedThreeSixty;
            rewardRate = rewardRates[365];
        } else {
            return 0;
        }

        // Avoid division by zero
        if (daysTotalDurationAmt == 0) {
            return 0;
        }

        // Calculate the user's share percentage in the pool
        uint256 userPoolSharePercent = (userStake.amount * 1e20) /
            daysTotalDurationAmt;

        uint256 totalReward = 0;

        // Iterate over rewards only once, considering rewards after staking started
        for (uint256 i = 1; i <= rewardEntryCount; i++) {
            RewardEntry memory rewardEntry = dailyRewards[i];

            if (rewardEntry.timestamp >= userStake.startTime) {
                // Calculate the user's share of the reward
                uint256 poolShareAmount = (rewardEntry.amount * rewardRate) /
                    100;
                uint256 userShare = (poolShareAmount * userPoolSharePercent) /
                    1e20;
                totalReward += userShare;
            }
        }
        return totalReward;
    }

    // Get users by particular duration
    function getUsersByDuration(
        uint256 _duration
    ) public view returns (address[] memory) {
        require(
            _duration == 30 ||
                _duration == 90 ||
                _duration == 180 ||
                _duration == 365,
            "Invalid duration"
        );

        // Count users with the specified duration
        uint256 count = 0;
        for (uint256 i = 0; i < stakersList.length; i++) {
            address user = stakersList[i];
            Stake[] memory userStakes = stakes[user];
            for (uint256 j = 0; j < userStakes.length; j++) {
                if (userStakes[j].duration == _duration) {
                    count++;
                    break; // Stop after finding the first stake with the given duration
                }
            }
        }

        // Create array to hold filtered users
        address[] memory filteredUsers = new address[](count);
        uint256 index = 0;

        // Populate the filtered users array
        for (uint256 i = 0; i < stakersList.length; i++) {
            address user = stakersList[i];
            Stake[] memory userStakes = stakes[user];
            for (uint256 j = 0; j < userStakes.length; j++) {
                if (userStakes[j].duration == _duration) {
                    filteredUsers[index] = user;
                    index++;
                    break; // Stop after finding the first stake with the given duration
                }
            }
        }

        return filteredUsers;
    }

    // Add daily rewards
    function addDailyReward(uint256 _amount) external onlyAdmin {
        require(_amount > 0  , "Amount must be greater than 0");

        // Record the reward entry
        rewardEntryCount++;
        dailyRewards[rewardEntryCount] = RewardEntry({
            amount: _amount,
            timestamp: block.timestamp
        });

        // Secure token transfer
        bool success = token.transferFrom(msg.sender, address(this), _amount);
        require(success, "Token transfer failed");

        emit RewardAdded(_amount, block.timestamp);
    }

    // Get user stakes
    function getUserStakes(
        address _user
    ) external view returns (Stake[] memory) {
        return stakes[_user];
    }

    function getAllDailyRewards() external view returns (RewardEntry[] memory) {
        RewardEntry[] memory rewards = new RewardEntry[](rewardEntryCount);
        for (uint256 i = 1; i <= rewardEntryCount; i++) {
            rewards[i - 1] = dailyRewards[i];
        }
        return rewards;
    }
}
