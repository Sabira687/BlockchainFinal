// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameYieldVault} from "../../contracts/vault/GameYieldVault.sol";
import {GameToken} from "../../contracts/tokens/GameToken.sol";

contract GameYieldVaultFuzzTest is Test {
    GameToken private token;
    GameYieldVault private vault;

    address private owner = address(this);
    address private player = address(0xB0B);

    function setUp() public {
        token = new GameToken(owner);
        vault = new GameYieldVault(owner, token);

        token.mint(player, 1_000_000 ether);
    }

    function testFuzzDepositMintsNonZeroShares(uint256 assets) public {
        assets = bound(assets, 1 ether, 100_000 ether);

        vm.startPrank(player);
        token.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, player);
        vm.stopPrank();

        assertGt(shares, 0);
        assertEq(vault.totalAssets(), assets);
    }

    function testFuzzWithdrawReturnsAssets(uint256 assets, uint256 withdrawAmount) public {
        assets = bound(assets, 10 ether, 100_000 ether);
        withdrawAmount = bound(withdrawAmount, 1 ether, assets);

        vm.startPrank(player);
        token.approve(address(vault), assets);
        vault.deposit(assets, player);

        uint256 beforeBalance = token.balanceOf(player);
        vault.withdraw(withdrawAmount, player, player);
        vm.stopPrank();

        assertEq(token.balanceOf(player), beforeBalance + withdrawAmount);
    }

    function testFuzzRedeemBurnsShares(uint256 assets, uint256 sharesToRedeem) public {
        assets = bound(assets, 10 ether, 100_000 ether);

        vm.startPrank(player);
        token.approve(address(vault), assets);
        uint256 shares = vault.deposit(assets, player);

        sharesToRedeem = bound(sharesToRedeem, 1 ether, shares);
        vault.redeem(sharesToRedeem, player, player);
        vm.stopPrank();

        assertEq(vault.balanceOf(player), shares - sharesToRedeem);
    }
}
