// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import "./Bank.sol";
import "./interfaces/IAffiliate.sol";

contract Affiliate is IAffiliate {
  // The bank contract.
  Bank public bankContract;

  // The maximum fee share per affiliate is 25%.
  uint256 public constant MAX_FEE_SHARE_PER_AFFILIATE = 25;

  struct AffiliateInfo {
    uint256 receivedFunds;
    uint256 lastClaimedBlock;
  }

  // Total received funds.
  uint256 public totalReceived;

  // Mapping from affiliate's address to their AffiliateInfo struct.
  mapping(address => AffiliateInfo) public affiliates;

  // Mapping from affiliate's address to a mapping from block number to received funds.
  mapping(address => mapping(uint256 => uint256)) private receivedFundsPerAffiliatePerBlock;

  // Mapping from affiliate's address to a list of consumers' addresses.
  mapping(address => address[]) private affiliateToConsumers;

  // Mapping from consumer's address to affiliate's address.
  mapping(address => address) private consumerToAffiliate;

  /**
   * @dev Modifier to check if the caller is the bank contract.
   */
  modifier onlyBankContract() {
    require(msg.sender == address(bankContract), "Only the bank contract can call this function.");
    _;
  }

  /**
   * @dev Modifier to check if the bank contract has not been initialized.
   */
  modifier bankNotInitialized() {
    require(address(bankContract) == address(0), "Bank contract already initialized");
    _;
  }

  /**
   * @dev Set the bank contract.
   * @param _bankContract The address of the bank contract.
   */
  function setBankContract(address _bankContract) external bankNotInitialized {
    bankContract = Bank(_bankContract);
  }

  /**
   * @dev Register a consumer with an affiliate.
   * @param affiliate The address of the affiliate.
   */
  function registerAsConsumer(address affiliate) external {
    // Check if this consumer has already registered with an affiliate.
    require(consumerToAffiliate[msg.sender] == address(0), "Consumer has already registered.");
    // Make sure the affiliate is not the sender.
    require(affiliate != msg.sender, "Affiliate cannot be the consumer.");

    // Add the consumer to the list of this affiliate's consumers.
    affiliateToConsumers[affiliate].push(msg.sender);

    // Register this consumer with the affiliate.
    consumerToAffiliate[msg.sender] = affiliate;

    emit ConsumerRegistered(msg.sender, affiliate);
  }

  /**
   * @dev Get the list of consumers registered with an affiliate.
   * @param affiliate The address of the affiliate.
   * @return A list of consumer addresses.
   */
  function getConsumersOfAffiliate(address affiliate) external view returns (address[] memory) {
    return affiliateToConsumers[affiliate];
  }

  /**
   * @dev Get the affiliate of a consumer.
   * @param consumer The address of the consumer.
   * @return The address of the consumer's affiliate.
   */
  function getAffiliateOfConsumer(address consumer) external view returns (address) {
    return consumerToAffiliate[consumer];
  }

  /**
   * @dev Calculate the affiliate's share and add it to the received funds.
   * @param affiliate The address of the affiliate.
   * @param totalAmount The total amount of funds received.
   * @return The affiliate's share.
   */
  function calculateAndAddAffiliateShare(
    address affiliate,
    address consumer,
    uint256 totalAmount
  ) external onlyBankContract returns (uint256) {
    if (affiliate != address(0)) {
      uint256 affiliateShare = (MAX_FEE_SHARE_PER_AFFILIATE * totalAmount) / 100;
      receivedFundsPerAffiliatePerBlock[affiliate][block.number] += affiliateShare;
      affiliates[affiliate].receivedFunds += affiliateShare;
      totalReceived += affiliateShare;

      emit RewardRecieved(affiliate, consumer, affiliateShare);

      return affiliateShare;
    }
    return 0;
  }

  /**
   * @dev Get the received funds for an affiliate in a block.
   * @param affiliate The address of the affiliate.
   * @param blockNumber The block number.
   * @return The received funds.
   */
  function getReceivedFundsForAffiliateInBlock(
    address affiliate,
    uint256 blockNumber
  ) public view returns (uint256) {
    return receivedFundsPerAffiliatePerBlock[affiliate][blockNumber];
  }

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
  ) public view returns (uint256) {
    uint256 totalFunds = 0;
    for (uint256 i = startBlock; i <= endBlock; i++) {
      totalFunds += getReceivedFundsForAffiliateInBlock(affiliate, i);
    }
    return totalFunds;
  }

  /**
   * @dev Retrieve the received funds for an affiliate.
   */
  function claimRewards() external {
    _claimRewards(msg.sender);
  }

  /**
   * @dev Retrieve the received funds for an affiliate.
   * @param affiliateAddress The address of the affiliate.
   */
  function _claimRewards(address affiliateAddress) private {
    AffiliateInfo storage affiliate = affiliates[affiliateAddress];
    uint256 claimableRewards = _calculateRewards(affiliateAddress);
    if (claimableRewards > 0) {
      bankContract.withdraw(claimableRewards, affiliateAddress);

      emit RewardClaimed(affiliateAddress, claimableRewards);
    }
    affiliate.lastClaimedBlock = block.number;
  }

  /**
   * @dev Calculate the affiliate's rewards.
   * @param affiliateAddress The address of the affiliate.
   * @return The affiliate's rewards.
   */
  function _calculateRewards(address affiliateAddress) private view returns (uint256) {
    AffiliateInfo storage affiliate = affiliates[affiliateAddress];
    if (affiliate.receivedFunds == 0 || totalReceived == 0) {
      return 0;
    }
    return
      getReceivedFundsForAffiliateInPeriod(
        affiliateAddress,
        affiliate.lastClaimedBlock,
        block.number
      );
  }

  /**
   * @dev View the affiliate's rewards.
   * @param affiliateAddress The address of the affiliate.
   * @return The affiliate's rewards.
   */
  function viewClaimableRewards(address affiliateAddress) external view returns (uint256) {
    return _calculateRewards(affiliateAddress);
  }
}
