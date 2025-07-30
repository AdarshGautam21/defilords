//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IStrategyVault {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount) external returns (uint256);
    function getBalance(address token) external view returns (uint256);
}

contract SimpleVault is ReentrancyGuard{
    using SafeEC20 for IERC20;
}

struct UserDeposit
{}

//Constant decleration
uint256 public constant FIXED_APY = 20; //
uint256 public constant LOCK_PERIOD = 7 days;
uint256 public constant BASIS_POINTS = 10000;
uint256 public constant SECS_PER_YEAR = 31536000; // 365 days   

//State Variables
IERC20 public immutable USDT;
IStrategyVault public strategyVault;

mapping(address => mapping(address => UserDeposit)) public userDeposits;

mapping (address => uint256) public totalDeposits;

//Events declaration
event Deposited(address indexed user, address indexed token,uint256 amount, uint256 timestamp);
event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 yield);
event AllocatedToStrategy(address indexed token, uint256 amount);
event YieldClaimed(address indexed user, address indexed token, uint256 yield
);



constructor(address _usdt, address _strategyVault) {
    USDT = IERC20(_usdt);
    strategyVault = IStrategyVault(_strategyVault);
}

// ETH deposit functionality
function depositETH() external payable nonReentrant{
    require(msg.value > 0, "Amount must be greater than 0");
    address ethToken = address(0);
    userDeposits[msg.sender][ethToken].amount += msg.value;
    userDeposits[msg.sender][ethToken].timestamp = block.timestamp;
    userDeposits[msg.sender][ethToken].lastYieldClaim = block.timestamp;

    totalDeposits[ethToken] += msg.value;
    emit Deposited(msg.sender, ethToken, msg.value, block.timestamp);
}

//USDT function for deposit

function depositUSDT(uint256 amount) external nonReentrant {
    require(amount > 0, "Amount must be greater than 0");
    USDT.safeTransferFrom(msg.sender, address(this), amount);
    
    address usdtToken = address(USDT);
    userDeposits[msg.sender][usdtToken].amount += amount;
    userDeposits[msg.sender][usdtToken].timestamp = block.timestamp;
    userDeposits[msg.sender][usdtToken].lastYieldClaim = block.timestamp;

    totalDeposits[usdtToken] += amount;
    emit Deposited(msg.sender, usdtToken, amount, block.timestamp);
}

//Withdraw function with yield calculation
function withdraw(address token) external nonReentrant {
    UserDeposit storage userDeposit = userDeposits[msg.sender][token];
    require(userDeposit.amount > 0, "No deposit found");
    require(canWithdraw(msg.sender, token), "Withdrawal not allowed for 7 days  after deposit");
    uint principal = userDeposit.amount;
    uint256 yield = getClaimableYield(msg.sender, token);
    uint256 totalAmount = principal + yield;

    userDeposit.amount = 0;
    userDeposit.timestamp = 0;
    userDeposit.lastYieldClaim = 0;

    totalDeposits[token] -= principal;

    //tranfer funds to user

    if (token == address(0)) {
        require(address(this).balance >= totalAmount, "Insufficient contract balance");
        payable(msg.sender).transfer(totalAmount);
    } else {
        //USdT
        require(IERC20(token).balanceOf(address(this)) >= totalAmount, "Insufficient contract balance");
        IERC20(token).safeTransfer(msg.sender, totalAmount);
    }
    emit Withdrawn(msg.sender, token, principal, yield);

  //ADmin fucntion rto allocate funds to strategy vault
function allocateToStrategy(address token, uint256 amount) external onlyOwner {
    require(amount > 0, "Amount must be greater than 0");
    if (token == address(0)) {
        //eth
        require(address(this).balance >= amount, "Insufficient ETH balance");
        payable(address(strategyVault)).transfer(amount);
    } else {
        //token allocate
        require(IERC20(token).balanceOf(address(this)) >= amount, "Insufficient toekn balance");
        IERC20(token).safeTransfer(address(strategyVault), amount);
    }

    strategyVault.deposit(token, amount);
    emit AllocatedToStrategy(token, amount);
}

//View fucntion
function getClaimableYield(address user, address token) public view returns (uint256) {
    UserDeposit memory userDeposit = userDeposits[user][token];
    if (userDeposit.amount == 0) return 0;

    uint256 timeHeld = block.timestamp - userDeposit.lastYieldClaim;
    uint256 annualYield = (userDeposit.amount * FIXED_APY * timeHeld) / (BASIS_POINTS * SECS_PER_YEAR);
    return annualYield;
}

function canWithdraw(address user, address token) public view returns (bool) {
    UserDeposit memory userDeposit = userDeposits[user][token];
    if (userDeposit.amount == 0) return false;
    return (block.timestamp - userDeposit.timestamp) >= LOCK_PERIOD;
}

function getUserDeposit(address user, address token) external view returns (uint256 amount, uint256 timestamp, uint256 canWithdrawNow) {
    UserDeposit memory userDeposit = userDeposits[user][token];
    return (userDeposit.amount, userDeposit.timestamp, canWithdraw(user, token));

}

function getTimeUntilWithdraw(address user, address token) external view returns (uint256 amount, uint256 timestamp, bool canWithdrawNow) {
    UserDeposit memory userDeposit = userDeposits[user][token];
    if( userDeposit.amount == 0) return (0, 0, false);
    uint256 unlockTime = userDeposit.timestamp + LOCK_PERIOD;
    if(block.timestamp >= unlockTime) return (0, 0, true);
    return (unlockTime - block.timestamp, unlockTime, false);
}
//Update strategy vault address 
function setStrategyVault(address _strategyVault) external onlyOwner {
   strategyVault = IStrategyVault(_strategyVault);
}
struct UserDeposit {
    uint256 amount;
    uint256 timestamp;
    uint256 lastYieldClaim; 
}
//REceive ETh
receive() external payable {
    // Allow contract to receive ETH
}   // Allow contract to receive ETH
}
