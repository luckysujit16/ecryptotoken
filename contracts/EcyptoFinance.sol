// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IEcryptoToken {
    function mint(address to, uint256 amount) external;

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);
}

contract EcyptoFinance {
    using SafeERC20 for IERC20;

    IERC20 public usdtToken;
    IEcryptoToken public ecryptoToken;
    address public owner;

    // Addresses for various payments
    address public liquidityAddress;
    address public marketingAddress;
    address public promoAddress;
    address public adminAddress;
    address public emergencyAddress;
    address public liquidityPoolAddress;
    address public stakingAddress;
    address public feesAddress;

    address public tokenAddress;

    uint256 public directReferralPer = 5; // One Time
    uint256 public referralLevelPer = 1e18; // monthly

    uint256 public initialTokenRate = 5;

    uint256 public minimumDeposit = 5; // In USDT
    uint256 public minimumWithdrawal = 5; // In USDT
    uint256 public precision = 1e18; // In Wie

    uint256 public withdrawalFees = 5e18;

    uint256 public liquiditySharePercent = 50;
    uint256 public marketingSharePercent = 10;
    uint256 public promoSharePercent = 5;
    uint256 public adminSharePercent = 5;
    uint256 public emergencySharePercent = 10;
    uint256 public contractSharePercent = 20;

    uint256 public maxLevels = 10;

    struct User {
        address user;
        address referrer;
        uint256 balance;
        uint256 referralBal;
        uint256 directBal;
        uint256 totalWithdrawal;
        uint256 withdrawalInToken;
        uint256 withdrawalInUSDT;
        bool isActive;
        uint256 createdOn;
        address[] referrals;
    }

    struct Deposit {
        uint256 amount;
        uint256 timestamp;
    }
    struct Withdrawal {
        uint256 amount;
        uint256 timestamp;
        uint256 withType;
    }

    mapping(address => User) public users;
    mapping(address => Deposit[]) public deposits;
    mapping(address => Withdrawal[]) public withdrawals;
    address[] public userAddresses;
    mapping(address => uint256) public investments;

    event Invested(address indexed user, uint256 amount);
    event Mined(address indexed user, uint256 amount);
    event Withdra(address indexed user, uint256 amount, uint256 withType);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _tokenAddress,
        address _usdtTokenAddress,
        address _liquidityAddress,
        address _marketingAddress,
        address _promoAddress,
        address _adminAddress,
        address _emergencyAddress,
        address _liquidityPoolAddress,
        address _stakingAddress,
        address _feesAddress
    ) {
        ecryptoToken = IEcryptoToken(_tokenAddress);
        usdtToken = IERC20(_usdtTokenAddress);
        owner = msg.sender;

        liquidityAddress = _liquidityAddress;
        marketingAddress = _marketingAddress;
        promoAddress = _promoAddress;
        adminAddress = _adminAddress;
        emergencyAddress = _emergencyAddress;
        liquidityPoolAddress = _liquidityPoolAddress;
        tokenAddress = _tokenAddress;
        stakingAddress = _stakingAddress;
        feesAddress = _feesAddress;

        // Initialize the owner as the first user
        users[owner] = User({
            user: owner,
            referrer: address(0),
            balance: 0,
            referralBal: 0,
            directBal: 0,
            totalWithdrawal: 0,
            withdrawalInToken: 0,
            withdrawalInUSDT: 0,
            isActive: true,
            createdOn: block.timestamp,
            referrals: new address[](0)
        });
        userAddresses.push(owner);
    }

    function invest(uint256 amount, address referrer) external {
        require(
            amount >= minimumDeposit * precision,
            "Deposit must be greater than or equal to 5 USDT"
        );
        // Register the user if not already registered
        if (users[msg.sender].user == address(0)) {
            require(
                referrer != address(0) &&
                    users[referrer].user != address(0) &&
                    referrer != msg.sender,
                "Invalid referrer"
            );

            users[msg.sender] = User({
                user: msg.sender,
                referrer: referrer,
                balance: 0,
                referralBal: 0,
                directBal: 0,
                totalWithdrawal: 0,
                withdrawalInToken: 0,
                withdrawalInUSDT: 0,
                isActive: true,
                createdOn: block.timestamp,
                referrals: new address[](0)
            });

            userAddresses.push(msg.sender);

            users[referrer].referrals.push(msg.sender);
        }
        // Add deposit details with timestamp
        deposits[msg.sender].push(
            Deposit({amount: amount, timestamp: block.timestamp})
        );
        // Pre-calculate the amount percentages to save gas
        uint256 liquidityShare = (amount * liquiditySharePercent) / 100;
        uint256 marketingShare = (amount * marketingSharePercent) / 100;
        uint256 promoShare = (amount * promoSharePercent) / 100;
        uint256 adminShare = (amount * adminSharePercent) / 100;
        uint256 emergencyShare = (amount * emergencySharePercent) / 100;
        uint256 tokenLiquidityShare = (amount / calculateLiveRate()) *
            precision;
        uint256 contractShare = (amount * contractSharePercent) / 100;

        // Transfer USDT to respective addresses
        transferUsd(liquidityAddress, liquidityShare);
        transferUsd(marketingAddress, marketingShare);
        transferUsd(promoAddress, promoShare);
        transferUsd(adminAddress, adminShare);
        transferUsd(emergencyAddress, emergencyShare);
        transferUsd(address(this), contractShare);

        // Mint tokens as a reward to the liquidity pool
        mintToken(liquidityAddress, tokenLiquidityShare);
        users[users[msg.sender].referrer].directBal +=
            (amount * directReferralPer) /
            100;
        investments[msg.sender] += amount;

        emit Invested(msg.sender, amount);
    }

    function calculateReferralIncomeForTree(address user)
        public
        view
        returns (uint256 totalReferralIncome)
    {
        require(users[user].user != address(0), "User does not exist");

        // Start the recursion from the root user (initial user) at level 1
        totalReferralIncome = calculateIncomeFromChildDeposits(user, 1);
    }

    function calculateIncomeFromChildDeposits(
        address currentUser,
        uint256 level
    ) internal view returns (uint256) {
        // Check if user is valid and level is within the allowed limit
        if (currentUser == address(0) || level > maxLevels) {
            return 0;
        }

        uint256 totalChildIncome = 0;
        uint256 dailyPercentage = 32876712320000000; // Adjusted daily percentage (scaled)

        // Retrieve direct referrals of the current user
        address[] storage directReferrals = users[currentUser].referrals;

        // Loop through each direct referral to calculate income from their deposits
        for (uint256 i = 0; i < directReferrals.length; i++) {
            address referral = directReferrals[i];

            // Retrieve deposits of the referral
            Deposit[] storage referralDeposits = deposits[referral];

            // Calculate daily income from each deposit made by this referral
            for (uint256 j = 0; j < referralDeposits.length; j++) {
                Deposit storage deposit = referralDeposits[j];
                uint256 daysPassed = calculateDaysSince(deposit.timestamp);

                // Calculate income for active days of this deposit
                uint256 dailyIncome = (deposit.amount * dailyPercentage) / 1e20;

                // Add income based on days this deposit has been active
                totalChildIncome += dailyIncome * daysPassed;
            }

            // Recursively calculate income from indirect referrals of this referral
            totalChildIncome += calculateIncomeFromChildDeposits(
                referral,
                level + 1
            );
        }
        return totalChildIncome;
    }

    // Function to determine the business level based on the total business volume
    function getBusinessLevel() public pure returns (uint256 level) {
        return 10;
    }

    function calculateGrowth(address user) public view returns (uint256) {
        Deposit[] storage userDeposits = deposits[user];
        require(userDeposits.length > 0, "No deposits for this user");

        uint256 totalGrowth = 0;
        uint256 growthPer = getGrowthPer(investments[user]);

        for (uint256 i = 0; i < userDeposits.length; i++) {
            Deposit storage deposit = userDeposits[i];

            // Calculate the number of days since this deposit
            uint256 daysPassed = calculateDaysSince(deposit.timestamp);

            // Calculate per day income for this deposit
            uint256 perDayIncome = (deposit.amount * growthPer) / 100e18;

            // Add to total growth based on days passed
            totalGrowth += perDayIncome * daysPassed;
        }

        return totalGrowth;
    }

    function calculateDaysSince(uint256 timestamp)
        public
        view
        returns (uint256)
    {
        if (block.timestamp > timestamp) {
            return (block.timestamp - timestamp) / 10 minutes;
        } else {
            return 0;
        }
    }

    function getGrowthPer(uint256 investedAmount)
        internal
        pure
        returns (uint256)
    {
        if (investedAmount >= 5000 * 10**18) {
            return 131506849315068500;
        } else if (investedAmount >= 1000 * 10**18) {
            return 197260273972602700;
        } else if (investedAmount >= 500 * 10**18) {
            return 164383561643835600;
        } else if (investedAmount >= 5 * 10**18) {
            return 131506849315068500;
        } else {
            return 0; // No growth rate for amounts less than 5e18
        }
    }

    function transferUsd(address recipient, uint256 amount) internal {
        usdtToken.safeTransferFrom(msg.sender, recipient, amount);
    }

    function mintToken(address recipient, uint256 amount) internal {
        ecryptoToken.mint(recipient, amount);
        emit Mined(recipient, amount);
    }

    function getUserDeposits(address user)
        external
        view
        returns (Deposit[] memory)
    {
        return deposits[user];
    }

     function getUserWithdrawals(address user)
        external
        view
        returns (Withdrawal[] memory)
    {
        return withdrawals[user];
    }

    // Function to get all users' addresses
    function getUsers() external view returns (address[] memory) {
        return userAddresses;
    }

    function getStakingBalance(uint256 rate) public view returns (uint256) {
        uint256 ecryptoTokenStakingBal = ecryptoToken.balanceOf(stakingAddress);
        return ecryptoTokenStakingBal * rate;
    }

   function calculateLiveRate() public view returns (uint256) {
        uint256 ecryptoTokenBal = ecryptoToken.balanceOf(tokenAddress);
        uint256 liquidityTokenBalance = ecryptoToken.balanceOf(
            liquidityAddress
        );
        uint256 stakedTokenBalance = ecryptoToken.balanceOf(stakingAddress);
        uint256 baseRate = initialTokenRate * (10 ** 18);
       
 
        // Calculate total supply held by users
        uint256 totalSupply = ecryptoToken.totalSupply();
        uint256 totalSupplyOfUser = totalSupply -
            (ecryptoTokenBal + liquidityTokenBalance + stakedTokenBalance);
 
        // If no tokens are held by users, return the base rate
        if (totalSupplyOfUser == 0) {
            return baseRate;
        }
 
        // Calculate total USDT held in liquidity, emergency, and contract addresses
        uint256 totalUSDT = usdtToken.balanceOf(liquidityPoolAddress) +
            usdtToken.balanceOf(emergencyAddress) +
            usdtToken.balanceOf(address(this));
 
        // Calculate an initial rate based on current totalUSDT and user-held supply
        uint256 rate = (totalUSDT * precision) / totalSupplyOfUser;
 
        // Calculate the staking portion with this live rate
        uint256 stakingUsdBalance = (stakedTokenBalance * rate) / precision;
        uint256 adjustedTotalUSDT = totalUSDT + stakingUsdBalance;
 
        // Recalculate the final rate with the updated total USDT
        uint256 finalRate = (adjustedTotalUSDT * precision) / totalSupplyOfUser;
 
        // Return the greater of the calculated rate or baseRate
        return finalRate >= baseRate ? finalRate : baseRate;
    }

    function withdraw(uint256 amount, uint256 withType) external {
        require(withType == 1 || withType == 2, "Invalid withdrawal type");
        require(amount >= minimumWithdrawal, "Minimum withdrawal amount is 5");

        // Check if the user (msg.sender) is registered
        require(investments[msg.sender] > 0, "User is not registered");

        // Calculate total available balance for withdrawal
        uint256 totalUsd = calculateTotalUsd(msg.sender);

        require(totalUsd >= amount, "Insufficient withdrawal amount");

        // Ensure total withdrawals don't exceed 3x the user's investment
        require(
            users[msg.sender].totalWithdrawal + amount <=
                investments[msg.sender] * 3,
            "Withdrawal amount exceeds 3x of your investment"
        );

        // Process withdrawal based on type
        _processWithdrawal(msg.sender, amount, withType);
    }

    function calculateTotalUsd(address user) internal view returns (uint256) {
        uint256 growthUsd = calculateGrowth(user);
        uint256 referralUsd = calculateReferralIncomeForTree(user);
        uint256 directReferralUsd = users[user].directBal;
        uint256 balance = users[user].balance;
        return
            growthUsd +
            referralUsd +
            directReferralUsd +
            balance -
            users[user].totalWithdrawal;
    }

    function _processWithdrawal(
        address user,
        uint256 amount,
        uint256 withType
    ) internal {
        uint256 feeUsd = (amount * withdrawalFees) / 100e18;
        uint256 netAmount = amount - feeUsd;
 
        // Calculate fee and net amount in tokens
        uint256 liveRate = calculateLiveRate();
        uint256 feeTokens = (feeUsd * precision) / liveRate;
        // uint256 netTokens = (netAmount * precision) / liveRate;
 
        // Ensure minimum fee in tokens
        if (feeUsd < precision) {
            feeTokens = (1 * precision) / liveRate;
            netAmount = amount - 1e18;
        }
 
        if (withType == 1) {
            // USDT withdrawal
            usdtToken.safeTransfer(user, netAmount);
        } else if (withType == 2) {
            // Token withdrawal
            mintToken(user, (amount / liveRate) - feeTokens);
        }
 
        // Mint tokens for the fee
        mintToken(feesAddress, feeTokens * precision);
 
        // Emit events
        emit Withdra(user, amount, withType);
        emit Mined(feesAddress, feeTokens * precision);
 
        // Update user's total withdrawal
        users[user].totalWithdrawal += amount;
 
        // Log the withdrawal
        withdrawals[user].push(
            Withdrawal({
                amount: amount,
                timestamp: block.timestamp,
                withType: withType
            })
        );
    }
}
