// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.11;

contract BurnerManager {
  mapping(address => address) private burnerToOwner;
  mapping(address => address) private ownerToBurner;

  function setBurner(address _burner) public {
    require(burnerToOwner[_burner] == address(0), "Burner already has owner.");

    // If the owner already has a burner, clear it
    if (ownerToBurner[msg.sender] != address(0)) {
      address oldBurner = ownerToBurner[msg.sender];
      delete burnerToOwner[oldBurner];
    }

    // Set the new burner
    burnerToOwner[_burner] = msg.sender;
    ownerToBurner[msg.sender] = _burner;
  }

  function getBurner(address _owner) public view returns (address) {
    if (ownerToBurner[_owner] == address(0)) {
      return _owner;
    }
    return ownerToBurner[_owner];
  }

  function getOwner(address _burner) public view returns (address) {
    if (burnerToOwner[_burner] == address(0)) {
      return _burner;
    }
    return burnerToOwner[_burner];
  }

  function fundBurner(uint _value) public payable {
    address payable burner = payable(ownerToBurner[msg.sender]);
    (bool success, ) = burner.call{value: _value}("");
    require(success, "Transfer to burner address failed.");
  }

  //internal function clearBurner(address _burner) internal {
  function clearBurner(address _owner) internal {
    address burner = ownerToBurner[_owner];
    delete burnerToOwner[burner];
    delete ownerToBurner[_owner];
  }
}
