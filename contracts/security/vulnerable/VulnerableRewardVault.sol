// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract VulnerableRewardVault {
    mapping(address user => uint256 balance) public balances;

    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];

        if (amount == 0) {
            revert();
        }

        (bool success,) = msg.sender.call{value: amount}("");

        if (!success) {
            revert();
        }

        balances[msg.sender] = 0;
    }
}
