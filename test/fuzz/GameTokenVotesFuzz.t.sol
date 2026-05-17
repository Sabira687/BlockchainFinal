// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameToken} from "../../contracts/tokens/GameToken.sol";

contract GameTokenVotesFuzzTest is Test {
    GameToken private token;

    address private owner = address(this);
    address private voter = address(0xA11CE);
    address private receiver = address(0xB0B);

    function setUp() public {
        token = new GameToken(owner);
        token.mint(voter, 1_000_000 ether);
    }

    function testFuzzDelegatedVotesEqualBalance(uint256 amount) public {
        amount = bound(amount, 1 ether, 500_000 ether);

        vm.prank(voter);
        token.delegate(voter);

        assertGe(token.getVotes(voter), amount);
    }

    function testFuzzVotesDecreaseAfterTransfer(uint256 amount) public {
        amount = bound(amount, 1 ether, 500_000 ether);

        vm.prank(voter);
        token.delegate(voter);

        uint256 beforeVotes = token.getVotes(voter);

        vm.prank(voter);
        token.transfer(receiver, amount);

        assertEq(token.getVotes(voter), beforeVotes - amount);
    }

    function testFuzzReceiverGetsVotesAfterDelegation(uint256 amount) public {
        amount = bound(amount, 1 ether, 500_000 ether);

        vm.prank(voter);
        token.transfer(receiver, amount);

        vm.prank(receiver);
        token.delegate(receiver);

        assertEq(token.getVotes(receiver), amount);
    }
}
