// SPDX-License-Identifier: Unlicense
// This interface uses the Unlicense SPDX license identifier.

pragma solidity ^0.8.11;

// Staking interface which represents a subset of functionalities from the Staking contract.
// Specifically, this interface includes the functions a typical user would interact with.
interface IStaking {
  // Event emitted when a user stakes.
  event Staked(address indexed staker, uint256 amount);

  // Event emitted when a user unstakes.
  event Unstaked(address indexed staker, uint256 amount);

  // Event emitted when a user claims rewards.
  event RewardsClaimed(address indexed staker, uint256 amount);

  //Event emitted when funds are received for staking.
  event ReceivedFundsForStaking(uint256 amount);

  // Function to view the total amount staked in the contract.
  function viewTotalStaked() external view returns (uint256);

  // Function to view the amount staked by a specific address.
  function stakedAmount(address stakerAddress) external view returns (uint256);

  // Function to stake a specific amount of tokens.
  function stake(uint256 amount) external;

  // Function to unstake a specific amount of tokens.
  function unstake(uint256 amount) external;

  // Function to claim staking rewards.
  function claimRewards() external;

  // Function to view the amount of claimable rewards for a specific address.
  function viewClaimableRewards(address stakerAddress) external view returns (uint256);

  // Function to get the amount of funds received for staking in a specific period.
  function getReceivedFundsForStaking() external view returns (uint256);
}
