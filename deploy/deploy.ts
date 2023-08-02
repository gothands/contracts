import { Wallet, utils } from "zksync-web3";
import * as ethers from "ethers";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import Secrets from "../secrets.json";

// Get private key from the environment variable
const PRIVATE_KEY: string = Secrets.privateKey || "";
if (!PRIVATE_KEY) {
  throw new Error("Please set ZKS_PRIVATE_KEY in the environment variables.");
}

export default async function (hre: HardhatRuntimeEnvironment) {
  console.log(`Running deploy script for the Hands and Bankroll contracts`);

  const wallet = new Wallet(PRIVATE_KEY);

  const deployer = new Deployer(hre, wallet);

  // Load the artifact of the Bankroll contract you want to deploy.
  const bankrollArtifact = await deployer.loadArtifact("Bankroll");

  // Estimate Bankroll contract deployment fee
  //const bankrollDeploymentFee = await deployer.estimateDeployFee(bankrollArtifact);

  //const parsedBankrollFee = ethers.utils.formatEther(bankrollDeploymentFee.toString());
  //console.log(`The Bankroll deployment is estimated to cost ${parsedBankrollFee} ETH`);

  //deployer address
  //const deployerAddress = await wallet.getAddress();

  // Deploy Bankroll contract
  const bankrollContract = await deployer.deploy(bankrollArtifact);

  // Show the Bankroll contract info
  const bankrollContractAddress = bankrollContract.address;
  console.log(`Bankroll was deployed to ${bankrollContractAddress}`);

  // Load the artifact of the Hands contract you want to deploy.
  const handsArtifact = await deployer.loadArtifact("Hands");

  // Estimate Hands contract deployment fee
  const handsDeploymentFee = await deployer.estimateDeployFee(handsArtifact, [
    bankrollContractAddress,
  ]);

  const parsedHandsFee = ethers.utils.formatEther(handsDeploymentFee.toString());
  console.log(`The Hands deployment is estimated to cost ${parsedHandsFee} ETH`);

  // Deploy Hands contract, passing the address of the deployed Bankroll contract to the constructor
  const handsContract = await deployer.deploy(handsArtifact, [bankrollContractAddress]);

  // Show the Hands contract info
  const handsContractAddress = handsContract.address;
  console.log(`Hands was deployed to ${handsContractAddress}`);
}
