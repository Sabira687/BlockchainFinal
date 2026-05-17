// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {GameItems} from "../tokens/GameItems.sol";
import {IRandomnessProvider} from "../oracle/IRandomnessProvider.sol";

contract LootBox is Ownable, Pausable, ReentrancyGuard {
    GameItems public immutable items;
    IRandomnessProvider public randomnessProvider;

    struct Drop {
        uint256 itemId;
        uint256 amount;
        uint256 weight;
    }

    struct Request {
        address player;
        bool fulfilled;
        bool exists;
    }

    Drop[] private drops;

    mapping(uint256 requestId => Request request) public requests;
    mapping(address player => uint256 pendingRequestId) public pendingRequests;

    uint256 public totalWeight;
    uint256 public lootBoxItemId;

    error ZeroAddress();
    error InvalidAmount();
    error InvalidDrop();
    error NoDropsConfigured();
    error RequestNotFound();
    error RequestAlreadyFulfilled();
    error UnauthorizedProvider();
    error PendingRequestExists();

    event RandomnessProviderUpdated(address indexed provider);
    event DropConfigured(uint256 indexed index, uint256 itemId, uint256 amount, uint256 weight);
    event LootBoxOpened(address indexed player, uint256 indexed requestId);
    event LootBoxFulfilled(address indexed player, uint256 indexed requestId, uint256 itemId, uint256 amount);

    constructor(address initialOwner, GameItems items_, address randomnessProvider_, uint256 lootBoxItemId_)
        Ownable(initialOwner)
    {
        if (
            initialOwner == address(0) || address(items_) == address(0) || randomnessProvider_ == address(0)
                || lootBoxItemId_ == 0
        ) {
            revert ZeroAddress();
        }

        items = items_;
        randomnessProvider = IRandomnessProvider(randomnessProvider_);
        lootBoxItemId = lootBoxItemId_;
    }

    function setRandomnessProvider(address newProvider) external onlyOwner {
        if (newProvider == address(0)) {
            revert ZeroAddress();
        }

        randomnessProvider = IRandomnessProvider(newProvider);

        emit RandomnessProviderUpdated(newProvider);
    }

    function setDrops(Drop[] calldata newDrops) external onlyOwner {
        if (newDrops.length == 0) {
            revert InvalidDrop();
        }

        delete drops;
        totalWeight = 0;

        for (uint256 i = 0; i < newDrops.length; i++) {
            if (newDrops[i].itemId == 0 || newDrops[i].amount == 0 || newDrops[i].weight == 0) {
                revert InvalidDrop();
            }

            drops.push(newDrops[i]);
            totalWeight += newDrops[i].weight;

            emit DropConfigured(i, newDrops[i].itemId, newDrops[i].amount, newDrops[i].weight);
        }
    }

    function openLootBox() external nonReentrant whenNotPaused returns (uint256 requestId) {
        if (totalWeight == 0) {
            revert NoDropsConfigured();
        }

        if (pendingRequests[msg.sender] != 0) {
            revert PendingRequestExists();
        }

        items.burn(msg.sender, lootBoxItemId, 1);

        requestId = randomnessProvider.requestRandomness(address(this));

        requests[requestId] = Request({player: msg.sender, fulfilled: false, exists: true});
        pendingRequests[msg.sender] = requestId;

        emit LootBoxOpened(msg.sender, requestId);
    }

    function fulfillRandomness(uint256 requestId, uint256 randomWord) external nonReentrant {
        if (msg.sender != address(randomnessProvider)) {
            revert UnauthorizedProvider();
        }

        Request storage request = requests[requestId];

        if (!request.exists) {
            revert RequestNotFound();
        }

        if (request.fulfilled) {
            revert RequestAlreadyFulfilled();
        }

        request.fulfilled = true;
        pendingRequests[request.player] = 0;

        Drop memory selectedDrop = _selectDrop(randomWord);

        items.mint(request.player, selectedDrop.itemId, selectedDrop.amount, "");

        emit LootBoxFulfilled(request.player, requestId, selectedDrop.itemId, selectedDrop.amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getDrop(uint256 index) external view returns (uint256 itemId, uint256 amount, uint256 weight) {
        Drop memory drop = drops[index];

        return (drop.itemId, drop.amount, drop.weight);
    }

    function getDropCount() external view returns (uint256) {
        return drops.length;
    }

    function _selectDrop(uint256 randomWord) private view returns (Drop memory) {
        uint256 target = randomWord % totalWeight;
        uint256 cumulative;

        for (uint256 i = 0; i < drops.length; i++) {
            cumulative += drops[i].weight;

            if (target < cumulative) {
                return drops[i];
            }
        }

        return drops[drops.length - 1];
    }
}
