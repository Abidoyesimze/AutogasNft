// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
import "./AutogasNft.sol";
/**
 * @title AutoGasVault
  Token conversion and distribution vault
 */
contract AutoGasVault is Ownable, ReentrancyGuard {
    // Tokens
    IERC20 public coreToken;
    IERC20 public speedToken;
    IUniswapV2Router02 public uniswapRouter;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Mainnet WETH

    
    // Conversion Parameters
    uint256 public conversionBuffer = 5 seconds;
    uint256 public lastConversionTimestamp;

    // Distribution
    uint256 public constant WEEKLY_DISTRIBUTION_INTERVAL = 7 days;
    uint256 public lastDistributionTimestamp;

    // Addresses
    address public nftContract;

    // Events
    event ETHToCoreConverted(uint256 amount);
    event SpeedTokensConverted(uint256 amount);
    event TokensDistributed(uint256 ethAmount);

    constructor(
        address _coreTokenAddress, 
        address _speedTokenAddress,
        address _uniswapRouterAddress,
        address _nftContract
    ) Ownable(msg.sender) {
        coreToken = IERC20(_coreTokenAddress);
        speedToken = IERC20(_speedTokenAddress);
        uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
        nftContract = _nftContract;
    }

    /**
     Convert received ETH to CORE with slippage management
     */
    function convertETHToCORE() external nonReentrant {
        require(block.timestamp >= lastConversionTimestamp + conversionBuffer, "Too soon");
        
        uint256 ethBalance = address(this).balance;
        require(ethBalance > 0, "No ETH to convert");

        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(coreToken);

        uint256 convertedAmount = uniswapRouter.swapExactETHForTokens{value: ethBalance}(
            0, // Accept any amount
            path,
            address(this),
            block.timestamp + 300 // 5 minutes deadline
        )[1];
        
        lastConversionTimestamp = block.timestamp;
        emit ETHToCoreConverted(convertedAmount);
    }

    /**
      Convert Speed tokens to ETH for distribution
     */
    function convertSpeedToETH() external nonReentrant {
        require(block.timestamp >= lastDistributionTimestamp + WEEKLY_DISTRIBUTION_INTERVAL, "Too soon");
        
        uint256 speedBalance = speedToken.balanceOf(address(this));
        require(speedBalance > 0, "No Speed tokens");

        address[] memory path = new address[](2);
        path[0] = address(speedToken);
        path[1] = WETH;

        uint256 convertedEthAmount = uniswapRouter.swapExactTokensForETH(
            speedBalance,
            0, // Accept any amount
            path,
            address(this),
            block.timestamp + 300 // 5 minutes deadline
        )[1];
        
        lastDistributionTimestamp = block.timestamp;
        emit SpeedTokensConverted(convertedEthAmount);
    }

    /**
      Distribute converted ETH to NFT holders or their designated addresses
     */
    function distributeETH() external nonReentrant {
        uint256 contractBalance = address(this).balance;
        require(contractBalance > 0, "No ETH to distribute");

        
        emit TokensDistributed(contractBalance);
    }

    
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