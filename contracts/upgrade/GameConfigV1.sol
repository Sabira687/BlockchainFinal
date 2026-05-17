// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

contract GameConfigV1 is Initializable, UUPSUpgradeable, OwnableUpgradeable {
    uint256 public craftingFee;
    uint256 public lootBoxPrice;
    address public treasury;

    error ZeroAddress();
    error InvalidAmount();

    event CraftingFeeUpdated(uint256 craftingFee);
    event LootBoxPriceUpdated(uint256 lootBoxPrice);
    event TreasuryUpdated(address treasury);

    function initialize(address initialOwner, address treasury_, uint256 craftingFee_, uint256 lootBoxPrice_)
        public
        initializer
    {
        if (initialOwner == address(0) || treasury_ == address(0)) {
            revert ZeroAddress();
        }

        __Ownable_init(initialOwner);
        __Ownable_init(initialOwner);

        treasury = treasury_;
        craftingFee = craftingFee_;
        lootBoxPrice = lootBoxPrice_;

        emit TreasuryUpdated(treasury_);
        emit CraftingFeeUpdated(craftingFee_);
        emit LootBoxPriceUpdated(lootBoxPrice_);
    }

    function setCraftingFee(uint256 newCraftingFee) external onlyOwner {
        craftingFee = newCraftingFee;

        emit CraftingFeeUpdated(newCraftingFee);
    }

    function setLootBoxPrice(uint256 newLootBoxPrice) external onlyOwner {
        lootBoxPrice = newLootBoxPrice;

        emit LootBoxPriceUpdated(newLootBoxPrice);
    }

    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) {
            revert ZeroAddress();
        }

        treasury = newTreasury;

        emit TreasuryUpdated(newTreasury);
    }

    function version() external pure virtual returns (uint256) {
        return 1;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}
}
