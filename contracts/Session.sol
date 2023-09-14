// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract Session {
    // Event that gets emitted when a user sets a session ID
    event OnSession(address indexed user, uint256 sessionId);

    // Function to set a session ID
    function set(uint256 sessionId) external {
        emit OnSession(msg.sender, sessionId);
    }
}
