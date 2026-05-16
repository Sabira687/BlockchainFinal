// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameToken} from "../../../contracts/tokens/GameToken.sol";

contract GameTokenTest is Test {
    GameToken private token;

    address private owner = address(0xA11CE);
    address private player = address(0xB0B);

    function setUp() public {
        token = new GameToken(owner);
    }

    function testConstructorMintsInitialSupplyToOwner() public view {
        assertEq(token.balanceOf(owner), token.INITIAL_SUPPLY());
        assertEq(token.totalSupply(), token.INITIAL_SUPPLY());
        assertEq(token.owner(), owner);
    }

    function testTokenMetadataIsCorrect() public view {
        assertEq(token.name(), "GameFi Governance Token");
        assertEq(token.symbol(), "GAME");
        assertEq(token.decimals(), 18);
    }

    function testOwnerCanMint() public {
        vm.prank(owner);
        token.mint(player, 100 ether);

        assertEq(token.balanceOf(player), 100 ether);
    }

    function testNonOwnerCannotMint() public {
        vm.prank(player);
        vm.expectRevert();
        token.mint(player, 100 ether);
    }

    function testCannotMintToZeroAddress() public {
        vm.prank(owner);
        vm.expectRevert(GameToken.ZeroAddress.selector);
        token.mint(address(0), 100 ether);
    }

    function testConstructorRejectsZeroOwner() public {
        vm.expectRevert();
        new GameToken(address(0));
    }

    function testHolderCanDelegateVotingPower() public {
        vm.prank(owner);
        token.transfer(player, 1_000 ether);

        vm.prank(player);
        token.delegate(player);

        assertEq(token.getVotes(player), 1_000 ether);
    }

    function testVotingPowerMovesAfterTransfer() public {
        address secondPlayer = address(0xCAFE);

        vm.prank(owner);
        token.transfer(player, 1_000 ether);

        vm.prank(player);
        token.delegate(player);

        assertEq(token.getVotes(player), 1_000 ether);

        vm.prank(player);
        token.transfer(secondPlayer, 400 ether);

        assertEq(token.getVotes(player), 600 ether);
    }
}
