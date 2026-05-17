// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract FixedGameAdmin is Ownable {
    uint256 public dropRate;

    event DropRateUpdated(uint256 dropRate);

    constructor(address initialOwner) Ownable(initialOwner) {}

    function setDropRate(uint256 newDropRate) external onlyOwner {
        dropRate = newDropRate;

        emit DropRateUpdated(newDropRate);
    }
}
