// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {GameConfigV1} from "../../../contracts/upgrade/GameConfigV1.sol";
import {GameConfigV2} from "../../../contracts/upgrade/GameConfigV2.sol";

contract GameConfigUpgradeTest is Test {
    GameConfigV1 private implementationV1;
    GameConfigV2 private implementationV2;
    GameConfigV1 private configV1;
    GameConfigV2 private configV2;

    address private owner = address(0xA11CE);
    address private treasury = address(0xB0B);
    address private attacker = address(0xBAD);

    function setUp() public {
        implementationV1 = new GameConfigV1();

        bytes memory initData = abi.encodeCall(GameConfigV1.initialize, (owner, treasury, 1 ether, 2 ether));

        ERC1967Proxy proxy = new ERC1967Proxy(address(implementationV1), initData);

        configV1 = GameConfigV1(address(proxy));
    }

    function testInitialStateThroughProxy() public view {
        assertEq(configV1.owner(), owner);
        assertEq(configV1.treasury(), treasury);
        assertEq(configV1.craftingFee(), 1 ether);
        assertEq(configV1.lootBoxPrice(), 2 ether);
        assertEq(configV1.version(), 1);
    }

    function testOwnerCanUpdateV1Config() public {
        vm.startPrank(owner);
        configV1.setCraftingFee(3 ether);
        configV1.setLootBoxPrice(4 ether);
        configV1.setTreasury(address(0xCAFE));
        vm.stopPrank();

        assertEq(configV1.craftingFee(), 3 ether);
        assertEq(configV1.lootBoxPrice(), 4 ether);
        assertEq(configV1.treasury(), address(0xCAFE));
    }

    function testNonOwnerCannotUpdateV1Config() public {
        vm.startPrank(attacker);

        vm.expectRevert();
        configV1.setCraftingFee(3 ether);

        vm.expectRevert();
        configV1.setLootBoxPrice(4 ether);

        vm.expectRevert();
        configV1.setTreasury(address(0xCAFE));

        vm.stopPrank();
    }

    function testCannotSetZeroTreasury() public {
        vm.prank(owner);
        vm.expectRevert(GameConfigV1.ZeroAddress.selector);
        configV1.setTreasury(address(0));
    }

    function testOwnerCanUpgradeToV2AndKeepStorage() public {
        implementationV2 = new GameConfigV2();

        vm.prank(owner);
        configV1.upgradeToAndCall(address(implementationV2), "");

        configV2 = GameConfigV2(address(configV1));

        assertEq(configV2.owner(), owner);
        assertEq(configV2.treasury(), treasury);
        assertEq(configV2.craftingFee(), 1 ether);
        assertEq(configV2.lootBoxPrice(), 2 ether);
        assertEq(configV2.version(), 2);

        vm.prank(owner);
        configV2.setRentalFee(5 ether);

        assertEq(configV2.rentalFee(), 5 ether);
    }

    function testNonOwnerCannotUpgrade() public {
        implementationV2 = new GameConfigV2();

        vm.prank(attacker);
        vm.expectRevert();
        configV1.upgradeToAndCall(address(implementationV2), "");
    }

    function testProxyCannotBeInitializedTwice() public {
        vm.expectRevert();
        configV1.initialize(owner, treasury, 1 ether, 2 ether);
    }
}
