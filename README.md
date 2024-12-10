# AutoGas Web3 Project

## Overview

The AutoGas project is a blockchain-based ecosystem featuring two primary smart contracts: AutogasNFT and AutogasVault. These contracts work together to create a unique NFT-based system with advanced tokenomics and distribution mechanisms.

## Contracts

### 1. AutogasNFT Contract

#### Features
- ERC1155 Multi-Token Standard Implementation
- Flexible NFT Minting with Multiple Pricing Strategies
- Referral and Bulk Discount Systems
- Automated Token Purchasing and Distribution

#### Key Functions

##### `mintNFT(uint256 quantity, string memory referralCode, address[] memory delegationAddresses)`
- Mint AutoGas NFTs with flexible parameters
- Supports referral discounts
- Allows multiple delegation addresses
- Handles payment distribution automatically

##### Pricing Mechanism
- Base Price: $100 per NFT
- Referral Discount: 5% off for referred mints
- Bulk Discount: 10% off for 100+ NFT purchases
- Team Fee: 5% of total mint value goes to team wallet

##### Token Interactions
- Automatically purchases Core tokens via Uniswap
- Deposits Core tokens to treasury wallet
- Optional Speed token distribution

#### Constructor Parameters
- `_teamWallet`: Address for team fee collection
- `_coreTokenAddress`: Core token contract address
- `_speedTokenAddress`: Speed token contract address
- `_uniswapRouterAddress`: Uniswap router for token swaps
- `_treasuryWalletAddress`: Safe wallet for token deposits

### 2. AutogasVault Contract

#### Features
- Token Conversion Vault
- ETH to CORE Token Conversion
- Speed Token to ETH Conversion
- Periodic Token Distribution
- Migration Capability

#### Key Functions

##### `convertETHToCORE()`
- Converts contract's ETH balance to CORE tokens
- Uses Uniswap for token swapping
- Implements a conversion buffer to prevent frequent conversions

##### `convertSpeedToETH()`
- Converts accumulated Speed tokens to ETH
- Supports weekly distribution intervals
- Uses Uniswap for token swapping

##### `distributeETH()`
- Distributes converted ETH to NFT holders
- Placeholder for future NFT holder distribution logic

##### `migrate(address newVaultAddress)`
- Allows owner to migrate vault to a new contract
- Transfers remaining tokens and ETH

#### Constructor Parameters
- `_coreTokenAddress`: Core token contract address
- `_speedTokenAddress`: Speed token contract address
- `_uniswapRouterAddress`: Uniswap router for token swaps
- `_nftContract`: AutogasNFT contract address

## Security Considerations
- Uses OpenZeppelin's security libraries
- Implements ReentrancyGuard
- Ownable pattern for contract management
- Slippage protection in token swaps

## Installation

### Prerequisites
- Hardhat
- OpenZeppelin Contracts
- Solidity ^0.8.20

