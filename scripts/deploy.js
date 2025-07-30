const { ethers } = require("hardhat");
require("dotenv").config();

async function main() {
  try {
    // Check for required environment variables
    if (!process.env.SEPOLIA_RPC_URL) {
      throw new Error("Missing SEPOLIA_RPC_URL in .env file");
    }
    if (!process.env.PRIVATE_KEY) {
      throw new Error("Missing PRIVATE_KEY in .env file");
    }

    // Get the contract factory
    const SimpleVault = await ethers.getContractFactory("SimpleVault");

    // Deploy USDT Mock for testing (you should replace this with actual USDT address for mainnet)
    const USDTMock = await ethers.getContractFactory("MockUSDT");
    const usdt = await USDTMock.deploy();
    await usdt.deployed();
    console.log("Mock USDT deployed to:", usdt.address);

    // Deploy Strategy Vault Mock (replace with actual strategy vault for production)
    const StrategyVaultMock = await ethers.getContractFactory("MockStrategyVault");
    const strategyVault = await StrategyVaultMock.deploy();
    await strategyVault.deployed();
    console.log("Mock Strategy Vault deployed to:", strategyVault.address);

    // Deploy SimpleVault with constructor arguments
    const simpleVault = await SimpleVault.deploy(
      usdt.address,
      strategyVault.address
    );
    await simpleVault.deployed();

    console.log("SimpleVault deployed to:", simpleVault.address);

    // Verify contract on Etherscan
    if (process.env.ETHERSCAN_API_KEY) {
      console.log("Waiting for block confirmations...");
      await simpleVault.deployTransaction.wait(6);
      await verify(simpleVault.address, [usdt.address, strategyVault.address]);
    }

  } catch (error) {
    console.error("Deployment failed:", error.message);
    process.exitCode = 1;
  }
}

async function verify(contractAddress, args) {
  console.log("Verifying contract...");
  try {
    await run("verify:verify", {
      address: contractAddress,
      constructorArguments: args,
    });
  } catch (e) {
    if (e.message.toLowerCase().includes("already verified")) {
      console.log("Contract is already verified!");
    } else {
      console.log(e);
    }
  }
}

// Execute deployment
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});