// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract ReferralCalculation {

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

        referrals[_newUser].referrer = _referrer;
        referrals[_newUser].referralIncome = 0;
        referrals[_newUser].level = 0;

        referrals[_referrer].levelInvestment[1] += _investmentAmount;
    }

    // Calculate eligibility based on level-specific investment
    function calculateEligibilityLevel(address user, uint256 level) internal view returns (bool) {
        uint256 requiredInvestment;

        if (level == 1) {
            requiredInvestment = 1000 * 10 ** 18; // 6 decimals for TRC-20
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

    // We will remove the direct call to _mint here and handle it in eCryptoToken.sol
    function distributeTeamIncome(address _user, uint256 _investmentAmount) internal virtual;
}
