// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {LootBox} from "../../../contracts/core/LootBox.sol";
import {GameItems} from "../../../contracts/tokens/GameItems.sol";
import {MockRandomnessProvider} from "../../../contracts/oracle/MockRandomnessProvider.sol";

contract LootBoxTest is Test {
    GameItems private items;
    LootBox private lootBox;
    MockRandomnessProvider private randomnessProvider;

    address private owner = address(0xA11CE);
    address private player = address(0xB0B);
    address private attacker = address(0xBAD);

    uint256 private lootBoxItemId;
    uint256 private wood;
    uint256 private crystal;
    uint256 private relic;

    function setUp() public {
        items = new GameItems(address(this), "ipfs://gamefi-items/");
        randomnessProvider = new MockRandomnessProvider();

        lootBoxItemId = items.LEGENDARY_RELIC();
        wood = items.WOOD();
        crystal = items.CRYSTAL();
        relic = items.LEGENDARY_RELIC();

        lootBox = new LootBox(owner, items, address(randomnessProvider), lootBoxItemId);

        items.mint(player, lootBoxItemId, 3, "");

        vm.prank(player);
        items.setApprovalForAll(address(lootBox), true);

        items.transferOwnership(address(lootBox));
    }

    function testConstructorSetsState() public view {
        assertEq(address(lootBox.items()), address(items));
        assertEq(address(lootBox.randomnessProvider()), address(randomnessProvider));
        assertEq(lootBox.lootBoxItemId(), lootBoxItemId);
        assertEq(lootBox.owner(), owner);
    }

    function testOwnerCanSetDrops() public {
        LootBox.Drop[] memory drops = _defaultDrops();

        vm.prank(owner);
        lootBox.setDrops(drops);

        assertEq(lootBox.totalWeight(), 100);
        assertEq(lootBox.getDropCount(), 3);

        (uint256 itemId, uint256 amount, uint256 weight) = lootBox.getDrop(0);

        assertEq(itemId, wood);
        assertEq(amount, 10);
        assertEq(weight, 70);
    }

    function testNonOwnerCannotSetDrops() public {
        LootBox.Drop[] memory drops = _defaultDrops();

        vm.prank(player);
        vm.expectRevert();
        lootBox.setDrops(drops);
    }

    function testCannotSetInvalidDrops() public {
        LootBox.Drop[] memory drops = new LootBox.Drop[](1);
        drops[0] = LootBox.Drop({itemId: 0, amount: 1, weight: 1});

        vm.prank(owner);
        vm.expectRevert(LootBox.InvalidDrop.selector);
        lootBox.setDrops(drops);
    }

    function testPlayerCanOpenLootBox() public {
        _setDefaultDrops();

        vm.prank(player);
        uint256 requestId = lootBox.openLootBox();

        assertEq(requestId, 1);
        assertEq(items.balanceOf(player, lootBoxItemId), 2);
        assertEq(lootBox.pendingRequests(player), 1);
    }

    function testCannotOpenWithoutDrops() public {
        vm.prank(player);
        vm.expectRevert(LootBox.NoDropsConfigured.selector);
        lootBox.openLootBox();
    }

    function testCannotOpenWithPendingRequest() public {
        _setDefaultDrops();

        vm.prank(player);
        lootBox.openLootBox();

        vm.prank(player);
        vm.expectRevert(LootBox.PendingRequestExists.selector);
        lootBox.openLootBox();
    }

    function testProviderCanFulfillRandomness() public {
        _setDefaultDrops();

        vm.prank(player);
        uint256 requestId = lootBox.openLootBox();

        vm.prank(address(randomnessProvider));
        lootBox.fulfillRandomness(requestId, 1);

        assertEq(lootBox.pendingRequests(player), 0);
        assertEq(items.balanceOf(player, wood), 10);
    }

    function testDifferentRandomnessCanSelectDifferentDrop() public {
        _setDefaultDrops();

        vm.prank(player);
        uint256 requestId = lootBox.openLootBox();

        vm.prank(address(randomnessProvider));
        lootBox.fulfillRandomness(requestId, 95);

        assertEq(items.balanceOf(player, relic), 3);
    }

    function testNonProviderCannotFulfillRandomness() public {
        _setDefaultDrops();

        vm.prank(player);
        uint256 requestId = lootBox.openLootBox();

        vm.prank(attacker);
        vm.expectRevert(LootBox.UnauthorizedProvider.selector);
        lootBox.fulfillRandomness(requestId, 1);
    }

    function testCannotFulfillMissingRequest() public {
        _setDefaultDrops();

        vm.prank(address(randomnessProvider));
        vm.expectRevert(LootBox.RequestNotFound.selector);
        lootBox.fulfillRandomness(999, 1);
    }

    function testCannotFulfillSameRequestTwice() public {
        _setDefaultDrops();

        vm.prank(player);
        uint256 requestId = lootBox.openLootBox();

        vm.prank(address(randomnessProvider));
        lootBox.fulfillRandomness(requestId, 1);

        vm.prank(address(randomnessProvider));
        vm.expectRevert(LootBox.RequestAlreadyFulfilled.selector);
        lootBox.fulfillRandomness(requestId, 1);
    }

    function testCannotOpenWhenPaused() public {
        _setDefaultDrops();

        vm.prank(owner);
        lootBox.pause();

        vm.prank(player);
        vm.expectRevert();
        lootBox.openLootBox();
    }

    function testOwnerCanUnpause() public {
        vm.prank(owner);
        lootBox.pause();

        vm.prank(owner);
        lootBox.unpause();

        assertFalse(lootBox.paused());
    }

    function _setDefaultDrops() private {
        LootBox.Drop[] memory drops = _defaultDrops();

        vm.prank(owner);
        lootBox.setDrops(drops);
    }

    function _defaultDrops() private view returns (LootBox.Drop[] memory drops) {
        drops = new LootBox.Drop[](3);

        drops[0] = LootBox.Drop({itemId: wood, amount: 10, weight: 70});
        drops[1] = LootBox.Drop({itemId: crystal, amount: 3, weight: 25});
        drops[2] = LootBox.Drop({itemId: relic, amount: 1, weight: 5});
    }
}
