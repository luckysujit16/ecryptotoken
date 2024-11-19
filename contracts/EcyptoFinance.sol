// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IEcryptoToken {
    function mint(address to, uint256 amount) external;

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);
}

contract EcyptoFinance {
    using SafeERC20 for IERC20;

    IERC20 public usdtToken;
    IEcryptoToken public ecryptoToken;
    address public owner;

    // Addresses for various payments
    address public liquidityAddressUSDT;
    address public liquidityAddressBNB;
    address public liquidityAddressETH;
    address public liquidityAddressBTC;
    address public marketingAddress;
    address public promoAddress;
    address public adminAddress;
    address public emergencyAddress;
    address public stakingAddress;
    address public feesAddress;

    address public tokenAddress;

    uint256 public totalUsdPaid;
    uint256 public totalEcryptoPaid;
    uint256 public totalWithdrawals;

    uint256 public directReferralPer = 5e18; // One Time
    uint256 public referralLevelPer = 1e18; // monthly

    uint256 public initialTokenRate = 5e18;

    uint256 public minimumDeposit = 5e18; // In USDT
    uint256 public minimumWithdrawal = 5e18; // In USDT
    
    uint256 public precision = 1e18; // In Wie

    uint256 public withdrawalFees = 5;

    uint256 public liquiditySharePercent = 50e18;
    uint256 public marketingSharePercent = 10e18;
    uint256 public promoSharePercent = 5e18;
    uint256 public adminSharePercent = 5e18;
    uint256 public emergencySharePercent = 10e18;
    uint256 public contractSharePercent = 20e18;

    uint256 public maxLevels = 10;
    uint256 private devider = 100e18;

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
        uint256 rate;
        uint256 withType;
    }
    struct Redeems {
        uint256 amount;
        uint256 timestamp;
        uint256 rate;
    }

    mapping(address => User) public users;
    mapping(address => Deposit[]) public deposits;
    mapping(address => Withdrawal[]) public withdrawals;
    mapping(address => Redeems[]) public redeems;
    address[] public userAddresses;
    mapping(address => uint256) public investments;

    event Invested(address indexed user, uint256 amount);
    event Mined(address indexed user, uint256 amount);
    event Withdra(address indexed user, uint256 amount, uint256 withType);
    event Redeem(address indexed user, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    constructor(
        address _tokenAddress,
        address _usdtTokenAddress,
        address _liquidityAddressUSDT,
        address _liquidityAddressBNB,
        address _liquidityAddressETH,
        address _liquidityAddressBTC,
        address _marketingAddress,
        address _promoAddress,
        address _adminAddress,
        address _emergencyAddress,
        address _stakingAddress,
        address _feesAddress
    ) {
        ecryptoToken = IEcryptoToken(_tokenAddress);
        usdtToken = IERC20(_usdtTokenAddress);
        owner = msg.sender;

        liquidityAddressUSDT = _liquidityAddressUSDT;
        liquidityAddressBNB = _liquidityAddressBNB;
        liquidityAddressETH = _liquidityAddressETH;
        liquidityAddressBTC = _liquidityAddressBTC;
        marketingAddress = _marketingAddress;
        promoAddress = _promoAddress;
        adminAddress = _adminAddress;
        emergencyAddress = _emergencyAddress;
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
            amount >= minimumDeposit,
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
        uint256 liquidityShare = (amount * liquiditySharePercent) / devider;
        uint256 marketingShare = (amount * marketingSharePercent) / devider;
        uint256 promoShare = (amount * promoSharePercent) / devider;
        uint256 adminShare = (amount * adminSharePercent) / devider;
        uint256 emergencyShare = (amount * emergencySharePercent) / devider;

        uint256 tokenLiveRate = calculateLiveRate();
        uint256 tokenLiquidityShare = (amount * precision) / tokenLiveRate;

        uint256 contractShare = (amount * contractSharePercent) / devider;

        // Transfer USDT to respective addresses
        
        transferUsd(marketingAddress, marketingShare);
        transferUsd(promoAddress, promoShare);
        transferUsd(adminAddress, adminShare);
        transferUsd(emergencyAddress, emergencyShare);
        transferUsd(address(this), contractShare);

        // Mint tokens as a reward to the liquidity pool
        
        checkLiquidity(amount, tokenLiquidityShare, liquidityShare);
        users[users[msg.sender].referrer].directBal +=
            (amount * directReferralPer) /
            devider;
        investments[msg.sender] += amount;

        emit Invested(msg.sender, amount);
    }

    function checkLiquidity(uint256 amount, uint256 tokenShare, uint256 usdtShare) internal {
        if (amount >= 5000 * 10**18) {
            mintToken(liquidityAddressBTC, tokenShare);
            transferUsd(liquidityAddressBTC, usdtShare);
        } else if (amount >= 1000 * 10**18) {
           mintToken(liquidityAddressETH, tokenShare);
           transferUsd(liquidityAddressETH, usdtShare);
        } else if (amount >= 500 * 10**18) {
            mintToken(liquidityAddressBNB, tokenShare);
            transferUsd(liquidityAddressBNB, usdtShare);
        } else if (amount >= 5 * 10**18) {
            mintToken(liquidityAddressUSDT, tokenShare);
            transferUsd(liquidityAddressUSDT, usdtShare);
        } 
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

            // Calculate the business volume for this referral's deposits
            uint256 referralBusinessVolume = calculateBusinessVolume(referral);

            // Check if this referral's business volume qualifies for the required level
            uint256 referralBusinessLevel = getBusinessLevel(
                referralBusinessVolume
            );
            if (referralBusinessLevel < level) {
                continue; // Skip if the referral's business level does not meet the required level
            }

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

    // Helper function to calculate the business volume of a user (sum of all deposits)
    function calculateBusinessVolume(address user)
        internal
        view
        returns (uint256)
    {
        Deposit[] storage userDeposits = deposits[user];
        uint256 businessVolume = 0;

        for (uint256 i = 0; i < userDeposits.length; i++) {
            businessVolume += userDeposits[i].amount;
        }

        return businessVolume;
    }

    // Function to determine the business level based on the total business volume
    function getBusinessLevel(uint256 businessVolume)
        public
        pure
        returns (uint256 level)
    {
        if (businessVolume >= 1875000000 * 1e18) {
            // 1.87 Billion
            return 10;
        } else if (businessVolume >= 375000000 * 1e18) {
            // 375 Million
            return 9;
        } else if (businessVolume >= 75000000 * 1e18) {
            // 75 Million
            return 8;
        } else if (businessVolume >= 15000000 * 1e18) {
            // 15 Million
            return 7;
        } else if (businessVolume >= 3000000 * 1e18) {
            // 3 Million
            return 6;
        } else if (businessVolume >= 600000 * 1e18) {
            // 0.6 Million
            return 5;
        } else if (businessVolume >= 125000 * 1e18) {
            // 125K
            return 4;
        } else if (businessVolume >= 25000 * 1e18) {
            // 25K
            return 3;
        } else if (businessVolume >= 5000 * 1e18) {
            // 5K
            return 2;
        } else if (businessVolume >= 1000 * 1e18) {
            // 1K
            return 1;
        } else {
            return 0; // No qualification
        }
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
            uint256 perDayIncome = (deposit.amount * growthPer) / devider;

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
            return (block.timestamp - timestamp) / 1 days;            
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
        uint256 feeUsd = (amount * withdrawalFees) / 100;
        uint256 netAmount = amount - feeUsd;

        // Calculate fee and net amount in tokens
        uint256 tokenliveRate = calculateLiveRate();
        uint256 feesTokens = getFees(amount);
        if (feeUsd < precision) {
            netAmount = amount - 1e18;
        }
        if (withType == 1) {
            // USDT withdrawal
            usdtToken.safeTransfer(user, netAmount);
            totalUsdPaid += amount;
        } else if (withType == 2) {
            // Token withdrawal
            uint256 tokens = ((amount * precision) / tokenliveRate) - feesTokens;
            mintToken(user, tokens);
            totalEcryptoPaid += (amount * precision) / tokenliveRate;
        }

        // Mint tokens for the fee
        mintToken(feesAddress, feesTokens);

        // Emit events
        emit Withdra(user, amount, withType);
        emit Mined(feesAddress, feesTokens);

        // Update user's total withdrawal
        users[user].totalWithdrawal += amount;
        totalWithdrawals += amount;
        // Log the withdrawal
        withdrawals[user].push(
            Withdrawal({
                amount: amount,
                timestamp: block.timestamp,
                rate: tokenliveRate,
                withType: withType
            })
        );
    }

    //Calculate Fees on withdrawal to be minted and credited to Fees Wallet for Stakers & Contract Owners Share
    function getFees(uint256 amount) public view returns (uint256) {
        uint256 feeUsd = (amount * withdrawalFees) / 100;

        uint256 tokenliveRate = calculateLiveRate();
        uint256 feeTokens = (feeUsd * precision) / tokenliveRate;

        // Ensure a minimum fee in tokens if feeUsd is less than precision
        if (feeUsd < precision) {
            feeTokens = (1e18 * precision) / tokenliveRate;
        }

        return feeTokens;
    }

    // Calculate Live Rate of eCrypto as per formula described in whitepaper.
    function calculateLiveRate() public view returns (uint256) {
    // Fetch balances in a single statement to minimize storage access
    uint256 ecryptoTokenBal = ecryptoToken.balanceOf(tokenAddress);
    uint256 liquidityTokenBalance = 
        ecryptoToken.balanceOf(liquidityAddressBTC) +
        ecryptoToken.balanceOf(liquidityAddressETH) +
        ecryptoToken.balanceOf(liquidityAddressBNB) +
        ecryptoToken.balanceOf(liquidityAddressUSDT);
    uint256 stakedTokenBalance = ecryptoToken.balanceOf(stakingAddress);
    uint256 totalSupply = ecryptoToken.totalSupply();

    uint256 baseRate = initialTokenRate;

    // Calculate tokens held by users
    uint256 totalSupplyOfUser = totalSupply - (
        ecryptoTokenBal + liquidityTokenBalance + stakedTokenBalance
    );

    // If no tokens are held by users, return the base rate
    if (totalSupplyOfUser == 0) {
        return baseRate;
    }

    // Calculate total USDT in liquidity
    uint256 totalLiquidityUSDT = 
        usdtToken.balanceOf(liquidityAddressUSDT) +
        usdtToken.balanceOf(liquidityAddressBNB) +
        usdtToken.balanceOf(liquidityAddressETH) +
        usdtToken.balanceOf(liquidityAddressBTC);

    // Include emergency and contract balances
    uint256 totalUSDT = totalLiquidityUSDT +
        usdtToken.balanceOf(emergencyAddress) +
        usdtToken.balanceOf(address(this));

    // Calculate the rate based on total USDT and user-held supply
    uint256 rate = (totalUSDT * precision) / totalSupplyOfUser;

    // Adjust the rate with staking balance
    uint256 stakingUsdBalance = (stakedTokenBalance * rate) / precision;
    uint256 adjustedTotalUSDT = totalUSDT + stakingUsdBalance;

    // Recalculate the final rate
    uint256 finalRate = (adjustedTotalUSDT * precision) / totalSupplyOfUser;

    // Return the greater of finalRate or baseRate
    return finalRate > baseRate ? finalRate : baseRate;
}


    function redeemEcrypto(uint256 amount) external {
    require(amount >= 1e18, "Invalid amount"); // Ensure at least 1 eCrypto is redeemed

    // Get the live rate
    uint256 rate = calculateLiveRate();

    // Calculate USD equivalent (consider token decimals)
    uint256 usdAmount = (amount * rate) / 1e18; // Adjust for eCrypto's 18 decimals

    // Ensure the user has sufficient eCrypto balance
    require(
        ecryptoToken.balanceOf(msg.sender) >= amount,
        "Insufficient eCrypto balance in user wallet"
    );

    // Ensure the contract has enough USDT balance
    require(
        usdtToken.balanceOf(address(this)) >= usdAmount,
        "Insufficient USDT balance in Finance Contract"
    );

    // Transfer eCrypto tokens from the user to the contract
    ecryptoToken.transferFrom(msg.sender, address(this), amount);

    // Transfer the equivalent USDT amount to the user
    usdtToken.safeTransfer(msg.sender, usdAmount);

    // Emit an event for the redemption
    emit Redeem(msg.sender, amount);

    // Record the redemption
    redeems[msg.sender].push(
        Redeems({amount: amount, rate: rate, timestamp: block.timestamp})
    );
    }
    // Check Finance Contract USDT Bal for the redemption
    function checkContractUSDBal(uint256 amount) public view returns (uint256 usdAmount, uint256 contractUSDBal) {
        uint256 liveRate = calculateLiveRate();
        usdAmount = amount * liveRate / 1e18;
        return (usdAmount, usdtToken.balanceOf(address(this)));
    }
       
    // This function can withdraw all Redeemed eCrypto Tokens to Contract Owner only after entire supply of 2.1 Million is Minted.
    function withdrawEcrypto(uint256 amount) external onlyOwner {
        // Check if the total supply is at least 21 million tokens (assuming 18 decimals)
        require(
            // ecryptoToken.totalSupply() >= 21000000 * 10**18, 
            ecryptoToken.totalSupply() >= 49 * 10**18,
            "Minimum supply not met"
        );
        // Check if the contract has enough balance to fulfill the withdrawal
        require(
            ecryptoToken.balanceOf(address(this)) >= amount,
            "Insufficient contract Ecrypto balance"
        );
        // Transfer the specified amount of Ecrypto to the owner
        ecryptoToken.transfer(msg.sender, amount);
    }

    function setStakingAddress(address _stakingAddress) external onlyOwner {
        stakingAddress = _stakingAddress;
    }

    function setfeesAddress(address _feesAddress) external onlyOwner {
        feesAddress = _feesAddress;
    }

    function setliquidityAddressUSDT(address _liquidityAddressUSDT) external onlyOwner {
        liquidityAddressUSDT = _liquidityAddressUSDT;
    }

    function setliquidityAddressBNB(address _liquidityAddressBNB) external onlyOwner {
        liquidityAddressBNB = _liquidityAddressBNB;
    }

    function setliquidityAddressETH(address _liquidityAddressETH) external onlyOwner {
        liquidityAddressETH = _liquidityAddressETH;
    }

    function setliquidityAddressBTC(address _liquidityAddressBTC) external onlyOwner {
        liquidityAddressBTC = _liquidityAddressBTC;
    }
    
}
