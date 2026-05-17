// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameYieldVault} from "../../../contracts/vault/GameYieldVault.sol";
import {GameToken} from "../../../contracts/tokens/GameToken.sol";

contract GameYieldVaultTest is Test {
    GameToken private token;
    GameYieldVault private vault;

    address private owner = address(0xA11CE);
    address private player = address(0xB0B);
    address private secondPlayer = address(0xCAFE);

    function setUp() public {
        token = new GameToken(owner);
        vault = new GameYieldVault(owner, token);

        vm.startPrank(owner);
        token.mint(player, 10_000 ether);
        token.mint(secondPlayer, 10_000 ether);
        vm.stopPrank();
    }

    function testConstructorSetsMetadataAndAsset() public view {
        assertEq(vault.name(), "GameFi Yield Vault Share");
        assertEq(vault.symbol(), "gGAME");
        assertEq(vault.asset(), address(token));
        assertEq(vault.owner(), owner);
    }

    function testCannotDeployWithZeroOwner() public {
        vm.expectRevert();
        new GameYieldVault(address(0), token);
    }

    function testDepositMintsShares() public {
        vm.startPrank(player);
        token.approve(address(vault), 1_000 ether);
        uint256 shares = vault.deposit(1_000 ether, player);
        vm.stopPrank();

        assertEq(shares, 1_000 ether);
        assertEq(vault.balanceOf(player), 1_000 ether);
        assertEq(vault.totalAssets(), 1_000 ether);
    }

    function testMintTransfersAssets() public {
        vm.startPrank(player);
        token.approve(address(vault), 1_000 ether);
        uint256 assets = vault.mint(1_000 ether, player);
        vm.stopPrank();

        assertEq(assets, 1_000 ether);
        assertEq(vault.balanceOf(player), 1_000 ether);
        assertEq(vault.totalAssets(), 1_000 ether);
    }

    function testWithdrawBurnsShares() public {
        vm.startPrank(player);
        token.approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether, player);
        uint256 sharesBurned = vault.withdraw(400 ether, player, player);
        vm.stopPrank();

        assertEq(sharesBurned, 400 ether);
        assertEq(vault.balanceOf(player), 600 ether);
        assertEq(token.balanceOf(player), 9_400 ether);
    }

    function testRedeemReturnsAssets() public {
        vm.startPrank(player);
        token.approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether, player);
        uint256 assets = vault.redeem(400 ether, player, player);
        vm.stopPrank();

        assertEq(assets, 400 ether);
        assertEq(vault.balanceOf(player), 600 ether);
        assertEq(token.balanceOf(player), 9_400 ether);
    }

    function testOwnerCanAddRewards() public {
        vm.startPrank(player);
        token.approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether, player);
        vm.stopPrank();

        vm.startPrank(owner);
        token.approve(address(vault), 500 ether);
        vault.addRewards(500 ether);
        vm.stopPrank();

        assertEq(vault.totalAssets(), 1_500 ether);
        assertApproxEqAbs(vault.convertToAssets(1_000 ether), 1_500 ether, 1);
    }

    function testNonOwnerCannotAddRewards() public {
        vm.startPrank(player);
        token.approve(address(vault), 100 ether);
        vm.expectRevert();
        vault.addRewards(100 ether);
        vm.stopPrank();
    }

    function testCannotAddZeroRewards() public {
        vm.prank(owner);
        vm.expectRevert(GameYieldVault.InvalidAmount.selector);
        vault.addRewards(0);
    }

    function testDepositAfterRewardsReceivesFewerShares() public {
        vm.startPrank(player);
        token.approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether, player);
        vm.stopPrank();

        vm.startPrank(owner);
        token.approve(address(vault), 1_000 ether);
        vault.addRewards(1_000 ether);
        vm.stopPrank();

        vm.startPrank(secondPlayer);
        token.approve(address(vault), 1_000 ether);
        uint256 shares = vault.deposit(1_000 ether, secondPlayer);
        vm.stopPrank();

        assertEq(shares, 500 ether);
        assertEq(vault.balanceOf(secondPlayer), 500 ether);
    }

    function testPreviewDepositMatchesDepositShares() public {
        uint256 preview = vault.previewDeposit(1_000 ether);

        vm.startPrank(player);
        token.approve(address(vault), 1_000 ether);
        uint256 shares = vault.deposit(1_000 ether, player);
        vm.stopPrank();

        assertEq(shares, preview);
    }

    function testPreviewRedeemMatchesRedeemAssets() public {
        vm.startPrank(player);
        token.approve(address(vault), 1_000 ether);
        vault.deposit(1_000 ether, player);

        uint256 preview = vault.previewRedeem(250 ether);
        uint256 assets = vault.redeem(250 ether, player, player);
        vm.stopPrank();

        assertEq(assets, preview);
    }
}
