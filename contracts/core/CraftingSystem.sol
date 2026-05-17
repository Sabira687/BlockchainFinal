// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {GameItems} from "../tokens/GameItems.sol";

contract CraftingSystem is Ownable, Pausable, ReentrancyGuard {
    GameItems public immutable items;

    struct Recipe {
        uint256[] inputIds;
        uint256[] inputAmounts;
        uint256 outputId;
        uint256 outputAmount;
        bool active;
    }

    mapping(uint256 recipeId => Recipe recipe) private recipes;

    error ZeroAddress();
    error InvalidRecipe();
    error RecipeNotActive();
    error ArrayLengthMismatch();
    error InvalidAmount();

    event RecipeSet(uint256 indexed recipeId, uint256 outputId, uint256 outputAmount);
    event RecipeStatusChanged(uint256 indexed recipeId, bool active);
    event Crafted(address indexed player, uint256 indexed recipeId, uint256 outputId, uint256 outputAmount);

    constructor(address initialOwner, GameItems items_) Ownable(initialOwner) {
        if (initialOwner == address(0) || address(items_) == address(0)) {
            revert ZeroAddress();
        }

        items = items_;
    }

    function setRecipe(
        uint256 recipeId,
        uint256[] calldata inputIds,
        uint256[] calldata inputAmounts,
        uint256 outputId,
        uint256 outputAmount,
        bool active
    ) external onlyOwner {
        if (recipeId == 0 || outputId == 0 || outputAmount == 0 || inputIds.length == 0) {
            revert InvalidRecipe();
        }

        if (inputIds.length != inputAmounts.length) {
            revert ArrayLengthMismatch();
        }

        for (uint256 i = 0; i < inputAmounts.length; i++) {
            if (inputIds[i] == 0 || inputAmounts[i] == 0) {
                revert InvalidAmount();
            }
        }

        recipes[recipeId] = Recipe({
            inputIds: inputIds,
            inputAmounts: inputAmounts,
            outputId: outputId,
            outputAmount: outputAmount,
            active: active
        });

        emit RecipeSet(recipeId, outputId, outputAmount);
        emit RecipeStatusChanged(recipeId, active);
    }

    function setRecipeActive(uint256 recipeId, bool active) external onlyOwner {
        Recipe storage recipe = recipes[recipeId];

        if (recipe.outputId == 0) {
            revert InvalidRecipe();
        }

        recipe.active = active;

        emit RecipeStatusChanged(recipeId, active);
    }

    function craft(uint256 recipeId) external nonReentrant whenNotPaused {
        Recipe storage recipe = recipes[recipeId];

        if (!recipe.active) {
            revert RecipeNotActive();
        }

        items.burnBatch(msg.sender, recipe.inputIds, recipe.inputAmounts);
        items.mint(msg.sender, recipe.outputId, recipe.outputAmount, "");

        emit Crafted(msg.sender, recipeId, recipe.outputId, recipe.outputAmount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getRecipe(uint256 recipeId)
        external
        view
        returns (
            uint256[] memory inputIds,
            uint256[] memory inputAmounts,
            uint256 outputId,
            uint256 outputAmount,
            bool active
        )
    {
        Recipe storage recipe = recipes[recipeId];

        return (recipe.inputIds, recipe.inputAmounts, recipe.outputId, recipe.outputAmount, recipe.active);
    }
}
