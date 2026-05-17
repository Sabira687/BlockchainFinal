// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {GameToken} from "../../contracts/tokens/GameToken.sol";

contract GameTokenInvariantTest is Test {
    GameToken private token;

    address private owner = address(this);
    address private player = address(0xB0B);

    function setUp() public {
        token = new GameToken(owner);
        token.mint(player, 1_000 ether);
    }

    function invariantTotalSupplyAtLeastInitialSupply() public view {
        assertGe(token.totalSupply(), token.INITIAL_SUPPLY());
    }
}
