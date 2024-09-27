// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol"; // Import ERC20 standard from OpenZeppelin
import "@openzeppelin/contracts/access/Ownable.sol"; // Import Ownable for access control
import "./ReferralCalculation.sol"; // Import referral calculation logic

contract eCryptoToken is ERC20, Ownable, ReferralCalculation {
    uint256 public constant INITIAL_SUPPLY = 21000000 * 10 ** 18; // 21 million tokens with 6 decimals

    struct User {
        uint256 investmentAmount;
        bool hasInvested;
    }

    mapping(address => User) public users;

    // Constructor
    constructor() ERC20("eCrypto", "eCrypto") Ownable(msg.sender) {
       
    }

    // Allow users to invest eCrypto tokens
    function invest(uint256 _amount) external {
        require(_amount > 0, "Investment must be greater than zero");
        require(balanceOf(msg.sender) >= _amount, "Insufficient token balance");

        // Transfer tokens to the contract
        _transfer(msg.sender, address(this), _amount);

        // Record the user's investment
        users[msg.sender].investmentAmount += _amount;
        users[msg.sender].hasInvested = true;
    }

    // Use the _mint function provided by the OpenZeppelin ERC-20 contract
    function distributeTeamIncome(address _user, uint256 _investmentAmount) internal override {
        address upline = referrals[_user].referrer;

        for (uint256 level = 1; level <= 10; level++) {
            if (upline == address(0)) break;

            if (calculateEligibilityLevel(upline, level)) {
                // 1% team income calculation
                uint256 teamIncome = (_investmentAmount * 1) / 100;

                // Mint team income directly using the ERC-20 _mint function
                _mint(upline, teamIncome);
            }

            upline = referrals[upline].referrer;
        }
    }
}
