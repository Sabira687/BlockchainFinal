// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {GameConfigV1} from "./GameConfigV1.sol";

contract GameConfigV2 is GameConfigV1 {
    uint256 public rentalFee;

    event RentalFeeUpdated(uint256 rentalFee);

    function setRentalFee(uint256 newRentalFee) external onlyOwner {
        rentalFee = newRentalFee;

        emit RentalFeeUpdated(newRentalFee);
    }

    function version() external pure override returns (uint256) {
        return 2;
    }
}
