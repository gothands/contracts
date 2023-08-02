// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import "./Affiliate.sol";
import "./Staking.sol";

//import "hardhat/console.sol";

/**
 * @title Bank contract
 * @dev  from Affiliate contract.
 * Keeps track of received funds and allows for fund withdrawal.
 */
contract Bank {
  // Instance of the Affiliate contract
  Affiliate private affiliateContract;

  // Instance of the Staking contract
  Staking private stakingContract;

  // Mapping to keep track of received funds per block
  mapping(uint256 => uint256) private receivedFundsPerBlock;

  // Event emitted when funds are received
  event FundsReceived(
    address indexed contributor1,
    address indexed contributor2,
    uint256 amount,
    uint256 blockNumber,
    uint256 affiliateAmount,
    uint256 stakerAmount
  );

  // Only the affiliate contract can call this function
  modifier onlyAffiliateContract() {
    require(
      msg.sender == address(affiliateContract),
      "Only the affiliate contract can call this function."
    );
    _;
  }

  // Only the staking contract can call this function
  modifier onlyStakingContract() {
    require(
      msg.sender == address(stakingContract),
      "Only the staking contract can call this function."
    );
    _;
  }

  // Only the affiliate or staking contract can call this function
  modifier onlyAffiliateOrStakingContract() {
    require(
      msg.sender == address(affiliateContract) || msg.sender == address(stakingContract),
      "Only the affiliate or staking contract can call this function."
    );
    _;
  }

  // Constructor to set the affiliate contract
  constructor(address _affiliateContract, address _stakingContract) {
    affiliateContract = Affiliate(_affiliateContract);
    stakingContract = Staking(_stakingContract);

    affiliateContract.setBankContract(address(this));
    stakingContract.setBankContract(address(this));
  }

  /**
   * @dev Allows contributors to deposit funds and emits a FundsReceived event
   * @param contributor1 Address of the first contributor
   * @param contributor2 Address of the second contributor
   */
  function receiveFunds(address contributor1, address contributor2) public payable {
    uint256 potFee = msg.value;

    // Check if the contributors are consumers and calculate the affiliate's share
    address affiliate1 = affiliateContract.getAffiliateOfConsumer(contributor1);
    address affiliate2 = affiliateContract.getAffiliateOfConsumer(contributor2);

    uint256 affiliateShare1 = affiliateContract.calculateAndAddAffiliateShare(
      affiliate1,
      contributor1,
      potFee
    );
    require(affiliateShare1 <= potFee, "Affiliate share cannot be more than potFee");
    potFee -= affiliateShare1;

    uint256 affiliateShare2 = affiliateContract.calculateAndAddAffiliateShare(
      affiliate2,
      contributor2,
      potFee
    );
    require(affiliateShare2 <= potFee, "Affiliate share cannot be more than potFee");
    potFee -= affiliateShare2;

    ////console.log("Received funds: %s   affiliate1: %s   affiliate2: %s   affiliateShare1: %s");
    //console.log("affiliateShare2: %s   potFee: %s", msg.value, affiliate1, affiliate2);
    //console.log(affiliateShare1, affiliateShare2, potFee);
    //console.log("Received funds: %s", msg.value);
    //console.log("affiliate1: %s", affiliate1);
    //console.log("affiliate2: %s", affiliate2);
    //console.log("affiliateShare1: %s", affiliateShare1);
    //console.log("affiliateShare2: %s", affiliateShare2);
    //console.log("potFee: %s", potFee);

    // Add the remaining potFee to the receivedFundsPerBlock
    // Call the addReceivedFundsForStaking function from the Staking contract
    stakingContract.addReceivedFundsForStaking(potFee);

    // Emit the event for fund receipt
    emit FundsReceived(
      contributor1,
      contributor2,
      msg.value,
      block.number,
      affiliateContract.getReceivedFundsForAffiliateInBlock(affiliate1, block.number),
      potFee
    );
  }

  /**
   * @dev Returns the total funds received in a given block range
   * @param startBlock Starting block number for the period
   * @param endBlock Ending block number for the period
   * @return Total funds received in the given period
   */
  function getReceivedFundsInPeriod(
    uint256 startBlock,
    uint256 endBlock
  ) external view returns (uint256) {
    uint256 totalFunds = 0;
    for (uint256 i = startBlock; i <= endBlock; i++) {
      totalFunds += receivedFundsPerBlock[i];
    }
    return totalFunds;
  }

  /**
   * @dev Allows the affiliate and contract to withdraw funds and emits a Withdrawal event
   * @param amount Amount to withdraw
   */
  function withdraw(uint256 amount, address recipient) external onlyAffiliateOrStakingContract {
    require(amount > 0, "Withdrawal amount should be more than zero");
    require(amount <= address(this).balance, "Not enough funds in the contract.");

    // Transfer the funds to the recipient
    (bool success, ) = recipient.call{value: amount}("");
    require(success, "Transfer failed.");
  }
}
