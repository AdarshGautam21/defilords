// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MockStrategyVault {
    function deposit(address token, uint256 amount) external {}
    function withdraw(address token, uint256 amount) external returns (uint256) {
        return amount;
    }
    function getBalance(address token) external view returns (uint256) {
        return 0;
    }
}