// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract MockRandomnessProvider {
    uint256 public nextRequestId = 1;

    mapping(uint256 requestId => address requester) public requesters;

    event RandomnessRequested(uint256 indexed requestId, address indexed requester);

    function requestRandomness(address requester) external returns (uint256 requestId) {
        requestId = nextRequestId;
        nextRequestId++;

        requesters[requestId] = requester;

        emit RandomnessRequested(requestId, requester);
    }
}
