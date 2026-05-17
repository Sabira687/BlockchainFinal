// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract GameYieldVault is ERC4626, Ownable {
    using SafeERC20 for IERC20;

    error ZeroAddress();
    error InvalidAmount();

    event RewardsAdded(address indexed sender, uint256 amount);

    constructor(address initialOwner, IERC20 asset_)
        ERC20("GameFi Yield Vault Share", "gGAME")
        ERC4626(asset_)
        Ownable(initialOwner)
    {
        if (initialOwner == address(0) || address(asset_) == address(0)) {
            revert ZeroAddress();
        }
    }

    function addRewards(uint256 amount) external onlyOwner {
        if (amount == 0) {
            revert InvalidAmount();
        }

        IERC20(asset()).safeTransferFrom(msg.sender, address(this), amount);

        emit RewardsAdded(msg.sender, amount);
    }
}
