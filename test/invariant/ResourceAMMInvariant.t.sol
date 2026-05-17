// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ResourceAMM} from "../../contracts/core/ResourceAMM.sol";
import {GameToken} from "../../contracts/tokens/GameToken.sol";

contract ResourceAMMHandler is Test {
    ResourceAMM public amm;
    GameToken public tokenA;
    GameToken public tokenB;

    address public actor = address(0xB0B);

    constructor(ResourceAMM amm_, GameToken tokenA_, GameToken tokenB_) {
        amm = amm_;
        tokenA = tokenA_;
        tokenB = tokenB_;

        vm.startPrank(actor);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        amm.addLiquidity(100_000 ether, 100_000 ether, 1);
        vm.stopPrank();
    }

    function swapAForB(uint256 amountIn) external {
        amountIn = bound(amountIn, 1 ether, 1_000 ether);

        vm.prank(actor);
        amm.swapExactAForB(amountIn, 1);
    }

    function swapBForA(uint256 amountIn) external {
        amountIn = bound(amountIn, 1 ether, 1_000 ether);

        vm.prank(actor);
        amm.swapExactBForA(amountIn, 1);
    }
}

contract ResourceAMMInvariantTest is Test {
    ResourceAMM private amm;
    GameToken private tokenA;
    GameToken private tokenB;
    ResourceAMMHandler private handler;

    uint256 private initialK;

    function setUp() public {
        tokenA = new GameToken(address(this));
        tokenB = new GameToken(address(this));
        amm = new ResourceAMM(address(this), address(tokenA), address(tokenB));

        tokenA.mint(address(0xB0B), 1_000_000 ether);
        tokenB.mint(address(0xB0B), 1_000_000 ether);

        handler = new ResourceAMMHandler(amm, tokenA, tokenB);
        targetContract(address(handler));

        initialK = amm.reserveA() * amm.reserveB();
    }

    function invariantConstantProductNeverDecreases() public view {
        assertGe(amm.reserveA() * amm.reserveB(), initialK);
    }

    function invariantReservesMatchTokenBalances() public view {
        assertEq(tokenA.balanceOf(address(amm)), amm.reserveA());
        assertEq(tokenB.balanceOf(address(amm)), amm.reserveB());
    }
}
