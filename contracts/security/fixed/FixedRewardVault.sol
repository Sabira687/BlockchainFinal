// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract FixedRewardVault is ReentrancyGuard {
    mapping(address user => uint256 balance) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external nonReentrant {
        uint256 amount = balances[msg.sender];

        if (amount == 0) {
            revert();
        }

        balances[msg.sender] = 0;

        (bool success,) = msg.sender.call{value: amount}("");

        if (!success) {
            revert();
        }
    }
}
