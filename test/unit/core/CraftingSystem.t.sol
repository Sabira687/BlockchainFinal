// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CraftingSystem} from "../../../contracts/core/CraftingSystem.sol";
import {GameItems} from "../../../contracts/tokens/GameItems.sol";

contract CraftingSystemTest is Test {
    GameItems private items;
    CraftingSystem private crafting;

    address private owner = address(0xA11CE);
    address private player = address(0xB0B);

    uint256 private wood;
    uint256 private stone;
    uint256 private sword;

    function setUp() public {
        items = new GameItems(address(this), "ipfs://gamefi-items/");
        crafting = new CraftingSystem(owner, items);

        wood = items.WOOD();
        stone = items.STONE();
        sword = items.SWORD();

        items.mint(player, wood, 10, "");
        items.mint(player, stone, 5, "");

        items.transferOwnership(address(crafting));
    }

    function testConstructorSetsState() public view {
        assertEq(address(crafting.items()), address(items));
        assertEq(crafting.owner(), owner);
    }

    function testOwnerCanSetRecipe() public {
        (uint256[] memory inputIds, uint256[] memory inputAmounts) = _recipeInputs();

        vm.prank(owner);
        crafting.setRecipe(1, inputIds, inputAmounts, sword, 1, true);

        (
            uint256[] memory storedIds,
            uint256[] memory storedAmounts,
            uint256 outputId,
            uint256 outputAmount,
            bool active
        ) = crafting.getRecipe(1);

        assertEq(storedIds[0], wood);
        assertEq(storedIds[1], stone);
        assertEq(storedAmounts[0], 3);
        assertEq(storedAmounts[1], 2);
        assertEq(outputId, sword);
        assertEq(outputAmount, 1);
        assertTrue(active);
    }

    function testNonOwnerCannotSetRecipe() public {
        (uint256[] memory inputIds, uint256[] memory inputAmounts) = _recipeInputs();

        vm.prank(player);
        vm.expectRevert();
        crafting.setRecipe(1, inputIds, inputAmounts, sword, 1, true);
    }

    function testCannotSetInvalidRecipe() public {
        (uint256[] memory inputIds, uint256[] memory inputAmounts) = _recipeInputs();

        vm.startPrank(owner);

        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        crafting.setRecipe(0, inputIds, inputAmounts, sword, 1, true);

        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        crafting.setRecipe(1, inputIds, inputAmounts, 0, 1, true);

        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        crafting.setRecipe(1, inputIds, inputAmounts, sword, 0, true);

        vm.stopPrank();
    }

    function testCannotSetRecipeWithMismatchedArrays() public {
        uint256[] memory inputIds = new uint256[](2);
        uint256[] memory inputAmounts = new uint256[](1);

        inputIds[0] = wood;
        inputIds[1] = stone;
        inputAmounts[0] = 3;

        vm.prank(owner);
        vm.expectRevert(CraftingSystem.ArrayLengthMismatch.selector);
        crafting.setRecipe(1, inputIds, inputAmounts, sword, 1, true);
    }

    function testCannotSetRecipeWithZeroInputAmount() public {
        uint256[] memory inputIds = new uint256[](1);
        uint256[] memory inputAmounts = new uint256[](1);

        inputIds[0] = wood;
        inputAmounts[0] = 0;

        vm.prank(owner);
        vm.expectRevert(CraftingSystem.InvalidAmount.selector);
        crafting.setRecipe(1, inputIds, inputAmounts, sword, 1, true);
    }

    function testPlayerCanCraftActiveRecipe() public {
        _setDefaultRecipe();

        vm.startPrank(player);
        items.setApprovalForAll(address(crafting), true);
        crafting.craft(1);
        vm.stopPrank();

        assertEq(items.balanceOf(player, wood), 7);
        assertEq(items.balanceOf(player, stone), 3);
        assertEq(items.balanceOf(player, sword), 1);
    }

    function testCannotCraftInactiveRecipe() public {
        (uint256[] memory inputIds, uint256[] memory inputAmounts) = _recipeInputs();

        vm.prank(owner);
        crafting.setRecipe(1, inputIds, inputAmounts, sword, 1, false);

        vm.startPrank(player);
        items.setApprovalForAll(address(crafting), true);

        vm.expectRevert(CraftingSystem.RecipeNotActive.selector);
        crafting.craft(1);
        vm.stopPrank();
    }

    function testOwnerCanToggleRecipeStatus() public {
        _setDefaultRecipe();

        vm.prank(owner);
        crafting.setRecipeActive(1, false);

        (,,,, bool active) = crafting.getRecipe(1);

        assertFalse(active);
    }

    function testCannotToggleMissingRecipe() public {
        vm.prank(owner);
        vm.expectRevert(CraftingSystem.InvalidRecipe.selector);
        crafting.setRecipeActive(999, false);
    }

    function testCannotCraftWhenPaused() public {
        _setDefaultRecipe();

        vm.prank(owner);
        crafting.pause();

        vm.startPrank(player);
        items.setApprovalForAll(address(crafting), true);

        vm.expectRevert();
        crafting.craft(1);
        vm.stopPrank();
    }

    function testOwnerCanUnpause() public {
        vm.prank(owner);
        crafting.pause();

        vm.prank(owner);
        crafting.unpause();

        assertFalse(crafting.paused());
    }

    function _setDefaultRecipe() private {
        (uint256[] memory inputIds, uint256[] memory inputAmounts) = _recipeInputs();

        vm.prank(owner);
        crafting.setRecipe(1, inputIds, inputAmounts, sword, 1, true);
    }

    function _recipeInputs() private view returns (uint256[] memory inputIds, uint256[] memory inputAmounts) {
        inputIds = new uint256[](2);
        inputAmounts = new uint256[](2);

        inputIds[0] = wood;
        inputIds[1] = stone;

        inputAmounts[0] = 3;
        inputAmounts[1] = 2;
    }
}
