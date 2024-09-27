// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract ReferralCalculation {

    struct Referral {
        address referrer;
        uint256 referralIncome;
        uint256 level;
        mapping(uint256 => uint256) levelInvestment; // Track investment for each level
    }

    mapping(address => Referral) public referrals;

    // Register a referral
    function registerReferral(address _referrer, address _newUser, uint256 _investmentAmount) internal {
        require(_referrer != address(0), "Referrer must be valid");
        require(referrals[_newUser].referrer == address(0), "User already has a referrer");

        // Instead of assigning the whole struct, we assign the individual fields
        referrals[_newUser].referrer = _referrer;
        referrals[_newUser].referralIncome = 0;
        referrals[_newUser].level = 0;

        // Update level 1 investment for the referrer
        referrals[_referrer].levelInvestment[1] += _investmentAmount;
    }

    // Calculate eligibility based on level-specific investment
    function calculateEligibilityLevel(address user, uint256 level) internal view returns (bool) {
        uint256 requiredInvestment;

        if (level == 1) {
            requiredInvestment = 1000 * 10 ** 18;
        } else if (level == 2) {
            requiredInvestment = 5000 * 10 ** 18;
        } else if (level == 3) {
            requiredInvestment = 25000 * 10 ** 18;
        } else if (level == 4) {
            requiredInvestment = 125000 * 10 ** 18;
        } else if (level == 5) {
            requiredInvestment = 625000 * 10 ** 18;
        } else if (level == 6) {
            requiredInvestment = 3125000 * 10 ** 18;
        } else if (level == 7) {
            requiredInvestment = 15625000 * 10 ** 18;
        } else if (level == 8) {
            requiredInvestment = 78125000 * 10 ** 18;
        } else if (level == 9) {
            requiredInvestment = 390625000 * 10 ** 18;
        } else if (level == 10) {
            requiredInvestment = 1953125000 * 10 ** 18;
        }

        return referrals[user].levelInvestment[level] >= requiredInvestment;
    }

    // Distribute team income based on eligibility
    function distributeTeamIncome(address _user, uint256 _investmentAmount) internal {
        address upline = referrals[_user].referrer;

        for (uint256 level = 1; level <= 10; level++) {
            if (upline == address(0)) break;

            if (calculateEligibilityLevel(upline, level)) {
                // 1% team income logic
                uint256 teamIncome = (_investmentAmount * 1) / 100;
                // Logic to distribute team income (for example, using _mint function if this is an ERC20)
            }

            upline = referrals[upline].referrer;
        }
    }

    // Update investment for each level
    function updateLevelInvestment(address user, uint256 investmentAmount, uint256 currentLevel) internal {
        address referrer = referrals[user].referrer;
        uint256 level = currentLevel;

        while (referrer != address(0) && level <= 10) {
            referrals[referrer].levelInvestment[level] += investmentAmount;
            referrer = referrals[referrer].referrer;
            level++;
        }
    }
}
