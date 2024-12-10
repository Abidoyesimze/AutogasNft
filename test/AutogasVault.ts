// import { expect } from "chai";
// import hre,{ ethers } from "hardhat";
// import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
// import {loadFixture} from "@nomicfoundation/hardhat-toolbox/network-helpers";


// describe("AutoGasVault", function () {
//   let owner;
//   let addr1;
//   let addr2;
  
//   let coreToken: any;
//   let speedToken: any;
//   let uniswapRouter: any;
//   let nftContract: any;
//   let autoGasVault: any;

//   // Mock WETH address (same as in the contract)
//   const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";

//   async function deployMockToken() {
//     // Get signers
//     const [owner, addr1, addr2] = await hre.ethers.getSigners();

//     const MockTokenFactory = await hre.ethers.getContractFactory("MockERC20");
//     coreToken = await MockTokenFactory.deploy("CoreToken", "CORE", ethers.parseEther("1000000"));
//     speedToken = await MockTokenFactory.deploy("SpeedToken", "SPEED", ethers.parseEther("1000000"));

//     // Deploy mock Uniswap router
//     const MockUniswapRouterFactory = await ethers.getContractFactory("MockUniswapV2Router02");
//     uniswapRouter = await MockUniswapRouterFactory.deploy();
    

//     // Deploy mock NFT contract
//     const MockNFTFactory = await ethers.getContractFactory("AutogasNft");
//     nftContract = await MockNFTFactory.deploy();

//     // Deploy AutoGasVault
//     const AutoGasVaultFactory = await hre.ethers.getContractFactory("AutoGasVault");
//     autoGasVault = await AutoGasVaultFactory.deploy(
//       await coreToken.getAddress(),
//       await speedToken.getAddress(),
//       await uniswapRouter.getAddress(),
//       await nftContract.getAddress()
      
//     );
//     return {owner, addr1, addr2}
//   };

//   describe("Deployment", function () {
//     it("Should set the right owner", async function () {
//         const {owner} = await loadFixture (deployMockToken);
//       expect(await autoGasVault.owner()).to.equal(await owner.getAddress());
//     });

//     it("Should set the correct token and router addresses", async function () {
//       expect(await autoGasVault.coreToken()).to.equal(await coreToken.getAddress());
//       expect(await autoGasVault.speedToken()).to.equal(await speedToken.getAddress());
//       expect(await autoGasVault.uniswapRouter()).to.equal(await uniswapRouter.getAddress());
//       expect(await autoGasVault.nftContract()).to.equal(await nftContract.getAddress());
//     });
//   });

//   describe("ETH to CORE Conversion", function () {
//     it("Should revert if conversion buffer not passed", async function () {
//         const {owner} = await loadFixture (deployMockToken);
//       // Send some ETH to the contract
//       await owner.sendTransaction({
//         to: await autoGasVault.getAddress(),
//         value: ethers.parseEther("1")
//       });

//       // First conversion should work
//       await autoGasVault.convertETHToCORE();

//       // Second conversion should revert due to conversion buffer
//       await expect(autoGasVault.convertETHToCORE()).to.be.revertedWith("Too soon");
//     });

//     it("Should convert ETH to CORE tokens", async function () {
//         const {owner} = await loadFixture (deployMockToken);
//       // Send some ETH to the contract
//       const ethAmount = ethers.parseEther("1");
//       await owner.sendTransaction({
//         to: await autoGasVault.getAddress(),
//         value: ethAmount
//       });

//       // Mock Uniswap router conversion
//       await uniswapRouter.mockConversionRate(ethAmount, ethers.parseEther("100"));

//       // Perform conversion
//       const tx = await autoGasVault.convertETHToCORE();
      
//       // Check event
//       await expect(tx)
//         .to.emit(autoGasVault, "ETHToCoreConverted")
//         .withArgs(ethers.parseEther("100"));
//     });
//   });

//   describe("Speed to ETH Conversion", function () {
//     it("Should revert if weekly distribution interval not passed", async function () {
//       // Mint some speed tokens to the vault
//       await speedToken.transfer(await autoGasVault.getAddress(), ethers.parseEther("100"));

//       // First conversion should work
//       await autoGasVault.convertSpeedToETH();

//       // Second conversion should revert
//       await expect(autoGasVault.convertSpeedToETH()).to.be.revertedWith("Too soon");
//     });

//     it("Should convert Speed tokens to ETH", async function () {
//       // Mint some speed tokens to the vault
//       const speedAmount = ethers.parseEther("100");
//       await speedToken.transfer(await autoGasVault.getAddress(), speedAmount);

//       // Mock Uniswap router conversion
//       await uniswapRouter.mockConversionRate(speedAmount, ethers.parseEther("0.1"));

//       // Perform conversion
//       const tx = await autoGasVault.convertSpeedToETH();
      
//       // Check event
//       await expect(tx)
//         .to.emit(autoGasVault, "SpeedTokensConverted")
//         .withArgs(ethers.parseEther("0.1"));
//     });
//   });

//   describe("ETH Distribution", function () {
//     it("Should revert if no ETH to distribute", async function () {
//       await expect(autoGasVault.distributeETH()).to.be.revertedWith("No ETH to distribute");
//     });

//     it("Should emit distribution event", async function () {
//         const {owner} = await loadFixture (deployMockToken);
//       // Send some ETH to the contract
//       const ethAmount = ethers.parseEther("1");
//       await owner.sendTransaction({
//         to: await autoGasVault.getAddress(),
//         value: ethAmount
//       });

//       // Perform distribution
//       const tx = await autoGasVault.distributeETH();
      
//       // Check event
//       await expect(tx)
//         .to.emit(autoGasVault, "TokensDistributed")
//         .withArgs(ethAmount);
//     });
//   });

//   describe("Migration", function () {
//     it("Should allow owner to migrate tokens and ETH", async function () {
//         const {owner, addr1} = await loadFixture (deployMockToken)
//       // Prepare some tokens and ETH
//       const coreAmount = ethers.parseEther("50");
//       const speedAmount = ethers.parseEther("25");
//       const ethAmount = ethers.parseEther("0.1");

//       // Transfer tokens to vault
      
//       await coreToken.transfer(await autoGasVault.getAddress(), coreAmount);
//       await speedToken.transfer(await autoGasVault.getAddress(), speedAmount);
//       await owner.sendTransaction({
//         to: await autoGasVault.getAddress(),
//         value: ethAmount
//       });

//       // Prepare new vault address
//       const newVaultAddress = addr1.address;

//       // Perform migration
//       await autoGasVault.migrate(newVaultAddress);

//       // Check balances of new vault
//       const newVaultCoreBalance = await coreToken.balanceOf(newVaultAddress);
//       const newVaultSpeedBalance = await speedToken.balanceOf(newVaultAddress);
//       const newVaultEthBalance = await ethers.provider.getBalance(newVaultAddress);

//       expect(newVaultCoreBalance).to.equal(coreAmount);
//       expect(newVaultSpeedBalance).to.equal(speedAmount);
//     });

//     it("Should revert migration if called by non-owner", async function () {
//         const {addr1, addr2} = await loadFixture (deployMockToken);
//       await expect(
//         autoGasVault.connect(addr1).migrate(addr2.address)
//       ).to.be.revertedWithCustomError(autoGasVault, "OwnableUnauthorizedAccount");
//     });
//   });

//   describe("Receive Function", function () {
//     it("Should accept ETH transfers", async function () {
//         const {owner} = await loadFixture (deployMockToken);
//       const ethAmount = ethers.parseEther("1");
      
//       // Send ETH directly to contract
//       await expect(
//         owner.sendTransaction({
//           to: await autoGasVault.getAddress(),
//           value: ethAmount
//         })
//       ).to.not.be.reverted;

//       // Verify balance
//       const contractBalance = await ethers.provider.getBalance(await autoGasVault.getAddress());
//       expect(contractBalance).to.equal(ethAmount);
//     });
//   });
// });