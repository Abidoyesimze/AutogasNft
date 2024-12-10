import { expect } from "chai";
import { ethers } from 'hardhat';
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe('AutoGasNFT', function () {
    let autoGasNFT: any;
    let owner: any, teamWallet: any, user1: any, user2: any;

    // Mainnet contract addresses (as constants without getAddress())
    const UNISWAP_V3_QUOTER = '0xb27308f9F87F9e81E126D570D338838f1dF45677';
    const UNISWAP_V2_ROUTER = '0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D';
    const WETH = '0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2';
    const USDC = '0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48';

    async function deployMockToken() {
        const [owner, teamWallet, user1, user2] = await ethers.getSigners();

        // Deploy mock tokens
        const MockToken = await ethers.getContractFactory('MockERC20');
        const coreToken = await MockToken.deploy('CoreToken', 'CORE', ethers.parseEther('1000000'));
        const speedToken = await MockToken.deploy('SpeedToken', 'SPEED', ethers.parseEther('1000000'));
        const usdcToken = await MockToken.deploy('USD Coin', 'USDC', ethers.parseUnits('1000000', 6));

        // Deploy SafeWallet mock
        const SafeWallet = await ethers.getContractFactory('MockSafeWallet');
        const treasuryWallet = await SafeWallet.deploy();

        // Deploy the main contract
        const AutoGasNFT = await ethers.getContractFactory('AutoGasNFT');
        autoGasNFT = await AutoGasNFT.deploy(
            UNISWAP_V3_QUOTER,
            teamWallet.address,
            await coreToken.getAddress(),
            await speedToken.getAddress(),
            UNISWAP_V2_ROUTER,
            await treasuryWallet.getAddress()
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

    describe('Deployment', function () {
        it('Should set the correct initial parameters', async function () {
            const {autoGasNFT, teamWallet} = await loadFixture(deployMockToken);
            expect(await autoGasNFT.teamWallet()).to.equal(teamWallet.address);
            expect(await autoGasNFT.mintPriceETH()).to.be.gt(0);
            expect(await autoGasNFT.mintPriceCore()).to.be.gt(0);
        });
    });

    describe('Minting', function () {
        it('Should mint NFT with ETH payment', async function () {
            const {autoGasNFT, user1} = await loadFixture(deployMockToken);
            const quantity = 5;
            const ethPrice = await autoGasNFT.mintPriceETH();
            const totalPrice = ethPrice * BigInt(quantity);

            await expect(
                autoGasNFT.connect(user1).mintNFT(
                    quantity, 
                    0, // PaymentType.ETH 
                    '', 
                    [], 
                    { value: totalPrice }
                )
            ).to.emit(autoGasNFT, 'NFTMinted')
            .withArgs(user1.address, quantity, totalPrice);

            const balance = await autoGasNFT.balanceOf(user1.address, 1);
            expect(balance).to.equal(quantity);
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

    describe('Strategic Purchase', function () {
        it('Should initiate strategic token purchase', async function () {
            const {autoGasNFT, owner} = await loadFixture(deployMockToken)
            const totalAmount = ethers.parseEther('100');

            await expect(autoGasNFT.connect(owner).initiateStrategicTokenPurchase(totalAmount))
                .to.emit(autoGasNFT, 'StrategicPurchaseInitiated');

            const purchase = await autoGasNFT.getStrategicPurchaseStatus(0);
            expect(purchase[0]).to.equal(totalAmount);
            expect(purchase[1]).to.be.false; // initialPurchaseComplete
        });
    });

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