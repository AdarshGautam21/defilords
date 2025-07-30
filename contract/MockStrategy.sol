// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function transfer(address to, uint256 amount) external returns (bool);
}

contract MockStrategy {
    // Address of the vault that is allowed to call deposit/withdraw
    address public immutable simpleVault;
    // Address of the USDT token
    address public immutable usdt;

    modifier onlyVault() {
        require(msg.sender == simpleVault, "Not authorized");
        _;
    }

    event Deposit(address indexed user, uint256 amount, address token);
    event Withdraw(address indexed user, uint256 amount, address token);

    constructor(address _simpleVault, address _usdt) {
        require(_simpleVault != address(0), "Vault address zero");
        require(_usdt != address(0), "USDT address zero");
        simpleVault = _simpleVault;
        usdt = _usdt;
    }

    // Deposit ETH (SimpleVault should wrap ETH if required)
    function depositETH(address user) external payable onlyVault {
        require(msg.value > 0, "No ETH sent");
        emit Deposit(user, msg.value, address(0));
    }

    // Deposit USDT
   function depositUSDT(address user, uint256 amount) external onlyVault {
    require(amount > 0, "Amount zero");
    require(IERC20(usdt).transferFrom(msg.sender, address(this), amount), "USDT transfer failed");
    emit Deposit(user, amount, usdt);
}


    // Withdraw ETH
    function withdrawETH(address user, uint256 amount) external onlyVault {
        require(amount > 0, "Amount zero");
        require(address(this).balance >= amount, "Insufficient ETH");
        (bool sent, ) = user.call{value: amount}("");
        require(sent, "ETH withdraw failed");
        emit Withdraw(user, amount, address(0));
    }

    // Withdraw USDT
    function withdrawUSDT(address user, uint256 amount) external onlyVault {
        require(amount > 0, "Amount zero");
        require(IERC20(usdt).transfer(user, amount), "USDT withdraw failed");
        emit Withdraw(user, amount, usdt);
    }

    // Fallback to accept ETH
    receive() external payable {}
}
