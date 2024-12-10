// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SafeWallet {
    using SafeERC20 for IERC20;
    address public owner;
    mapping(address => bool) public isAuthorized;

  event AuthorizationUpdated(address indexed account, bool authorized);
  event Deposit(address indexed sender, uint256 amount);
  event Withdrawal(address indexed to, uint256 amount);
  event Deposit(address indexed from, address indexed token, uint256 amount);


modifier onlyOwner(){
    require(msg.sender == owner, "Not the owner");
    _;
}

modifier onlyAuthorized() {
        require(isAuthorized[msg.sender] || msg.sender == owner, "Not authorized");
        _;
    }

constructor(){
    msg.sender == owner;
}

function deposit(address token, uint256 amount) external payable {
    if (msg.value > 0) {
        // Deposit ETH
        emit Deposit(msg.sender, address(0), msg.value);
    }
    if (token != address(0) && amount > 0) {
        // Deposit ERC20 tokens
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, token, amount);
    }
    require(msg.value > 0 || amount > 0, "No funds provided");
}


function setAuthorized(address account, bool authorized) external onlyOwner {
        isAuthorized[account] = authorized;
        emit AuthorizationUpdated(account, authorized);
    }

    function transferTokens(address token, uint256 amount, address to) external onlyOwner {
        IERC20(token).safeTransfer(to, amount);
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }
    fallback() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    // Withdraw funds to a specified address
    function withdraw(address payable to, uint256 amount) external onlyAuthorized {
        require(address(this).balance >= amount, "Insufficient balance");
        to.transfer(amount);
        emit Withdrawal(to, amount);
    }

     // Get the wallet's current balance
    function getBalance() external view returns (uint256) {
        return address(this).balance;
    }

    // Allow the owner to transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid address");
        owner = newOwner;
    }
}