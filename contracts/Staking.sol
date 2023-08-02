// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import "./interfaces/IHandsToken.sol";
import "./interfaces/IStaking.sol";
import "./Bank.sol";

contract Staking is IStaking {
  IHandsToken private handsToken;
  Bank public bankContract;

  struct Staker {
    uint256 stakedAmount;
    uint256 lastCumulativeRewardRate;
  }

  uint256 public totalStaked;
  uint256 public cumulativeRewardRate;
  mapping(address => Staker) public stakers;
  mapping(address => uint256) public rewards;

  constructor(address _handsTokenAddress) {
    handsToken = IHandsToken(_handsTokenAddress);
  }

  modifier onlyBankContract() {
    require(msg.sender == address(bankContract), "Only bank contract");
    _;
  }

  modifier bankNotInitialized() {
    require(address(bankContract) == address(0), "Bank contract already initialized");
    _;
  }

  function setBankContract(address _bankContractAddress) external bankNotInitialized {
    bankContract = Bank(_bankContractAddress);
  }

  function stake(uint256 amount) external {
    updateRewardsFor(msg.sender);

    handsToken.transferFrom(msg.sender, address(this), amount);
    totalStaked += amount;
    stakers[msg.sender].stakedAmount += amount;

    emit Staked(msg.sender, amount);
  }

  function unstake(uint256 amount) external {
    updateRewardsFor(msg.sender);

    handsToken.transfer(msg.sender, amount);
    totalStaked -= amount;
    stakers[msg.sender].stakedAmount -= amount;

    emit Unstaked(msg.sender, amount);
  }

  function claimRewards() external {
    updateRewardsFor(msg.sender);

    uint256 reward = rewards[msg.sender];
    rewards[msg.sender] = 0;

    bankContract.withdraw(reward, msg.sender);

    emit RewardsClaimed(msg.sender, reward);
  }

  function addReceivedFundsForStaking(uint256 amount) external onlyBankContract {
    if (totalStaked > 0) {
      cumulativeRewardRate += (amount * 1e18) / totalStaked;
    }

    emit ReceivedFundsForStaking(amount);
  }

  function updateRewardsFor(address stakerAddress) public {
    Staker storage staker = stakers[stakerAddress];

    if (staker.stakedAmount > 0) {
      rewards[stakerAddress] +=
        ((cumulativeRewardRate - staker.lastCumulativeRewardRate) * staker.stakedAmount) /
        1e18;
    }

    staker.lastCumulativeRewardRate = cumulativeRewardRate;
  }

  function viewTotalStaked() external view returns (uint256) {
    return totalStaked;
  }

  function stakedAmount(address stakerAddress) external view returns (uint256) {
    return stakers[stakerAddress].stakedAmount;
  }

  function viewClaimableRewards(address stakerAddress) external view returns (uint256) {
    Staker memory staker = stakers[stakerAddress];

    uint256 claimableRewards = rewards[stakerAddress];
    if (staker.stakedAmount > 0) {
      claimableRewards +=
        ((cumulativeRewardRate - staker.lastCumulativeRewardRate) * staker.stakedAmount) /
        1e18;
    }

    return claimableRewards;
  }

  function getReceivedFundsForStaking() external view returns (uint256) {
    return (cumulativeRewardRate * totalStaked) / 1e18;
  }
}
