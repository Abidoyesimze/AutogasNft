// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title AutoGasNFT
 * @dev Main NFT contract for AutoGas system
 */
contract AutoGasNFT is ERC721Enumerable, Ownable, ReentrancyGuard {
    using Strings for uint256;

    // Pricing and Minting Configuration
    uint256 public constant BASE_PRICE = 100 * 10**18; // $100 in ETH/CORE
    uint256 public constant BULK_DISCOUNT_THRESHOLD = 999;
    uint256 public constant BULK_DISCOUNT_PERCENTAGE = 10;

    // NFT Utility Tracking
    struct NFTDetails {
        address[] delegationAddresses;
        uint256 lastGasGenerationTimestamp;
        uint256 gasGenerationCooldown;
    }

    mapping(uint256 => NFTDetails) public nftDetails;
    mapping(uint256 => uint256) public nftMintTimestamp;

    // Payment Tokens
    IERC20 public coreToken;
    address public vaultAddress;

    // Events
    event NFTMinted(address indexed minter, uint256 tokenId);
    event DelegationAddressAdded(uint256 tokenId, address delegationAddress);
    event DelegationAddressRemoved(uint256 tokenId, address delegationAddress);

    constructor(
        string memory _name, 
        string memory _symbol, 
        address _coreTokenAddress
    ) ERC721(_name, _symbol) {
        coreToken = IERC20(_coreTokenAddress);
    }

    /**
     * @dev Mint new AutoGas NFTs with bulk discount logic
     */
    function mint(uint256 quantity) external payable nonReentrant {
        require(quantity > 0, "Quantity must be greater than 0");
        
        uint256 totalPrice = calculatePrice(quantity);
        
        // Accept payment in ETH or CORE
        if (msg.value > 0) {
            require(msg.value >= totalPrice, "Insufficient ETH sent");
            // Refund excess if needed
            if (msg.value > totalPrice) {
                payable(msg.sender).transfer(msg.value - totalPrice);
            }
        } else {
            require(coreToken.transferFrom(msg.sender, vaultAddress, totalPrice), "Payment failed");
        }

        // Mint NFTs
        for (uint256 i = 0; i < quantity; i++) {
            uint256 newTokenId = totalSupply() + 1;
            _safeMint(msg.sender, newTokenId);
            
            // Initialize NFT details
            nftDetails[newTokenId].gasGenerationCooldown = 1 days;
            nftMintTimestamp[newTokenId] = block.timestamp;
            
            emit NFTMinted(msg.sender, newTokenId);
        }
    }

    /**
     * @dev Calculate price with bulk discount
     */
    function calculatePrice(uint256 quantity) public pure returns (uint256) {
        if (quantity > BULK_DISCOUNT_THRESHOLD) {
            return BASE_PRICE * quantity * (100 - BULK_DISCOUNT_PERCENTAGE) / 100;
        }
        return BASE_PRICE * quantity;
    }

    /**
     * @dev Add delegation address for a specific NFT
     */
    function addDelegationAddress(uint256 tokenId, address delegationAddress) external {
        require(_ownerOf(tokenId) == msg.sender, "Not NFT owner");
        require(delegationAddress != address(0), "Invalid address");
        
        NFTDetails storage details = nftDetails[tokenId];
        details.delegationAddresses.push(delegationAddress);
        
        emit DelegationAddressAdded(tokenId, delegationAddress);
    }

    /**
     * @dev Remove a specific delegation address
     */
    function removeDelegationAddress(uint256 tokenId, address delegationAddress) external {
        require(_ownerOf(tokenId) == msg.sender, "Not NFT owner");
        
        NFTDetails storage details = nftDetails[tokenId];
        for (uint256 i = 0; i < details.delegationAddresses.length; i++) {
            if (details.delegationAddresses[i] == delegationAddress) {
                details.delegationAddresses[i] = details.delegationAddresses[details.delegationAddresses.length - 1];
                details.delegationAddresses.pop();
                
                emit DelegationAddressRemoved(tokenId, delegationAddress);
                return;
            }
        }
        revert("Address not found");
    }

    /**
     * @dev Bulk upload delegation addresses via CSV
     */
    function bulkUploadDelegationAddresses(uint256 tokenId, address[] calldata addresses) external {
        require(_ownerOf(tokenId) == msg.sender, "Not NFT owner");
        
        NFTDetails storage details = nftDetails[tokenId];
        details.delegationAddresses = addresses;
    }

    /**
     * @dev Get delegation addresses for an NFT
     */
    function getDelegationAddresses(uint256 tokenId) external view returns (address[] memory) {
        return nftDetails[tokenId].delegationAddresses;
    }

    /**
     * @dev Set the Vault address (only owner)
     */
    function setVaultAddress(address _vaultAddress) external onlyOwner {
        vaultAddress = _vaultAddress;
    }

    /**
     * @dev Validate if NFT can generate gas
     */
    function canGenerateGas(uint256 tokenId) public view returns (bool) {
        NFTDetails storage details = nftDetails[tokenId];
        return block.timestamp >= details.lastGasGenerationTimestamp + details.gasGenerationCooldown;
    }
}

/**
 * @title AutoGasVault
 * @dev Token conversion and distribution vault
 */
contract AutoGasVault is Ownable, ReentrancyGuard {
    // Tokens
    IERC20 public coreToken;
    IERC20 public speedToken;
    
    // Conversion Parameters
    uint256 public conversionBuffer = 5 seconds;
    uint256 public lastConversionTimestamp;

    // Distribution
    uint256 public constant WEEKLY_DISTRIBUTION_INTERVAL = 7 days;
    uint256 public lastDistributionTimestamp;

    // Events
    event ETHToCoreConverted(uint256 amount);
    event SpeedTokensConverted(uint256 amount);
    event TokensDistributed(uint256 ethAmount);

    constructor(
        address _coreTokenAddress, 
        address _speedTokenAddress
    ) {
        coreToken = IERC20(_coreTokenAddress);
        speedToken = IERC20(_speedTokenAddress);
    }

    /**
     * @dev Convert received ETH to CORE with slippage management
     */
    function convertETHToCORE() external nonReentrant {
        require(block.timestamp >= lastConversionTimestamp + conversionBuffer, "Too soon");
        
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH to convert");

        // Implement conversion logic (would integrate with DEX)
        // This is a placeholder for actual conversion mechanism
        uint256 convertedAmount = performConversion(ethBalance);
        
        lastConversionTimestamp = block.timestamp;
        emit ETHToCoreConverted(convertedAmount);
    }

    /**
     * @dev Convert Speed tokens to ETH for distribution
     */
    function convertSpeedToETH() external nonReentrant {
        require(block.timestamp >= lastDistributionTimestamp + WEEKLY_DISTRIBUTION_INTERVAL, "Too soon");
        
        uint256 speedBalance = speedToken.balanceOf(address(this));
        require(speedBalance > 0, "No Speed tokens");

        // Implement Speed to ETH conversion
        uint256 convertedEthAmount = performSpeedConversion(speedBalance);
        
        lastDistributionTimestamp = block.timestamp;
        emit SpeedTokensConverted(convertedEthAmount);
    }

    /**
     * @dev Placeholder for actual conversion logic
     */
    function performConversion(uint256 amount) internal returns (uint256) {
        // TODO: Integrate with DEX for actual conversion
        return amount;
    }

    /**
     * @dev Placeholder for Speed token conversion
     */
    function performSpeedConversion(uint256 amount) internal returns (uint256) {
        // TODO: Integrate with DEX for Speed to ETH conversion
        return amount;
    }

    /**
     * @dev Distribute converted ETH to delegated addresses
     */
    function distributeETH(address[] calldata addresses) external nonReentrant {
        uint256 totalAddresses = addresses.length;
        require(totalAddresses > 0, "No addresses");

        uint256 contractBalance = address(this).balance;
        uint256 amountPerAddress = contractBalance / totalAddresses;

        for (uint256 i = 0; i < totalAddresses; i++) {
            payable(addresses[i]).transfer(amountPerAddress);
        }

        emit TokensDistributed(contractBalance);
    }

    /**
     * @dev Migrate vault to a new contract if needed
     */
    function migrate(address newVaultAddress) external onlyOwner {
        // Transfer remaining tokens and ETH
        uint256 coreBalance = coreToken.balanceOf(address(this));
        uint256 speedBalance = speedToken.balanceOf(address(this));
        uint256 ethBalance = address(this).balance;

        if (coreBalance > 0) coreToken.transfer(newVaultAddress, coreBalance);
        if (speedBalance > 0) speedToken.transfer(newVaultAddress, speedBalance);
        if (ethBalance > 0) payable(newVaultAddress).transfer(ethBalance);
    }

    // Fallback to receive ETH
    receive() external payable {}
}