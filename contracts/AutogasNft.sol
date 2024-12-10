// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//Uniswap V3 quoter interface
interface IUniswapV3Quoter {
    function quoteExactInputSingle(
        address tokenIn,
        address tokenOut,
        uint24 fee,
        uint256 amountIn,
        uint160 sqrtPriceLimitX96
    ) external returns (uint256 amountOut);
}

// Extended router interface for price checking


interface IUniswapV2Router02 {
    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function getAmountsOut(
        uint amountIn, 
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
}

interface ISafeWallet {
    function deposit(uint256 amount) external;
}

interface ISpeedToken {
    function transfer(address recipient, uint256 amount) external returns (bool);
}

contract AutoGasNFT is ERC1155, Ownable, ReentrancyGuard {
    // Pricing Constants
    uint256 public constant BASE_USD_PRICE = 100 * 10**18; // $100

    // Mint Parameters
    uint256 public constant BASE_PRICE = 100 * 10**18; // $100 in wei
    uint256 public constant TEAM_FEE_PERCENTAGE = 5;
    uint256 public constant REFERRAL_DISCOUNT_PERCENTAGE = 5;
    uint256 public constant BULK_DISCOUNT_PERCENTAGE = 10;
    uint256 public constant BULK_DISCOUNT_THRESHOLD = 100;

    // Token Addresses
    IERC20 public coreToken;
    ISpeedToken public speedToken;
    IUniswapV2Router02 public uniswapRouter;
    IERC20 public usdcToken;
    IUniswapV3Quoter public v3Quoter;
    ISafeWallet public treasuryWallet;

      // Dynamic Pricing Variables
    uint256 public mintPriceETH;  // Price in ETH to mint
    uint256 public mintPriceCore;  // Price in Core tokens to mint
    uint256 public lastPriceUpdateTimestamp;

    // Pricing Pools (to be configured)
    address public constant WETH_USDC_POOL = address(0); // Highest volume V3 pool
    uint24 public constant POOL_FEE = 3000; // 0.3% fee tier


    // Wallet Addresses
    address public teamWallet;
    // Conversion Addresses
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    struct StrategicPurchase {
        uint256 totalAmount;
        uint256 initialPurchaseAmount;  // 60%
        uint256 secondPurchaseAmount;   // 30%
        uint256 finalPurchaseAmount;    // 10%
        uint256 initialPurchaseTimestamp;
        bool initialPurchaseComplete;
        bool secondPurchaseComplete;
        bool finalPurchaseComplete;
    }

     enum PaymentType {
        ETH,
        USDC,
        CORE
    }

     mapping(uint256 => StrategicPurchase) public strategicPurchases;
    uint256 public strategicPurchaseCounter;

    // Referral Tracking
    mapping(address => string) public userReferralCodes;
    mapping(string => address) public referralCodeToAddress;
    mapping(address => address) public userReferrerMapping;
    mapping(address => bool) public referralCodeLocked;
    mapping(address => address[]) public userDelegationAddresses;

    // NFT Tracking
    uint256 public constant NFT_ID = 1; // Single NFT type for open edition
    uint256 public totalMinted;

    // Events
    event NFTMinted(address indexed to, uint256 quantity, uint256 price);
    event CorePurchased(uint256 amount);
    event SpeedTokenDistributed(address indexed recipient, uint256 amount);
    event DelegationAddressUpdated(address indexed user, address[] delegationAddresses);
    event StrategicPurchaseInitiated(uint256 indexed purchaseId, uint256 totalAmount);
    event StrategicPurchaseStageCompleted(
        uint256 indexed purchaseId, 
        uint256 stageAmount, 
        uint256 tokenAmountReceived
    );

   constructor(
     address _v3Quoter,
    address _teamWallet,
    address _coreTokenAddress,
    address _speedTokenAddress,
    address _uniswapRouterAddress,
    address _treasuryWalletAddress
) ERC1155("https://autogas.xyz/nft/{id}.json") Ownable(msg.sender) {
    v3Quoter = IUniswapV3Quoter(_v3Quoter);
    teamWallet = _teamWallet;
    coreToken = IERC20(_coreTokenAddress);
    speedToken = ISpeedToken(_speedTokenAddress);
    uniswapRouter = IUniswapV2Router02(_uniswapRouterAddress);
    treasuryWallet = ISafeWallet(_treasuryWalletAddress);

    // Initial price update
        updateMintPrices();
}

function updateMintPrices() public {
        // Update ETH Price in USD
        uint256 ethPriceInUSD = getETHPriceInUSD();
        mintPriceETH = BASE_USD_PRICE * 10**18 / ethPriceInUSD;

        // Update Core Token Price in USD
        uint256 corePriceInUSD = getCorePriceInUSD();
        mintPriceCore = BASE_USD_PRICE * 10**18 / corePriceInUSD;

        lastPriceUpdateTimestamp = block.timestamp;
    }

    function getETHPriceInUSD() public  returns (uint256) {
        // Use Uniswap V3 Quoter to get ETH/USDC price
        // 1 WETH input to get USDC out
        try v3Quoter.quoteExactInputSingle(
            WETH, 
            USDC, 
            POOL_FEE, 
            10**18,  // 1 ETH
            0  // No price limit
        ) returns (uint256 usdcAmount) {
            return usdcAmount;
        } catch {
            // Fallback to V2 router if V3 fails
            address[] memory path = new address[](2);
            path[0] = WETH;
            path[1] = USDC;
            uint[] memory amounts = uniswapRouter.getAmountsOut(10**18, path);
            return amounts[1];
        }
    }

    function getCorePriceInUSD() public view returns (uint256) {
        // Similar approach for Core token pricing
        address[] memory path = new address[](3);
        path[0] = address(coreToken);
        path[1] = WETH;
        path[2] = USDC;
        
        uint[] memory amounts = uniswapRouter.getAmountsOut(10**18, path);
        return amounts[2];
    }


function initiateStrategicTokenPurchase(uint256 totalAmount) external onlyOwner {
        require(totalAmount > 0, "Invalid total amount");
        
        // Calculate stage amounts
        uint256 initialAmount = (totalAmount * 60) / 100;
        uint256 secondAmount = (totalAmount * 30) / 100;
        uint256 finalAmount = totalAmount - initialAmount - secondAmount;
        
        // Create strategic purchase
        StrategicPurchase memory newPurchase = StrategicPurchase({
            totalAmount: totalAmount,
            initialPurchaseAmount: initialAmount,
            secondPurchaseAmount: secondAmount,
            finalPurchaseAmount: finalAmount,
            initialPurchaseTimestamp: block.timestamp,
            initialPurchaseComplete: false,
            secondPurchaseComplete: false,
            finalPurchaseComplete: false
        });
        
        uint256 purchaseId = strategicPurchaseCounter++;
        strategicPurchases[purchaseId] = newPurchase;
        
        emit StrategicPurchaseInitiated(purchaseId, totalAmount);
    }

function executeFirstPurchaseStage(uint256 purchaseId) external {
        StrategicPurchase storage purchase = strategicPurchases[purchaseId];
        
        require(!purchase.initialPurchaseComplete, "First stage already complete");
        require(block.timestamp >= purchase.initialPurchaseTimestamp, "Too early for first purchase");
        
        // Perform first token swap (60%)
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(coreToken);
        
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: purchase.initialPurchaseAmount}(
            0, // Minimal output (slippage protection in frontend)
            path,
            address(this),
            block.timestamp + 300 // 5 minutes deadline
        );
        
        // Mark first stage complete
        purchase.initialPurchaseComplete = true;
        
        emit StrategicPurchaseStageCompleted(purchaseId, purchase.initialPurchaseAmount, amounts[1]);
    }

function executeSecondPurchaseStage(uint256 purchaseId) external {
        StrategicPurchase storage purchase = strategicPurchases[purchaseId];
        
        require(purchase.initialPurchaseComplete, "First stage not complete");
        require(!purchase.secondPurchaseComplete, "Second stage already complete");
        require(block.timestamp >= purchase.initialPurchaseTimestamp + 5 minutes, "Too early for second purchase");
        
        // Perform second token swap (30%)
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(coreToken);
        
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: purchase.secondPurchaseAmount}(
            0, // Minimal output (slippage protection in frontend)
            path,
            address(this),
            block.timestamp + 300 // 5 minutes deadline
        );
        
        // Mark second stage complete
        purchase.secondPurchaseComplete = true;
        
        emit StrategicPurchaseStageCompleted(purchaseId, purchase.secondPurchaseAmount, amounts[1]);
    }

    function executeFinalPurchaseStage(uint256 purchaseId) external {
        StrategicPurchase storage purchase = strategicPurchases[purchaseId];
        
        require(purchase.secondPurchaseComplete, "Second stage not complete");
        require(!purchase.finalPurchaseComplete, "Final stage already complete");
        require(block.timestamp >= purchase.initialPurchaseTimestamp + 10 minutes, "Too early for final purchase");
        
        // Perform final token swap (10%)
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(coreToken);
        
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: purchase.finalPurchaseAmount}(
            0, // Minimal output (slippage protection in frontend)
            path,
            address(this),
            block.timestamp + 300 // 5 minutes deadline
        );
        
        // Mark final stage complete and deposit to treasury
        purchase.finalPurchaseComplete = true;
        
        // Approve and deposit total tokens to treasury
        uint256 totalTokens = coreToken.balanceOf(address(this));
        coreToken.approve(address(treasuryWallet), totalTokens);
        treasuryWallet.deposit(totalTokens);
        
        emit StrategicPurchaseStageCompleted(purchaseId, purchase.finalPurchaseAmount, amounts[1]);
    }

    // View function to check strategic purchase status
    function getStrategicPurchaseStatus(uint256 purchaseId) external view returns (
        uint256 totalAmount,
        bool initialPurchaseComplete,
        bool secondPurchaseComplete,
        bool finalPurchaseComplete
    ) {
        StrategicPurchase memory purchase = strategicPurchases[purchaseId];
        return (
            purchase.totalAmount,
            purchase.initialPurchaseComplete,
            purchase.secondPurchaseComplete,
            purchase.finalPurchaseComplete
        );
    }

    function mintNFT(
        uint256 quantity,
        PaymentType paymentType, 
        string memory referralCode, 
        address[] memory delegationAddresses
    ) public payable nonReentrant {
        require(quantity > 0, "Quantity must be greater than 0");uint256 requiredPayment;
        if (paymentType == PaymentType.ETH) {
            requiredPayment = mintPriceETH * quantity;
            require(msg.value >= requiredPayment, "Insufficient ETH");
        } else if (paymentType == PaymentType.USDC) {
            requiredPayment = BASE_USD_PRICE * quantity;
            usdcToken.transferFrom(msg.sender, address(this), requiredPayment);
        } else if (paymentType == PaymentType.CORE) {
            requiredPayment = mintPriceCore * quantity;
            coreToken.transferFrom(msg.sender, address(this), requiredPayment);
        }

        
        // Calculate total price with discounts
        uint256 totalPrice = calculateMintPrice(quantity, referralCode);
        require(msg.value >= totalPrice, "Insufficient payment");
        
        // Handle financial distribution
        distributePayment(totalPrice, quantity, referralCode);
        
        // Mint NFTs
        _mint(msg.sender, NFT_ID, quantity, "");
        totalMinted += quantity;
        
        // Manage delegation addresses
        if (delegationAddresses.length > 0) {
            updateDelegationAddresses(msg.sender, delegationAddresses);
        }
        
        // Refund excess payment
        if (msg.value > totalPrice) {
            payable(msg.sender).transfer(msg.value - totalPrice);
        }
        
        emit NFTMinted(msg.sender, quantity, totalPrice);
    }
    
    // Conversion and payout functions
    function convertToETH(IERC20 token, uint256 amount) internal returns (uint256) {
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = WETH;
        
        uint[] memory amounts = uniswapRouter.swapExactTokensForETH(
            amount,
            0,  // Accept any amount
            path,
            address(this),
            block.timestamp + 300
        );
        
        return amounts[1];  // Return ETH amount
    }

    function calculateMintPrice(
        uint256 quantity, 
        string memory referralCode
    ) public view returns (uint256) {
        uint256 baseTotal = BASE_PRICE * quantity;
        
        // Bulk discount for 100+ NFTs (disables referral)
        if (quantity >= BULK_DISCOUNT_THRESHOLD) {
            return baseTotal * (100 - BULK_DISCOUNT_PERCENTAGE) / 100;
        }
        
        // Referral discount
        if (bytes(referralCode).length > 0) {
            address referrer = referralCodeToAddress[referralCode];
            if (referrer != address(0) && referrer != msg.sender) {
                return baseTotal * (100 - REFERRAL_DISCOUNT_PERCENTAGE) / 100;
            }
        }
        
        return baseTotal;
    }
    
    function distributePayment(
        uint256 totalPrice, 
        uint256 quantity, 
        string memory referralCode
    ) internal {
        // Team wallet fee (5%)
        uint256 teamFee = totalPrice * TEAM_FEE_PERCENTAGE / 100;
        payable(teamWallet).transfer(teamFee);
        
        // Referral logic (for < 100 NFTs)
        if (quantity < BULK_DISCOUNT_THRESHOLD && bytes(referralCode).length > 0) {
            address referrer = referralCodeToAddress[referralCode];
            
            if (referrer != address(0) && referrer != msg.sender) {
                // 5% to referrer
                uint256 referrerAmount = totalPrice * REFERRAL_DISCOUNT_PERCENTAGE / 100;
                payable(referrer).transfer(referrerAmount);
            }
        }
        
        // Remaining 85% for Core token purchase and treasury
        uint256 remainingFunds = totalPrice * 85 / 100;
        purchaseCoreTokens(remainingFunds);
    }
    
    function purchaseCoreTokens(uint256 amount) internal {
        // Swap ETH for Core tokens via Uniswap
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = address(coreToken);
        
        uint[] memory amounts = uniswapRouter.swapExactETHForTokens{value: amount}(
            0, // Accept any amount 
            path,
            address(this),
            block.timestamp + 300 // 5 minutes deadline
        );
        
        // Deposit Core tokens to treasury
        uint256 coreAmount = amounts[1];
        coreToken.approve(address(treasuryWallet), coreAmount);
        treasuryWallet.deposit(coreAmount);
        
        emit CorePurchased(coreAmount);
    }
    
    function distributeSpeeds(address[] memory recipients, uint256[] memory amounts) external onlyOwner {
        require(recipients.length == amounts.length, "Mismatched arrays");
        
        for (uint256 i = 0; i < recipients.length; i++) {
            speedToken.transfer(recipients[i], amounts[i]);
            emit SpeedTokenDistributed(recipients[i], amounts[i]);
        }
    }
    
    function updateDelegationAddresses(
        address user, 
        address[] memory delegationAddresses
    ) public {
        // Clear existing delegation addresses
        delete userDelegationAddresses[user];
        
        // Add new delegation addresses
        for (uint256 i = 0; i < delegationAddresses.length; i++) {
            require(delegationAddresses[i] != address(0), "Invalid address");
            userDelegationAddresses[user].push(delegationAddresses[i]);
        }
        
        emit DelegationAddressUpdated(user, delegationAddresses);
    }
    
    function getUserDelegationAddresses(address user) external view returns (address[] memory) {
        return userDelegationAddresses[user];
    }
    
    // Withdraw function for contract owner
    function withdraw() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }
    
    // URI management for NFT metadata
    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }
}