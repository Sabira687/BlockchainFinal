// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ResourceAMM} from "../../../contracts/core/ResourceAMM.sol";
import {GameToken} from "../../../contracts/tokens/GameToken.sol";

contract ResourceAMMTest is Test {
    ResourceAMM private amm;
    GameToken private tokenA;
    GameToken private tokenB;

    address private owner = address(0xA11CE);
    address private liquidityProvider = address(0xB0B);
    address private trader = address(0xCAFE);

    function setUp() public {
        tokenA = new GameToken(owner);
        tokenB = new GameToken(owner);

        amm = new ResourceAMM(owner, address(tokenA), address(tokenB));

        vm.startPrank(owner);
        tokenA.mint(liquidityProvider, 100_000 ether);
        tokenB.mint(liquidityProvider, 100_000 ether);
        tokenA.mint(trader, 10_000 ether);
        tokenB.mint(trader, 10_000 ether);
        vm.stopPrank();
    }

    function testConstructorSetsTokensAndOwner() public view {
        assertEq(address(amm.tokenA()), address(tokenA));
        assertEq(address(amm.tokenB()), address(tokenB));
        assertEq(amm.owner(), owner);
    }

    function testCannotDeployWithZeroAddress() public {
        vm.expectRevert();
        new ResourceAMM(address(0), address(tokenA), address(tokenB));

        vm.expectRevert(ResourceAMM.ZeroAddress.selector);
        new ResourceAMM(owner, address(0), address(tokenB));

        vm.expectRevert(ResourceAMM.ZeroAddress.selector);
        new ResourceAMM(owner, address(tokenA), address(0));
    }

    function testCannotDeployWithSameToken() public {
        vm.expectRevert(ResourceAMM.InvalidToken.selector);
        new ResourceAMM(owner, address(tokenA), address(tokenA));
    }

    function testAddInitialLiquidity() public {
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(amm), 1_000 ether);
        tokenB.approve(address(amm), 1_000 ether);

        uint256 liquidity = amm.addLiquidity(1_000 ether, 1_000 ether, 1);
        vm.stopPrank();

        assertEq(liquidity, 1_000 ether);
        assertEq(amm.balanceOf(liquidityProvider), 1_000 ether);
        assertEq(amm.reserveA(), 1_000 ether);
        assertEq(amm.reserveB(), 1_000 ether);
    }

    function testCannotAddZeroLiquidity() public {
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(amm), 1_000 ether);
        tokenB.approve(address(amm), 1_000 ether);

        vm.expectRevert(ResourceAMM.InvalidAmount.selector);
        amm.addLiquidity(0, 1_000 ether, 1);

        vm.expectRevert(ResourceAMM.InvalidAmount.selector);
        amm.addLiquidity(1_000 ether, 0, 1);
        vm.stopPrank();
    }

    function testAddLiquidityRespectsMinLiquidity() public {
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(amm), 1_000 ether);
        tokenB.approve(address(amm), 1_000 ether);

        vm.expectRevert(ResourceAMM.InvalidLiquidity.selector);
        amm.addLiquidity(1_000 ether, 1_000 ether, 2_000 ether);
        vm.stopPrank();
    }

    function testRemoveLiquidity() public {
        _addLiquidity(1_000 ether, 1_000 ether);

        vm.prank(liquidityProvider);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(500 ether, 1, 1);

        assertEq(amountA, 500 ether);
        assertEq(amountB, 500 ether);
        assertEq(amm.balanceOf(liquidityProvider), 500 ether);
        assertEq(amm.reserveA(), 500 ether);
        assertEq(amm.reserveB(), 500 ether);
    }

    function testRemoveLiquidityRespectsMinimumOutputs() public {
        _addLiquidity(1_000 ether, 1_000 ether);

        vm.prank(liquidityProvider);
        vm.expectRevert(ResourceAMM.InsufficientOutputAmount.selector);
        amm.removeLiquidity(500 ether, 600 ether, 1);
    }

    function testCannotRemoveMoreThanBalance() public {
        _addLiquidity(1_000 ether, 1_000 ether);

        vm.prank(trader);
        vm.expectRevert(ResourceAMM.InsufficientLiquidity.selector);
        amm.removeLiquidity(1 ether, 1, 1);
    }

    function testSwapExactAForB() public {
        _addLiquidity(1_000 ether, 1_000 ether);

        uint256 expectedOut = amm.getAmountOut(address(tokenA), 100 ether);

        vm.startPrank(trader);
        tokenA.approve(address(amm), 100 ether);
        uint256 amountOut = amm.swapExactAForB(100 ether, expectedOut);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(tokenB.balanceOf(trader), 10_000 ether + expectedOut);
        assertEq(amm.reserveA(), 1_100 ether);
        assertEq(amm.reserveB(), 1_000 ether - expectedOut);
    }

    function testSwapExactBForA() public {
        _addLiquidity(1_000 ether, 1_000 ether);

        uint256 expectedOut = amm.getAmountOut(address(tokenB), 100 ether);

        vm.startPrank(trader);
        tokenB.approve(address(amm), 100 ether);
        uint256 amountOut = amm.swapExactBForA(100 ether, expectedOut);
        vm.stopPrank();

        assertEq(amountOut, expectedOut);
        assertEq(tokenA.balanceOf(trader), 10_000 ether + expectedOut);
        assertEq(amm.reserveB(), 1_100 ether);
        assertEq(amm.reserveA(), 1_000 ether - expectedOut);
    }

    function testSwapRespectsSlippageProtection() public {
        _addLiquidity(1_000 ether, 1_000 ether);

        uint256 expectedOut = amm.getAmountOut(address(tokenA), 100 ether);

        vm.startPrank(trader);
        tokenA.approve(address(amm), 100 ether);

        vm.expectRevert(ResourceAMM.InsufficientOutputAmount.selector);
        amm.swapExactAForB(100 ether, expectedOut + 1);
        vm.stopPrank();
    }

    function testCannotSwapWithInvalidToken() public {
        _addLiquidity(1_000 ether, 1_000 ether);

        vm.expectRevert(ResourceAMM.InvalidToken.selector);
        amm.getAmountOut(address(0xDEAD), 100 ether);
    }

    function testConstantProductDoesNotDecreaseAfterSwap() public {
        _addLiquidity(1_000 ether, 1_000 ether);

        uint256 beforeK = amm.reserveA() * amm.reserveB();

        vm.startPrank(trader);
        tokenA.approve(address(amm), 100 ether);
        amm.swapExactAForB(100 ether, 1);
        vm.stopPrank();

        uint256 afterK = amm.reserveA() * amm.reserveB();

        assertGe(afterK, beforeK);
    }

    function _addLiquidity(uint256 amountA, uint256 amountB) private {
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(amm), amountA);
        tokenB.approve(address(amm), amountB);
        amm.addLiquidity(amountA, amountB, 1);
        vm.stopPrank();
    }
}
