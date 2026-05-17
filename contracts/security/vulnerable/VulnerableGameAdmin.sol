// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract VulnerableGameAdmin {
    uint256 public dropRate;

    event DropRateUpdated(uint256 dropRate);

    function setDropRate(uint256 newDropRate) external {
        dropRate = newDropRate;

        emit DropRateUpdated(newDropRate);
    }
}
