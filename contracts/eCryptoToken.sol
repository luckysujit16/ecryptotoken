// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ReferralCalculation.sol"; // Import the Referral logic

contract eCryptoToken is ERC20, Ownable, ReferralCalculation {
    uint256 public constant INITIAL_SUPPLY = 21000000 * 10 ** 8; // 21 million tokens with 8 decimals (eSatoshi)

    constructor() ERC20("eCrypto", "eCrypto") Ownable(msg.sender) {
        // Mint the initial supply of tokens to the owner of the contract
        _mint(msg.sender, INITIAL_SUPPLY);
    }
    // Allow users to register a referral
    function registerUserReferral(address _referrer) external {
        require(balanceOf(msg.sender) > 0, "You need to invest before referring");
        uint256 investmentAmount = balanceOf(msg.sender);

        registerReferral(_referrer, msg.sender, investmentAmount);
    }

    // Allow users to distribute income to their team
    function claimTeamIncome() external {
        distributeTeamIncome(msg.sender, balanceOf(msg.sender));
    }

    // Function to update downline investments (internal)
    function _updateDownlineInvestments(address user, uint256 investmentAmount, uint256 currentLevel) internal {
        updateLevelInvestment(user, investmentAmount, currentLevel);
    }
}

