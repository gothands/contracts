// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract HandsToken is ERC20, Ownable {
  uint256 private immutable _SUPPLY_CAP;

  /**
   * @notice Constructor
   * @param _premintReceiver address that receives the premint
   * @param _premintAmount amount to premint
   * @param _cap supply cap (to prevent abusive mint)
   */
  constructor(
    address _premintReceiver,
    uint256 _premintAmount,
    uint256 _cap
  ) ERC20("Handsy Token", "HANDS") {
    require(_cap >= _premintAmount, "HANDS: Premint amount is greater than cap");
    // Transfer the sum of the premint to address
    _mint(_premintReceiver, _premintAmount);
    _SUPPLY_CAP = _cap;
  }

  /**
   * @notice Mint HANDS tokens
   * @param account address to receive tokens
   * @param amount amount to mint
   * @return status true if mint is successful, false if not
   */
  function mint(address account, uint256 amount) external onlyOwner returns (bool status) {
    if (totalSupply() + amount <= _SUPPLY_CAP) {
      _mint(account, amount);
      return true;
    }
    return false;
  }

  /**
   * @notice View supply cap
   */
  function SUPPLY_CAP() external view returns (uint256) {
    return _SUPPLY_CAP;
  }
}
