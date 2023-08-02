import { Wallet, utils, Provider } from "zksync-web3";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import fs from "fs";
import * as secrets from "../secrets.json";
import { DeployFunction, DeployOptions } from "hardhat-deploy/types";
const hre = require("hardhat");

// Get private key from the environment variable
const PRIVATE_KEY: string = secrets.privateKeyArbitrumGoerli;

interface DependencyAbis {
  wETH: any;
  vault: any;
  master: any;
  classicFactory: any;
  stableFactory: any;
  router: any;
  feeManager: any;
  feeRecipient: any;
  feeRegistry: any;
  forwardRegistry: any;
  classicPool: any;
}

interface DependencyContracts {
  wETH: string;
  vault: string;
  master: string;
  classicFactory: string;
  stableFactory: string;
  router: string;
  feeManager: string;
  feeRecipient: string;
  feeRegistry: string;
  forwardRegistry: string;
}

interface DeployedContracts {
  HandsToken: string;
  Hands: string;
  Bank: string;
  Staking: string;
  Affiliate: string;
}

interface DeployedAbis {
  HandsToken: any;
  Hands: any;
  Bank: any;
  Staking: any;
  Affiliate: any;
}

const fetchDependencyAbis = async (): Promise<DependencyAbis> => {
  const wETHFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/WETH.sol/WETH.json",
  );
  const vaultFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/vault/SyncSwapVault.sol/SyncSwapVault.json",
  );
  const masterFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/master/SyncSwapPoolMaster.sol/SyncSwapPoolMaster.json",
  );
  const classicFactoryFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/pool/classic/SyncSwapClassicPoolFactory.sol/SyncSwapClassicPoolFactory.json",
  );
  const stableFactoryFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/pool/stable/SyncSwapStablePoolFactory.sol/SyncSwapStablePoolFactory.json",
  );
  const routerFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/SyncSwapRouter.sol/SyncSwapRouter.json",
  );
  const feeManagerFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/master/SyncSwapFeeManager.sol/SyncSwapFeeManager.json",
  );
  const feeRecipientFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/master/SyncSwapFeeRecipient.sol/SyncSwapFeeRecipient.json",
  );
  const feeRegistryFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/master/FeeRegistry.sol/FeeRegistry.json",
  );
  const forwardRegistryFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/master/ForwarderRegistry.sol/ForwarderRegistry.json",
  );
  const classicPoolFile = fs.readFileSync(
    "./syncswap-contracts/artifacts-zk/contracts/pool/classic/SyncSwapClassicPool.sol/SyncSwapClassicPool.json",
  );

  //make sure all files are loaded
  if (
    !wETHFile ||
    !vaultFile ||
    !masterFile ||
    !classicFactoryFile ||
    !stableFactoryFile ||
    !routerFile ||
    !feeManagerFile ||
    !feeRecipientFile ||
    !feeRegistryFile ||
    !forwardRegistryFile ||
    !classicPoolFile
  ) {
    throw new Error("Please run `yarn deploy:local` first");
  }

  const wETH = JSON.parse(wETHFile.toString()).abi;
  const vault = JSON.parse(vaultFile.toString()).abi;
  const master = JSON.parse(masterFile.toString()).abi;
  const classicFactory = JSON.parse(classicFactoryFile.toString()).abi;
  const stableFactory = JSON.parse(stableFactoryFile.toString()).abi;
  const router = JSON.parse(routerFile.toString()).abi;
  const feeManager = JSON.parse(feeManagerFile.toString()).abi;
  const feeRecipient = JSON.parse(feeRecipientFile.toString()).abi;
  const feeRegistry = JSON.parse(feeRegistryFile.toString()).abi;
  const forwardRegistry = JSON.parse(forwardRegistryFile.toString()).abi;
  const classicPool = JSON.parse(classicPoolFile.toString()).abi;

  //make sure all files are parsed
  if (
    !wETH ||
    !vault ||
    !master ||
    !classicFactory ||
    !stableFactory ||
    !router ||
    !feeManager ||
    !feeRecipient ||
    !feeRegistry ||
    !forwardRegistry ||
    !classicPool
  ) {
    throw new Error("Please run `yarn deploy:local` first");
  }

  return {
    wETH,
    vault,
    master,
    classicFactory,
    stableFactory,
    router,
    feeManager,
    feeRecipient,
    feeRegistry,
    forwardRegistry,
    classicPool,
  };
};

const fetchDependencyContracts = async (): Promise<DependencyContracts> => {
  const file = fs.readFileSync("./local-dependency-contracts.json");

  if (!file) {
    throw new Error("Please run `yarn deploy:local` first");
  }

  const contracts: DependencyContracts = JSON.parse(file.toString());

  if (!contracts) {
    throw new Error("Please run `yarn deploy:local` first");
  }

  return contracts;
};

const setLocalContractFile = async (
  dependencyContracts: DependencyContracts,
  dependencyAbis: DependencyAbis,
  deployedContracts: DeployedContracts,
  deployedAbis: DeployedAbis,
) => {
  const file = {
    dependencyContracts,
    dependencyAbis,
    deployedContracts,
    deployedAbis,
  };

  fs.writeFileSync("./local-contracts.json", JSON.stringify(file, null, 4));
};

function waitForPoolCreatedEvent(contract: any): Promise<string> {
  return new Promise((resolve, reject) => {
    // Event listener
    contract.on("PoolCreated", (token0: any, token1: any, pool: any) => {
      console.log(
        `PoolCreated event received: token0: ${token0}, token1: ${token1}, pool: ${pool}`,
      );
      contract.off("PoolCreated"); // Stop listening after the event is received
      resolve(pool); // Resolve the promise with pool address
    });

    // Error handling
    setTimeout(() => {
      reject(new Error("Timeout: PoolCreated event not received"));
    }, 60000); // 60 second timeout, adjust as needed
  });
}

console.log("Deploying Hands and Bank contracts");

async function main() {
  console.log(`Running deploy script for the Hands and bank contracts`);

  const { deployments, getNamedAccounts, network } = hre;
  console.log("named accounts", await getNamedAccounts());

  const provider = new ethers.providers.JsonRpcProvider("https://goerli-rollup.arbitrum.io/rpc");
  const wallet = new ethers.Wallet(PRIVATE_KEY, provider);
  let nonce = 2;
  console.log(`Nonce: ${nonce}`);
  const address = wallet.address;
  const signer = await hre.ethers.getSigner(wallet.address);

  console.log(`Wallet address: ${address}`);

  // IoTeX does not support the deterministic deployment through the contract used by hardhat-deploy
  const deterministicDeployment = network.name !== "iotex_testnet";

  const opts: DeployOptions = {
    deterministicDeployment,
    from: wallet.address,
    log: true,
  };
  //const deployer = new Deployer(wallet, opts);

  //dependency contracts
  const dependencyContracts = await fetchDependencyContracts();
  console.log(dependencyContracts);

  //dependency abis
  const dependencyAbis = await fetchDependencyAbis();
  //console.log(dependencyAbis);

  //DEPLOY HANDS TOKEN

  // Load the artifact of the HandsToken contract you want to deploy.
  //const handsTokenArtifact = await deployer.loadArtifact("HandsToken");

  // Set the premintReceiver, premintAmount, and supplyCap according to your requirements.
  const premintReceiver = address;
  const premintAmount = ethers.utils.parseUnits("1000000", 18);
  const supplyCap = ethers.utils.parseUnits("1000000", 18);

  // Deploy the HandsToken contract
  const HandsTokenContractFactory = await hre.ethers.getContractFactory("HandsToken");
  const HandsTokenContract = await HandsTokenContractFactory.deploy(
    premintReceiver,
    premintAmount,
    supplyCap,
  );
  // await HandsTokenContract.deployed();
  const HandsTokenArtifact = await hre.artifacts.readArtifact("HandsToken");
  const HandsTokenContractAbi = HandsTokenArtifact.abi;
  console.log("abi", HandsTokenContractAbi);
  const handsTokenContractAddress = HandsTokenContract.address;
  console.log(`HandsToken was deployed to ${HandsTokenContract.address}`);

  //DEPLOY AFFILIATE CONTRACT

  // Load the artifact of the Affiliate contract you want to deploy.
  //const affiliateArtifact = await deployer.loadArtifact("Affiliate");

  // Deploy Affiliate contract
  const AffiliateTokenContractFactory = await hre.ethers.getContractFactory("Affiliate");
  const AffiliateTokenContract = await AffiliateTokenContractFactory.deploy();
  await AffiliateTokenContract.deployed();
  const AffiliateTokenArtifact = await hre.artifacts.readArtifact("Affiliate");
  const AffiliateTokenContractAbi = AffiliateTokenArtifact.abi;
  const affiliateContractAddress = AffiliateTokenContract.address;

  // Show the Affiliate contract info
  console.log(`Affiliate was deployed to ${affiliateContractAddress}`);

  //DEPLOY STAKING CONTRACT

  // Load the artifact of the Staking contract you want to deploy.
  //const stakingArtifact = await deployer.loadArtifact("Staking");

  // Estimate Staking contract deployment fee
  //const stakingDeploymentFee = await deployer.estimateDeployFee(stakingArtifact, [handsTokenContractAddress]);

  //onst parsedStakingFee = ethers.utils.formatEther(stakingDeploymentFee.toString());
  //console.log(`The Staking deployment is estimated to cost ${parsedStakingFee} ETH`);

  // Deploy Staking contract, passing the addresses of the deployed HandsToken and bank contracts to the constructor
  const StakingContractFactory = await hre.ethers.getContractFactory("Staking");
  const StakingContract = await StakingContractFactory.deploy(handsTokenContractAddress);
  await StakingContract.deployed();
  const StakingContractArtifact = await hre.artifacts.readArtifact("Staking");
  const StakingContractAbi = StakingContractArtifact.abi;
  const stakingContractAddress = StakingContract.address;

  // Show the Staking contract
  console.log(`Staking was deployed to ${stakingContractAddress}`);

  //DEPLOY bank CONTRACT

  // Load the artifact of the bank contract you want to deploy.
  //const bankArtifact = await deployer.loadArtifact("Bank");

  // Deploy bank contract
  const BankContractFactory = await hre.ethers.getContractFactory("Bank");
  const BankContract = await BankContractFactory.deploy(
    affiliateContractAddress,
    stakingContractAddress,
  );
  await BankContract.deployed();
  const BankContractArtifact = await hre.artifacts.readArtifact("Bank");
  const BankContractAbi = BankContractArtifact.abi;
  const bankContractAddress = BankContract.address;

  // Show the bank contract info
  console.log(`bank was deployed to ${bankContractAddress}`);

  // //set banking contract for both affiliate and staking
  // console.log(`Owner of the Affiliate contract: ${await affiliateContract.owner()}`);
  // console.log(`Wallet address: ${deployer}`);

  // const setBankForAffiliateTx = await affiliateContract.setBankContract(bankContractAddress);
  // await setBankForAffiliateTx.wait();
  // //console.log(`Affiliate contract setBankContract tx: `);
  // const setBankForStakingTx = await stakingContract.setBankContract(bankContractAddress);
  // await setBankForStakingTx.wait();
  // //console.log(`Staking contract setBankContract tx: ${setBankForStakingTx.hash}`);

  //DEPLOY HANDS CONTRACT

  // Load the artifact of the Hands contract you want to deploy.
  //const handsArtifact = await deployer.loadArtifact("Hands");

  // Estimate Hands contract deployment fee
  //const handsDeploymentFee = await deployer.estimateDeployFee(handsArtifact, [bankContractAddress]);

  //const parsedHandsFee = ethers.utils.formatEther(handsDeploymentFee.toString());
  //console.log(`The Hands deployment is estimated to cost ${parsedHandsFee} ETH`);

  // Deploy Hands contract, passing the address of the deployed bank contract to the constructor
  const HandsContractFactory = await hre.ethers.getContractFactory("Hands");
  const HandsContract = await HandsContractFactory.deploy(bankContractAddress);
  await HandsContract.deployed();
  const HandsContractArtifact = await hre.artifacts.readArtifact("Hands");
  const HandsContractAbi = HandsContractArtifact.abi;
  const handsContractAddress = HandsContract.address;
  console.log("Hands ");

  // Show the Hands contract info
  console.log(`Hands was deployed to ${handsContractAddress}`);

  // //Send eth to address
  // const reciever = "0xf8a2bE5bAbD50AC94b5B811c137F306676012567"
  // const reciever2 = "0x3Cab3b593388D1750ab967D62927dD2B90e3cC22"
  // const tx = await wallet.sendTransaction({
  //     to: reciever,
  //     value: ethers.utils.parseEther("1"),
  // });
  // const tx2 = await wallet.sendTransaction({
  //     to: reciever2,
  //     value: ethers.utils.parseEther("1"),
  // });

  // //send hands to address
  // const handsToken = new ethers.Contract(
  //     handsTokenContractAddress,
  //     HandsTokenContractAbi,
  //     wallet,

  // );
  // const handsTokenTx = await handsToken.transfer(reciever, ethers.utils.parseUnits("100", 18));
  // const handsTokenTx2 = await handsToken.transfer(reciever2, ethers.utils.parseUnits("100", 18));

  //DEPLOYMENT FILE
  //create new json file with all the contract addresses
  const deployedContracts: DeployedContracts = {
    HandsToken: handsTokenContractAddress,
    Bank: bankContractAddress,
    Staking: stakingContractAddress,
    Hands: handsContractAddress,
    Affiliate: affiliateContractAddress,
  };

  const deployedAbis: DeployedAbis = {
    HandsToken: HandsTokenContractAbi,
    Bank: BankContractAbi,
    Staking: StakingContractAbi,
    Hands: HandsContractAbi,
    Affiliate: AffiliateTokenContractAbi,
  };

  setLocalContractFile(dependencyContracts, dependencyAbis, deployedContracts, deployedAbis);
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(() => process.exit());
