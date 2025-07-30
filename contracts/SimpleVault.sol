//SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IStrategyVault {
    function deposit(address token, uint256 amount) external;
    function withdraw(address token, uint256 amount) external returns (uint256);
    function getBalance(address token) external view returns (uint256);
}

struct UserDeposit {
    uint256 amount;
    uint256 timestamp;
    uint256 lastYieldClaim; 
}

contract SimpleVault is ReentrancyGuard, Ownable, Pausable {
    using SafeERC20 for IERC20;

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

    // Add state variable
    mapping(address => uint256) public pendingWithdrawals;

    //Events declaration
    event Deposited(address indexed user, address indexed token,uint256 amount, uint256 timestamp);
    event Withdrawn(address indexed user, address indexed token, uint256 amount, uint256 yield);
    event AllocatedToStrategy(address indexed token, uint256 amount);
    event YieldClaimed(address indexed user, address indexed token, uint256 yield
    );
    event StrategyVaultUpdated(address indexed oldVault, address indexed newVault);
    event PausedStateChanged(bool isPaused);



    constructor(
        address _usdt, 
        address _strategyVault
    ) {
        require(_usdt != address(0), "Invalid USDT address");
        require(_strategyVault != address(0), "Invalid strategy vault address");
        USDT = IERC20(_usdt);
        strategyVault = IStrategyVault(_strategyVault);
        _transferOwnership(msg.sender);
    }

    // ETH deposit functionality
    function depositETH() external payable nonReentrant {
        require(msg.value > 0, "Amount must be greater than 0");
        address ethToken = address(0);
        userDeposits[msg.sender][ethToken].amount += msg.value;
        userDeposits[msg.sender][ethToken].timestamp = block.timestamp;
        userDeposits[msg.sender][ethToken].lastYieldClaim = block.timestamp;

        totalDeposits[ethToken] += msg.value;
        emit Deposited(msg.sender, ethToken, msg.value, block.timestamp);  // Fixed incomplete event emission
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
function pause() external onlyOwner {
    _pause();
}

function unpause() external onlyOwner {
    _unpause();
}

    function canWithdraw(address user, address token) public view returns (bool) {
        UserDeposit memory userDeposit = userDeposits[user][token];
        if (userDeposit.amount == 0) return false;
        return (block.timestamp - userDeposit.timestamp) >= LOCK_PERIOD;
    }

    function getClaimableYield(address user, address token) public view returns (uint256) {
        UserDeposit memory userDeposit = userDeposits[user][token];
        if (userDeposit.amount == 0) return 0;

        uint256 timeHeld = block.timestamp - userDeposit.lastYieldClaim;
        uint256 annualYield = (userDeposit.amount * FIXED_APY * timeHeld) / (BASIS_POINTS * SECS_PER_YEAR);
        return annualYield;
    }

    //Withdraw function with yield calculation
    function withdraw(address token) external nonReentrant whenNotPaused {
        UserDeposit storage userDeposit = userDeposits[msg.sender][token];
        require(userDeposit.amount > 0, "No deposit found");
        require(canWithdraw(msg.sender, token), "Withdrawal not allowed yet");
        
        uint256 principal = userDeposit.amount;
        uint256 yield = getClaimableYield(msg.sender, token);
        uint256 totalAmount = principal + yield;
        
        userDeposit.amount = 0;
        userDeposit.timestamp = 0;
        userDeposit.lastYieldClaim = 0;
        
        totalDeposits[token] -= principal;
        
        if (token == address(0)) {
            pendingWithdrawals[msg.sender] = totalAmount;
        } else {
            IERC20(token).safeTransfer(msg.sender, totalAmount);
        }
        
        emit Withdrawn(msg.sender, token, principal, yield);
    }

    // Function to withdraw pending ETH
    function withdrawPendingETH() external nonReentrant whenNotPaused {
        uint256 amount = pendingWithdrawals[msg.sender];
        require(amount > 0, "No pending withdrawal");
        pendingWithdrawals[msg.sender] = 0;
        (bool success, ) = msg.sender.call{value: amount}("");
        require(success, "ETH transfer failed");
    }

    // Receive function to accept ETH
    receive() external payable {
        // Allow contract to receive ETH
    }
}