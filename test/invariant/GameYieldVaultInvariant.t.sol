// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameYieldVault} from "../../contracts/vault/GameYieldVault.sol";
import {GameToken} from "../../contracts/tokens/GameToken.sol";

contract GameYieldVaultHandler is Test {
    GameYieldVault public vault;
    GameToken public token;

    address public actor = address(0xB0B);

    constructor(GameYieldVault vault_, GameToken token_) {
        vault = vault_;
        token = token_;

        vm.prank(actor);
        token.approve(address(vault), type(uint256).max);
    }

    function deposit(uint256 assets) external {
        assets = bound(assets, 1 ether, 1_000 ether);

        vm.prank(actor);
        vault.deposit(assets, actor);
    }

    function withdraw(uint256 assets) external {
        uint256 maxWithdraw = vault.maxWithdraw(actor);

        if (maxWithdraw == 0) {
            return;
        }

        assets = bound(assets, 1, maxWithdraw);

        vm.prank(actor);
        vault.withdraw(assets, actor, actor);
    }
}

contract GameYieldVaultInvariantTest is Test {
    GameToken private token;
    GameYieldVault private vault;
    GameYieldVaultHandler private handler;

    function setUp() public {
        token = new GameToken(address(this));
        vault = new GameYieldVault(address(this), token);

        token.mint(address(0xB0B), 1_000_000 ether);

        handler = new GameYieldVaultHandler(vault, token);
        targetContract(address(handler));
    }

    function invariantTotalAssetsMatchVaultBalance() public view {
        assertEq(vault.totalAssets(), token.balanceOf(address(vault)));
    }

    function invariantShareSupplyDoesNotExceedAssetsWhenNoRewards() public view {
        assertLe(vault.totalSupply(), vault.totalAssets());
    }
}
