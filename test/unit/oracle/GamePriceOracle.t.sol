// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GamePriceOracle} from "../../../contracts/oracle/GamePriceOracle.sol";
import {MockV3Aggregator} from "../../../contracts/oracle/MockV3Aggregator.sol";

contract GamePriceOracleTest is Test {
    MockV3Aggregator private feed;
    GamePriceOracle private oracle;

    function setUp() public {
        feed = new MockV3Aggregator(8, 2_000e8);
        oracle = new GamePriceOracle(address(feed), 1 hours);
    }

    function testConstructorSetsState() public view {
        assertEq(address(oracle.priceFeed()), address(feed));
        assertEq(oracle.maxStaleness(), 1 hours);
    }

    function testCannotDeployWithZeroFeed() public {
        vm.expectRevert(GamePriceOracle.ZeroAddress.selector);
        new GamePriceOracle(address(0), 1 hours);
    }

    function testReturnsLatestPriceAndDecimals() public view {
        (uint256 price, uint8 decimals) = oracle.getLatestPrice();

        assertEq(price, 2_000e8);
        assertEq(decimals, 8);
    }

    function testReturnsUpdatedPrice() public {
        feed.updateAnswer(2_500e8);

        (uint256 price, uint8 decimals) = oracle.getLatestPrice();

        assertEq(price, 2_500e8);
        assertEq(decimals, 8);
    }

    function testRevertsOnZeroPrice() public {
        feed.updateAnswer(0);

        vm.expectRevert(GamePriceOracle.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function testRevertsOnNegativePrice() public {
        feed.updateAnswer(-1);

        vm.expectRevert(GamePriceOracle.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function testRevertsOnIncompleteRound() public {
        feed.updateIncompleteRound(2_000e8);

        vm.expectRevert(GamePriceOracle.InvalidPrice.selector);
        oracle.getLatestPrice();
    }

    function testRevertsOnStalePrice() public {
        vm.warp(10 hours);
        feed.updateStaleAnswer(2_000e8, block.timestamp - 2 hours);

        vm.expectRevert(GamePriceOracle.StalePrice.selector);
        oracle.getLatestPrice();
    }

    function testFreshPriceAfterTimeWarpStillValidWithinLimit() public {
        feed.updateAnswer(2_000e8);

        vm.warp(block.timestamp + 30 minutes);

        (uint256 price, uint8 decimals) = oracle.getLatestPrice();

        assertEq(price, 2_000e8);
        assertEq(decimals, 8);
    }
}
