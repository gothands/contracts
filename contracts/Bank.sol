// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./Affiliate.sol";
import "./Staking.sol";

//import "hardhat/console.sol";

/**
 * @title Bank contract
 * @dev  from Affiliate contract.
 * Keeps track of received funds and allows for fund withdrawal.
 */
contract Bank is ReentrancyGuard {
  // Instance of the Affiliate contract
  Affiliate private immutable affiliateContract;

  // Instance of the Staking contract
  Staking private immutable stakingContract;

  // Event emitted when funds are received
  event FundsReceived(
    uint256 amount,
    uint256 blockNumber,
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
   * @dev Receive function to handle incoming Ether transactions.
   */
  receive() external payable {
    // You can add any logic here if needed, or just leave it blank.
    // For now, we'll just call the receiveFunds function to handle the incoming funds.
    receiveFunds();
  }

  /**
   * @dev Allows contributors to deposit funds and emits a FundsReceived event
   */
  function receiveFunds() public payable nonReentrant {
    uint256 potFee = msg.value;

    // Add the remaining potFee to the receivedFundsPerBlock
    // Call the addReceivedFundsForStaking function from the Staking contract
    stakingContract.addReceivedFundsForStaking(potFee);

    // Emit the event for fund receipt
    emit FundsReceived(
      msg.value,
      block.number,
      potFee
    );
  }

  /**
   * @dev Allows the affiliate and contract to withdraw funds and emits a Withdrawal event
   * @param amount Amount to withdraw
   */
  function withdraw(uint256 amount, address recipient) external onlyAffiliateOrStakingContract nonReentrant {
    require(amount > 0, "Withdrawal amount should be more than zero");
    require(amount <= address(this).balance, "Not enough funds in the contract.");

    // Transfer the funds to the recipient
    payable(recipient).transfer(amount);
  }
}
