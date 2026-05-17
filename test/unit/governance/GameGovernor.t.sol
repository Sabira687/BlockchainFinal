// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {GameGovernor} from "../../../contracts/governance/GameGovernor.sol";
import {GameToken} from "../../../contracts/tokens/GameToken.sol";
import {CraftingSystem} from "../../../contracts/core/CraftingSystem.sol";
import {GameItems} from "../../../contracts/tokens/GameItems.sol";

contract GameGovernorTest is Test {
    GameToken private token;
    TimelockController private timelock;
    GameGovernor private governor;
    GameItems private items;
    CraftingSystem private crafting;

    address private deployer = address(this);
    address private voter = address(0xA11CE);
    address private proposer = address(0xB0B);

    bytes32 private constant PROPOSER_ROLE = keccak256("PROPOSER_ROLE");
    bytes32 private constant EXECUTOR_ROLE = keccak256("EXECUTOR_ROLE");
    bytes32 private constant CANCELLER_ROLE = keccak256("CANCELLER_ROLE");
    bytes32 private constant DEFAULT_ADMIN_ROLE = 0x00;

    function setUp() public {
        token = new GameToken(deployer);

        address[] memory proposers = new address[](0);
        address[] memory executors = new address[](0);

        timelock = new TimelockController(2 days, proposers, executors, deployer);
        governor = new GameGovernor(token, timelock);

        timelock.grantRole(PROPOSER_ROLE, address(governor));
        timelock.grantRole(EXECUTOR_ROLE, address(0));
        timelock.grantRole(CANCELLER_ROLE, address(governor));
        timelock.revokeRole(DEFAULT_ADMIN_ROLE, deployer);

        token.transfer(voter, 600_000 ether);
        token.transfer(proposer, 100_000 ether);

        vm.prank(voter);
        token.delegate(voter);

        vm.prank(proposer);
        token.delegate(proposer);

        items = new GameItems(address(this), "ipfs://gamefi-items/");
        crafting = new CraftingSystem(address(timelock), items);
    }

    function testGovernorParameters() public view {
        assertEq(governor.name(), "GameFi Governor");
        assertEq(governor.votingDelay(), 1 days);
        assertEq(governor.votingPeriod(), 1 weeks);
        assertEq(governor.proposalThreshold(), 10_000 ether);
        assertEq(timelock.getMinDelay(), 2 days);
    }

    function testTimelockRolesConfigured() public view {
        assertTrue(timelock.hasRole(PROPOSER_ROLE, address(governor)));
        assertTrue(timelock.hasRole(EXECUTOR_ROLE, address(0)));
        assertTrue(timelock.hasRole(CANCELLER_ROLE, address(governor)));
        assertFalse(timelock.hasRole(DEFAULT_ADMIN_ROLE, deployer));
    }

    function testFullGovernanceLifecycle() public {
        uint256 wood = items.WOOD();
        uint256 stone = items.STONE();
        uint256 sword = items.SWORD();

        uint256[] memory inputIds = new uint256[](2);
        uint256[] memory inputAmounts = new uint256[](2);

        inputIds[0] = wood;
        inputIds[1] = stone;
        inputAmounts[0] = 3;
        inputAmounts[1] = 2;

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(crafting);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(CraftingSystem.setRecipe, (1, inputIds, inputAmounts, sword, 1, true));

        string memory description = "Set sword crafting recipe";

        vm.roll(block.number + 1);

        vm.prank(proposer);
        uint256 proposalId = governor.propose(targets, values, calldatas, description);

        assertEq(uint256(governor.state(proposalId)), 0);

        vm.roll(block.number + governor.votingDelay() + 1);

        assertEq(uint256(governor.state(proposalId)), 1);

        vm.prank(voter);
        governor.castVote(proposalId, 1);

        vm.prank(proposer);
        governor.castVote(proposalId, 1);

        vm.roll(block.number + governor.votingPeriod() + 1);

        assertEq(uint256(governor.state(proposalId)), 4);

        bytes32 descriptionHash = keccak256(bytes(description));

        governor.queue(targets, values, calldatas, descriptionHash);

        assertEq(uint256(governor.state(proposalId)), 5);

        vm.warp(block.timestamp + timelock.getMinDelay() + 1);

        governor.execute(targets, values, calldatas, descriptionHash);

        assertEq(uint256(governor.state(proposalId)), 7);

        (
            uint256[] memory storedIds,
            uint256[] memory storedAmounts,
            uint256 outputId,
            uint256 outputAmount,
            bool active
        ) = crafting.getRecipe(1);

        assertEq(storedIds[0], wood);
        assertEq(storedIds[1], stone);
        assertEq(storedAmounts[0], 3);
        assertEq(storedAmounts[1], 2);
        assertEq(outputId, sword);
        assertEq(outputAmount, 1);
        assertTrue(active);
    }

    function testProposalBelowThresholdFails() public {
        address smallHolder = address(0xCAFE);

        token.transfer(smallHolder, 1 ether);

        vm.prank(smallHolder);
        token.delegate(smallHolder);

        vm.roll(block.number + 1);

        address[] memory targets = new address[](1);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);

        targets[0] = address(crafting);
        values[0] = 0;
        calldatas[0] = abi.encodeCall(CraftingSystem.pause, ());

        vm.prank(smallHolder);
        vm.expectRevert();
        governor.propose(targets, values, calldatas, "Pause crafting");
    }
}
