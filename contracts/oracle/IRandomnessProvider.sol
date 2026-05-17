// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IRandomnessProvider {
    function requestRandomness(address requester) external returns (uint256 requestId);
}
