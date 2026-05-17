// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ResourceAMM} from "../../contracts/core/ResourceAMM.sol";
import {GameToken} from "../../contracts/tokens/GameToken.sol";

contract ResourceAMMFuzzTest is Test {
    ResourceAMM private amm;
    GameToken private tokenA;
    GameToken private tokenB;

    address private owner = address(this);
    address private liquidityProvider = address(0xB0B);
    address private trader = address(0xCAFE);

    function setUp() public {
        tokenA = new GameToken(owner);
        tokenB = new GameToken(owner);
        amm = new ResourceAMM(owner, address(tokenA), address(tokenB));

        tokenA.mint(liquidityProvider, 1_000_000 ether);
        tokenB.mint(liquidityProvider, 1_000_000 ether);
        tokenA.mint(trader, 1_000_000 ether);
        tokenB.mint(trader, 1_000_000 ether);
    }

    function testFuzzAddLiquidity(uint256 amountA, uint256 amountB) public {
        amountA = bound(amountA, 1 ether, 100_000 ether);
        amountB = bound(amountB, 1 ether, 100_000 ether);

        vm.startPrank(liquidityProvider);
        tokenA.approve(address(amm), amountA);
        tokenB.approve(address(amm), amountB);
        uint256 liquidity = amm.addLiquidity(amountA, amountB, 1);
        vm.stopPrank();

        assertGt(liquidity, 0);
        assertEq(amm.reserveA(), amountA);
        assertEq(amm.reserveB(), amountB);
    }

    function testFuzzSwapAForBPreservesK(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 10_000 ether);

        _addLiquidity(100_000 ether, 100_000 ether);

        uint256 beforeK = amm.reserveA() * amm.reserveB();

        vm.startPrank(trader);
        tokenA.approve(address(amm), amountIn);
        amm.swapExactAForB(amountIn, 1);
        vm.stopPrank();

        uint256 afterK = amm.reserveA() * amm.reserveB();

        assertGe(afterK, beforeK);
    }

    function testFuzzSwapBForAPreservesK(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 10_000 ether);

        _addLiquidity(100_000 ether, 100_000 ether);

        uint256 beforeK = amm.reserveA() * amm.reserveB();

        vm.startPrank(trader);
        tokenB.approve(address(amm), amountIn);
        amm.swapExactBForA(amountIn, 1);
        vm.stopPrank();

        uint256 afterK = amm.reserveA() * amm.reserveB();

        assertGe(afterK, beforeK);
    }

    function testFuzzGetAmountOutIsPositive(uint256 amountIn) public {
        amountIn = bound(amountIn, 1 ether, 10_000 ether);

        _addLiquidity(100_000 ether, 100_000 ether);

        uint256 amountOut = amm.getAmountOut(address(tokenA), amountIn);

        assertGt(amountOut, 0);
        assertLt(amountOut, amm.reserveB());
    }

    function _addLiquidity(uint256 amountA, uint256 amountB) private {
        vm.startPrank(liquidityProvider);
        tokenA.approve(address(amm), amountA);
        tokenB.approve(address(amm), amountB);
        amm.addLiquidity(amountA, amountB, 1);
        vm.stopPrank();
    }
}
