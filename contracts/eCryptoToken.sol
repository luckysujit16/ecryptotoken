// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
 
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
 
contract EcryptoToken is Initializable, ERC20Upgradeable, OwnableUpgradeable {
    address public financeContract;
    uint256 public MAX_SUPPLY = 21000000 * 10 ** decimals();
 
    function initialize() public initializer {
        __ERC20_init("EcryptoT", "ECRYPT");
        __Ownable_init(msg.sender); // Allows owner control
        _mint(msg.sender, 50 * 10 ** decimals()); // Initial mint for the owner
    }
 
    // Restrict minting to only the finance contract
    function setfinanceContract(address _financeContract) external onlyOwner {
        financeContract = _financeContract;
    }
 
    function mint(address to, uint256 amount) external {
        require(
            totalSupply() + amount <= MAX_SUPPLY,
            "Minting would exceed max supply"
        );
        require(
            msg.sender == financeContract,
            "Only finance contract can mint"
        );
        _mint(to, amount);
    }
}