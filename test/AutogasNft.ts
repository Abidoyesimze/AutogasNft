
import { expect } from "chai";
import { ethers } from 'hardhat';
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe('AutoGasNFT', function () {
    let autoGasNFT;
    // let owner, teamWallet, user1, user2;

    const BASE_USD_PRICE = 100n * 10n ** 18n; // $100
    // Update the contract addresses
    const UNISWAP_V3_QUOTER = '0xb27308f9f87f9e81e126d570d338838f1df45677';
    const UNISWAP_V2_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    const ETH_PRICE_FEED_ADDRESS = '0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419';
    const CORE_PRICE_FEED_ADDRESS = '0x2c1d9daef2b8ee8070ce12de007d1ba7bfa1d4dd';
    const USDC_PRICE_FEED_ADDRESS = '0x8fffffd4afb6115b954bd326caf7a64730d22d1a';
    const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const USDC = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';

    async function deployMockToken() {
        const [owner, teamWallet, user1, user2] = await ethers.getSigners();

        // Deploy mock tokens
        const MockToken = await ethers.getContractFactory('MockERC20');
        const coreToken = await MockToken.deploy('CoreToken', 'CORE', ethers.parseEther('1000000'));
        const coreTokenAddress = await coreToken.getAddress() 

        const speedToken = await MockToken.deploy('SpeedToken', 'SPEED', ethers.parseEther('1000000'));
        const speedTokenAddress = await speedToken.getAddress() 

        const usdcToken = await MockToken.deploy('USD Coin', 'USDC', ethers.parseUnits('1000000', 6));
        const usdcTokenAddress = await usdcToken.getAddress() 

        // Deploy SafeWallet mock
        const SafeWallet = await ethers.getContractFactory('SafeWallet');
        const treasuryWallet = await SafeWallet.deploy();
        const treasuryWalletAddress = await treasuryWallet.getAddress()

        // Deploy the main contract
        const AutoGasNFT = await ethers.getContractFactory('AutoGasNFT');
        autoGasNFT = await AutoGasNFT.deploy(
            UNISWAP_V3_QUOTER,
            teamWallet.address,
            coreTokenAddress,
            speedTokenAddress,
            UNISWAP_V2_ROUTER,
            ETH_PRICE_FEED_ADDRESS,
            CORE_PRICE_FEED_ADDRESS,
            USDC_PRICE_FEED_ADDRESS,
            treasuryWalletAddress
        );
        
        // Prepare tokens for users
        await coreToken.transfer(user1.address, ethers.parseEther('1000'));
        await usdcToken.transfer(user1.address, ethers.parseUnits('1000', 6));
        
        // Approve tokens for contract
        await coreToken.connect(user1).approve(await autoGasNFT.getAddress(), ethers.parseEther('1000'));
        await usdcToken.connect(user1).approve(await autoGasNFT.getAddress(), ethers.parseUnits('1000', 6));

        return {
            autoGasNFT, 
            teamWallet, 
            owner, 
            user1, 
            user2, 
            coreToken, 
            speedToken, 
            usdcToken, 
            treasuryWallet
        };
    }

    describe.only("Deployment", function () {
        it("Should initialize price feeds correctly", async function () {
            const {autoGasNFT} = await loadFixture (deployMockToken);
          const ethPrice = await autoGasNFT.getETHPriceInUSD();
          const corePrice = await autoGasNFT.getCorePriceInUSD();
          
          expect(ethPrice).to.equal(ETH_PRICE_FEED_ADDRESS);
          expect(corePrice).to.equal(CORE_PRICE_FEED_ADDRESS);
        });
      });

    describe("Minting NFTs", function () {
        it("should mint NFTs using ETH", async function () {
            const {autoGasNFT, user1} = await loadFixture(deployMockToken);
            const quantity = 1;
            const paymentType = 0; // ETH
            const referralCode = "";
            const delegationAddresses: string[] = [];
    
            const price = await autoGasNFT.mintPriceETH(); // Get the mint price
            const totalPrice = BigInt(price) * BigInt(quantity);

    
            await expect(autoGasNFT.connect(user1).mintNFT(quantity, paymentType, referralCode, delegationAddresses, { value: totalPrice }))
            .to.emit(autoGasNFT, "NFTMinted")
            .withArgs(await user1.getAddress(), quantity, totalPrice);
        });


it('Should apply referral discount', async function () {
            const {autoGasNFT, user1, user2} = await loadFixture(deployMockToken);
            const quantity = 5;
            const ethPrice = await autoGasNFT.mintPriceETH();
            const baseTotal = ethPrice * BigInt(quantity);
            const discountedPrice = baseTotal * BigInt(95) / BigInt(100); // 5% referral discount

            // First, set up a referral code
            const referralCode = 'TESTREF';
            await autoGasNFT.connect(user2).userReferralCodes(referralCode);

            await expect(
                autoGasNFT.connect(user1).mintNFT(
                    quantity, 
                    0, // PaymentType.ETH 
                    referralCode, 
                    [], 
                    { value: discountedPrice }
                )
            ).to.emit(autoGasNFT, 'NFTMinted');

            const balance = await autoGasNFT.balanceOf(user1.address, 1);
            expect(balance).to.equal(quantity);
        });
    });

    describe('Price Updates', function () {
        it('Should update mint prices', async function () {
            const {autoGasNFT} = await loadFixture(deployMockToken);
            const initialETHPrice = await autoGasNFT.mintPriceETH();
            
            // Trigger price update
            await autoGasNFT.updateMintPrices();

            const updatedETHPrice = await autoGasNFT.mintPriceETH();
            
            // Ensure price has been updated
            expect(updatedETHPrice).to.be.gt(0);
            expect(updatedETHPrice).to.not.equal(initialETHPrice);
        });
    });

    // describe('Strategic Purchase', function () {
    //     it('Should initiate strategic token purchase', async function () {
    //         const {autoGasNFT, owner} = await loadFixture(deployMockToken)
    //         const totalAmount = ethers.parseEther('100');

    //         await expect(autoGasNFT.connect(owner).initiateStrategicTokenPurchase(totalAmount))
    //             .to.emit(autoGasNFT, 'StrategicPurchaseInitiated');

    //         const purchase = await autoGasNFT.getStrategicPurchaseStatus(0);
    //         expect(purchase[0]).to.equal(totalAmount);
    //         expect(purchase[1]).to.be.false; // initialPurchaseComplete
    //     });
    // });

    describe('Delegation Addresses', function () {
        it('Should update delegation addresses', async function () {
            const {autoGasNFT, teamWallet, user1, user2} = await loadFixture(deployMockToken);
            const delegationAddresses = [user2.address, teamWallet.address];

            await expect(
                autoGasNFT.connect(user1).updateDelegationAddresses(
                    user1.address, 
                    delegationAddresses
                )
            ).to.emit(autoGasNFT, 'DelegationAddressUpdated')
            .withArgs(user1.address, delegationAddresses);

            const userDelegations = await autoGasNFT.getUserDelegationAddresses(user1.address);
            expect(userDelegations).to.deep.equal(delegationAddresses);
        });
    });
});

// function address(arg0: string) {
//     throw new Error("Function not implemented.");
// }