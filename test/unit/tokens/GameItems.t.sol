// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameItems} from "../../../contracts/tokens/GameItems.sol";

contract GameItemsTest is Test {
    GameItems private items;

    address private owner = address(0xA11CE);
    address private player = address(0xB0B);
    address private operator = address(0xC0DE);

    uint256 private wood;
    uint256 private stone;
    uint256 private iron;
    uint256 private sword;

    function setUp() public {
        items = new GameItems(owner, "ipfs://gamefi-items/");
        wood = items.WOOD();
        stone = items.STONE();
        iron = items.IRON();
        sword = items.SWORD();
    }

    function testConstructorSetsOwner() public view {
        assertEq(items.owner(), owner);
    }

    function testUriIncludesTokenId() public view {
        assertEq(items.uri(wood), "ipfs://gamefi-items/1.json");
        assertEq(items.uri(sword), "ipfs://gamefi-items/100.json");
    }

    function testOwnerCanMintItem() public {
        vm.prank(owner);
        items.mint(player, wood, 10, "");

        assertEq(items.balanceOf(player, wood), 10);
        assertEq(items.totalSupply(wood), 10);
    }

    function testNonOwnerCannotMintItem() public {
        vm.prank(player);
        vm.expectRevert();
        items.mint(player, wood, 10, "");
    }

    function testCannotMintToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(GameItems.ZeroAddress.selector);
        items.mint(address(0), wood, 10, "");
    }

    function testCannotMintZeroAmount() public {
        vm.prank(owner);
        vm.expectRevert(GameItems.InvalidAmount.selector);
        items.mint(player, wood, 0, "");
    }

    function testOwnerCanMintBatch() public {
        uint256[] memory ids = new uint256[](3);
        uint256[] memory amounts = new uint256[](3);

        ids[0] = wood;
        ids[1] = stone;
        ids[2] = iron;

        amounts[0] = 10;
        amounts[1] = 20;
        amounts[2] = 30;

        vm.prank(owner);
        items.mintBatch(player, ids, amounts, "");

        assertEq(items.balanceOf(player, wood), 10);
        assertEq(items.balanceOf(player, stone), 20);
        assertEq(items.balanceOf(player, iron), 30);
    }

    function testHolderCanBurnOwnItem() public {
        vm.prank(owner);
        items.mint(player, wood, 10, "");

        vm.prank(player);
        items.burn(player, wood, 4);

        assertEq(items.balanceOf(player, wood), 6);
        assertEq(items.totalSupply(wood), 6);
    }

    function testApprovedOperatorCanBurnItem() public {
        vm.prank(owner);
        items.mint(player, wood, 10, "");

        vm.prank(player);
        items.setApprovalForAll(operator, true);

        vm.prank(operator);
        items.burn(player, wood, 5);

        assertEq(items.balanceOf(player, wood), 5);
    }

    function testUnapprovedOperatorCannotBurnItem() public {
        vm.prank(owner);
        items.mint(player, wood, 10, "");

        vm.prank(operator);
        vm.expectRevert();
        items.burn(player, wood, 5);
    }
}
