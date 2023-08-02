// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

interface IAffiliate {
  // Event emitted when a consumer registers with an affiliate.
  event ConsumerRegistered(address indexed consumer, address indexed affiliate);

  // Event emitted when affiliate recieves a reward.
  event RewardRecieved(address indexed affiliate, address indexed consumer, uint256 amount);

  // Event emitted when affiliate claims a reward.
  event RewardClaimed(address indexed affiliate, uint256 amount);

  /**
   * @dev Register a consumer with an affiliate.
   * @param affiliate The address of the affiliate.
   */
  function registerAsConsumer(address affiliate) external;

  /**
   * @dev Get the list of consumers registered with an affiliate.
   * @param affiliate The address of the affiliate.
   * @return A list of consumer addresses.
   */
  function getConsumersOfAffiliate(address affiliate) external view returns (address[] memory);

  /**
   * @dev Get the affiliate of a consumer.
   * @param consumer The address of the consumer.
   * @return The address of the consumer's affiliate.
   */
  function getAffiliateOfConsumer(address consumer) external view returns (address);

  /**
   * @dev Get the received funds for an affiliate in a block.
   * @param affiliate The address of the affiliate.
   * @param blockNumber The block number.
   * @return The received funds.
   */
  function getReceivedFundsForAffiliateInBlock(
    address affiliate,
    uint256 blockNumber
  ) external view returns (uint256);

  /**
   * @dev Get the received funds for an affiliate in a period.
   * @param affiliate The address of the affiliate.
   * @param startBlock The start block.
   * @param endBlock The end block.
   * @return The received funds.
   */
  function getReceivedFundsForAffiliateInPeriod(
    address affiliate,
    uint256 startBlock,
    uint256 endBlock
  ) external view returns (uint256);

  /**
   * @dev Retrieve the received funds for an affiliate.
   */
  function claimRewards() external;

  /**
   * @dev View the affiliate's rewards.
   * @param affiliateAddress The address of the affiliate.
   * @return The affiliate's rewards.
   */
  function viewClaimableRewards(address affiliateAddress) external view returns (uint256);
}
