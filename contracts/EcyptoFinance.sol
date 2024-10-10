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
    address private owner;

    // Addresses for various payments
    address private liquidityAddress;
    address private marketingAddress;
    address private promoAddress;
    address private adminAddress;
    address private emergencyAddress;
    address private liquidityPoolAddress;
    address private stakingAddress;
    address private feesAddress;

    address public tokenAddress;

    uint256 public directReferralPer = 5; // One Time
    uint256 public referralLevelPer = 1; // monthly

    uint256 public initialTokenRate = 5;

    uint256 public minimumDeposit = 5; // In USDT
    uint256 public minimumWithdrawal = 5; // In USDT
    uint256 public precision = 1e18; // In Wie

    uint256 public withdrawalFees = 5;

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
    mapping(address => Deposit[]) private deposits;
    mapping(address => Withdrawal[]) private withdrawals;
    address[] private userAddresses;
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
            amount > minimumDeposit * precision,
            "Deposit must be greater than 5 USDT"
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

        uint256 growthTill = calculateGrowth(msg.sender);
        if (growthTill > 0) {
            users[msg.sender].balance += growthTill;
        }

        emit Invested(msg.sender, amount);
    }

    function calculateReferralIncomeForTree(
        address user
    ) public view returns (uint256 totalReferralIncome) {
        require(users[user].user != address(0), "User does not exist");

        // Start the recursion from the root user (initial user) at level 1
        totalReferralIncome = calculateIncomeForUser(user, 1);
    }

    function calculateIncomeForUser(
        address currentUser,
        uint256 level
    ) internal view returns (uint256) {
        if (currentUser == address(0) || level > maxLevels) {
            return 0;
        }

        uint256 totalIncome = 0;

        uint256 numerator = referralLevelPer * 12 * 1e18;
        uint256 denominator = 365;

        // Perform the division
        uint256 dailyPercentage = numerator / denominator;

        // Get the user's deposits and calculate total business volume
        Deposit[] memory userDeposits = deposits[currentUser];
        uint256 totalBusinessVolume = 0;

        for (uint256 i = 0; i < userDeposits.length; i++) {
            totalBusinessVolume += userDeposits[i].amount;
        }

        // Determine the business level based on total business volume
        uint256 businessLevel = getBusinessLevel();

        // Only calculate income if the user qualifies for this business level
        if (businessLevel >= level) {
            // Get referral percentage once per user

            for (uint256 i = 0; i < userDeposits.length; i++) {
                Deposit memory currentDeposit = userDeposits[i];
                uint256 daysPassed = calculateDaysSince(
                    currentDeposit.timestamp
                );

                // Calculate income for the current deposit with scaling
                uint256 dailyIncome = (currentDeposit.amount *
                    dailyPercentage) / 1e18; // Divide by 1e18 to match precision

                // Add to total income based on the days passed
                totalIncome += dailyIncome * daysPassed;
            }
        }

        // Recursively calculate income from direct referrals (child nodes)
        address[] memory directReferrals = users[currentUser].referrals;
        for (uint256 j = 0; j < directReferrals.length; j++) {
            totalIncome += calculateIncomeForUser(
                directReferrals[j],
                level + 1
            );
        }

        return totalIncome;
    }

    // Function to determine the business level based on the total business volume
    function getBusinessLevel(
        
    ) public pure returns (uint256 level) {
         return 10;
        
    }

    function calculateGrowth(address user) public view returns (uint256) {
        // Ensure the user has deposits
        Deposit[] memory userDeposits = deposits[user];
        require(userDeposits.length > 0, "No deposits for this user");

        // Get the latest deposit
        Deposit memory lastDeposit = userDeposits[userDeposits.length - 1];
        uint256 depositTimestamp = lastDeposit.timestamp;

        // Calculate days passed since the last deposit
        uint256 daysPassed = calculateDaysSince(depositTimestamp);

        // Get the growth percentage based on the invested amount
        uint256 growthPer = getGrowthPer(investments[user]);

        // Calculate per day percent and income
        uint256 perDayPercent = (growthPer * precision * 12) / 365; // Scaled up to avoid precision loss
        uint256 perDayIncome = (investments[user] * perDayPercent) / 100e18; // Scale back down

        return perDayIncome * daysPassed;
    }

    function calculateDaysSince(
        uint256 timestamp
    ) internal view returns (uint256) {
        if (block.timestamp > timestamp) {
            return (block.timestamp - timestamp) / 1 minutes;
        } else {
            return 0;
        }
    }

    function getGrowthPer(
        uint256 investedAmount
    ) internal pure returns (uint256) {
        if (investedAmount >= 5000) {
            return 7;
        } else if (investedAmount >= 1000) {
            return 6;
        } else if (investedAmount >= 500) {
            return 5;
        } else if (investedAmount >= 5) {
            return 4;
        } else {
            return 0;
        }
    }

    function transferUsd(address recipient, uint256 amount) internal {
        usdtToken.safeTransferFrom(msg.sender, recipient, amount);
    }

    function mintToken(address recipient, uint256 amount) internal {
        ecryptoToken.mint(recipient, amount);
        emit Mined(recipient, amount);
    }

    function getUserDeposits(
        address user
    ) external view returns (Deposit[] memory) {
        return deposits[user];
    }

    function getFormattedDeposits(
        address user
    )
        external
        view
        returns (uint256[] memory amounts, uint256[] memory timestamps)
    {
        uint256 len = deposits[user].length;
        amounts = new uint256[](len);
        timestamps = new uint256[](len);

        for (uint256 i = 0; i < len; i++) {
            amounts[i] = deposits[user][i].amount;
            timestamps[i] = deposits[user][i].timestamp;
        }
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
    uint256 liquidityTokenBalance = ecryptoToken.balanceOf(liquidityAddress);
    uint256 baseRate = initialTokenRate * (10 ** 18);

    // Calculate total supply held by users
    uint256 totalSupply = ecryptoToken.totalSupply();
    uint256 totalSupplyOfUser = totalSupply -
        (ecryptoTokenBal + liquidityTokenBalance);

    // If no tokens are held by users, return the base rate
    if (totalSupplyOfUser == 0) {
        return baseRate;
    }

    // Calculate total USDT held across liquidity, emergency, and contract balances
    uint256 totalUSDT = usdtToken.balanceOf(liquidityPoolAddress) +
        usdtToken.balanceOf(emergencyAddress) +
        usdtToken.balanceOf(address(this));

    // Add the staking balance separately without recursion
    uint256 stakingBalance = ecryptoToken.balanceOf(stakingAddress);
    totalUSDT += stakingBalance * baseRate; // Use base rate or a pre-calculated rate if needed

    // Calculate rate with a scaling factor for precision
    uint256 rate = (totalUSDT * precision) / totalSupplyOfUser;

    // Return the greater of rate or baseRate
    return rate >= baseRate ? rate : baseRate;
    }

   

   function withdraw(uint256 amount, uint256 withType) external {
        require(withType == 1 || withType == 2, "Invalid withdrawal type");
        require(amount >= minimumWithdrawal, "Minimum withdrawal amount is 5");
 
        // Check if the user (msg.sender) is registered (i.e., they have made an investment)
        require(investments[msg.sender] > 0, "User is not registered");
 
        uint256 fees = withdrawalFees; // Fee percentage
 
        // Calculate available balances
        uint256 growthUsd = calculateGrowth(msg.sender);
        uint256 referralUsd = calculateReferralIncomeForTree(msg.sender);
        uint256 directReferralUsd = users[msg.sender].directBal;
        uint256 storedReferralUsd = users[msg.sender].referralBal;
 
        // Total available balance for withdrawal
        uint256 totalUsd = growthUsd +
            referralUsd +
            directReferralUsd +
            storedReferralUsd -
            users[msg.sender].totalWithdrawal;
 
        require(totalUsd >= amount, "Insufficient withdrawal amount");
 
        // Ensure total withdrawals don't exceed 3x the user's investment
        require(
            users[msg.sender].totalWithdrawal + amount <=
                investments[msg.sender] * 3,
            "Withdrawal amount exceeds 3x of your investment"
        );
 
        uint256 feeUsd = (amount * fees) / 100; // Calculate fee amount in USD
        uint256 netAmount = amount - feeUsd; // Amount after fee deduction
 
        if (withType == 1) {
            // USDT withdrawal
            uint256 feesInTokens = (feeUsd * precision) / calculateLiveRate(); // Convert fee to tokens based on live rate
 
            if (feeUsd < precision) {
                // Ensure a minimum fee in tokens
                feesInTokens = (1 * precision) / calculateLiveRate();
            }
 
            // Transfer net amount and fee
            usdtToken.safeTransfer(
                msg.sender,
                (netAmount * precision) / calculateLiveRate()
            ); // Convert net amount to tokens
            mintToken(feesAddress, feesInTokens);
 
            emit Withdra(msg.sender, amount, withType);
            emit Mined(feesAddress, feesInTokens);
        } else if (withType == 2) {
            // Token withdrawal
            uint256 tokenAmount = (amount * precision) / calculateLiveRate(); // Convert withdrawal amount to tokens
            uint256 feesInTokens = (tokenAmount * fees) / 100; // Calculate fee in tokens
 
            if (feeUsd < precision) {
                // Ensure a minimum fee in tokens
               feesInTokens = (1 * precision) / calculateLiveRate();
            }
 
            // Transfer net amount and fee
            mintToken(msg.sender, tokenAmount - feesInTokens);
            mintToken(feesAddress, feesInTokens);
 
            emit Withdra(msg.sender, tokenAmount, withType);
            emit Mined(feesAddress, feesInTokens);
        }
 
        // Update user's total withdrawal
        users[msg.sender].totalWithdrawal += amount;
 
        // Log the withdrawal
        withdrawals[msg.sender].push(
            Withdrawal({
                amount: amount,
                timestamp: block.timestamp,
                withType: withType
            })
        );
    }

}
