// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ItemRentalVault} from "../../../contracts/vault/ItemRentalVault.sol";
import {GameItems} from "../../../contracts/tokens/GameItems.sol";
import {GameToken} from "../../../contracts/tokens/GameToken.sol";

contract ItemRentalVaultTest is Test {
    GameItems private items;
    GameToken private paymentToken;
    ItemRentalVault private rentalVault;

    address private owner = address(0xA11CE);
    address private lender = address(0xB0B);
    address private renter = address(0xCAFE);
    address private attacker = address(0xBAD);

    uint256 private sword;

    function setUp() public {
        items = new GameItems(address(this), "ipfs://gamefi-items/");
        paymentToken = new GameToken(owner);
        rentalVault = new ItemRentalVault(owner, items, paymentToken);

        sword = items.SWORD();

        items.mint(lender, sword, 5, "");

        vm.prank(owner);
        paymentToken.mint(renter, 10_000 ether);

        vm.prank(lender);
        items.setApprovalForAll(address(rentalVault), true);

        vm.prank(renter);
        paymentToken.approve(address(rentalVault), type(uint256).max);
    }

    function testConstructorSetsState() public view {
        assertEq(address(rentalVault.items()), address(items));
        assertEq(address(rentalVault.paymentToken()), address(paymentToken));
        assertEq(rentalVault.owner(), owner);
    }

    function testLenderCanListItem() public {
        uint256 listingId = _listDefaultItem();

        (address storedLender, uint256 itemId, uint256 amount, uint256 pricePerSecond, bool active) =
            rentalVault.listings(listingId);

        assertEq(storedLender, lender);
        assertEq(itemId, sword);
        assertEq(amount, 2);
        assertEq(pricePerSecond, 1 ether);
        assertTrue(active);
        assertEq(items.balanceOf(address(rentalVault), sword), 2);
    }

    function testCannotListInvalidItem() public {
        vm.startPrank(lender);

        vm.expectRevert(ItemRentalVault.InvalidAmount.selector);
        rentalVault.listItem(0, 1, 1 ether);

        vm.expectRevert(ItemRentalVault.InvalidAmount.selector);
        rentalVault.listItem(sword, 0, 1 ether);

        vm.expectRevert(ItemRentalVault.InvalidAmount.selector);
        rentalVault.listItem(sword, 1, 0);

        vm.stopPrank();
    }

    function testLenderCanCancelListing() public {
        uint256 listingId = _listDefaultItem();

        vm.prank(lender);
        rentalVault.cancelListing(listingId);

        (,, uint256 amount,, bool active) = rentalVault.listings(listingId);

        assertEq(amount, 0);
        assertFalse(active);
        assertEq(items.balanceOf(lender, sword), 5);
    }

    function testNonLenderCannotCancelListing() public {
        uint256 listingId = _listDefaultItem();

        vm.prank(attacker);
        vm.expectRevert(ItemRentalVault.UnauthorizedRenter.selector);
        rentalVault.cancelListing(listingId);
    }

    function testRenterCanRentItem() public {
        uint256 listingId = _listDefaultItem();

        vm.prank(renter);
        uint256 rentalId = rentalVault.rentItem(listingId, 1, 10);

        (address storedRenter, uint256 storedListingId, uint256 amount, uint256 endTime, bool returned) =
            rentalVault.rentals(rentalId);

        assertEq(storedRenter, renter);
        assertEq(storedListingId, listingId);
        assertEq(amount, 1);
        assertEq(endTime, block.timestamp + 10);
        assertFalse(returned);
        assertEq(items.balanceOf(renter, sword), 1);
        assertEq(rentalVault.claimableEarnings(lender), 10 ether);
    }

    function testCannotRentInactiveListing() public {
        uint256 listingId = _listDefaultItem();

        vm.prank(lender);
        rentalVault.cancelListing(listingId);

        vm.prank(renter);
        vm.expectRevert(ItemRentalVault.ListingNotActive.selector);
        rentalVault.rentItem(listingId, 1, 10);
    }

    function testCannotRentInvalidAmountOrDuration() public {
        uint256 listingId = _listDefaultItem();

        vm.startPrank(renter);

        vm.expectRevert(ItemRentalVault.InvalidAmount.selector);
        rentalVault.rentItem(listingId, 0, 10);

        vm.expectRevert(ItemRentalVault.InvalidDuration.selector);
        rentalVault.rentItem(listingId, 1, 0);

        vm.stopPrank();
    }

    function testCannotRentMoreThanListed() public {
        uint256 listingId = _listDefaultItem();

        vm.prank(renter);
        vm.expectRevert(ItemRentalVault.InsufficientListedAmount.selector);
        rentalVault.rentItem(listingId, 3, 10);
    }

    function testRenterCanReturnAfterExpiry() public {
        uint256 rentalId = _rentDefaultItem();

        vm.warp(block.timestamp + 11);

        vm.prank(renter);
        items.setApprovalForAll(address(rentalVault), true);

        vm.prank(renter);
        rentalVault.returnItem(rentalId);

        (,,,, bool returned) = rentalVault.rentals(rentalId);
        (,, uint256 amount,, bool active) = rentalVault.listings(1);

        assertTrue(returned);
        assertEq(amount, 2);
        assertTrue(active);
        assertEq(items.balanceOf(address(rentalVault), sword), 2);
    }

    function testCannotReturnBeforeExpiry() public {
        uint256 rentalId = _rentDefaultItem();

        vm.prank(renter);
        vm.expectRevert(ItemRentalVault.RentalNotExpired.selector);
        rentalVault.returnItem(rentalId);
    }

    function testNonRenterCannotReturn() public {
        uint256 rentalId = _rentDefaultItem();

        vm.warp(block.timestamp + 11);

        vm.prank(attacker);
        vm.expectRevert(ItemRentalVault.UnauthorizedRenter.selector);
        rentalVault.returnItem(rentalId);
    }

    function testCannotReturnSameRentalTwice() public {
        uint256 rentalId = _rentDefaultItem();

        vm.warp(block.timestamp + 11);

        vm.startPrank(renter);
        items.setApprovalForAll(address(rentalVault), true);
        rentalVault.returnItem(rentalId);

        vm.expectRevert(ItemRentalVault.RentalAlreadyReturned.selector);
        rentalVault.returnItem(rentalId);
        vm.stopPrank();
    }

    function testLenderCanClaimEarnings() public {
        _rentDefaultItem();

        uint256 beforeBalance = paymentToken.balanceOf(lender);

        vm.prank(lender);
        rentalVault.claimEarnings();

        assertEq(paymentToken.balanceOf(lender), beforeBalance + 10 ether);
        assertEq(rentalVault.claimableEarnings(lender), 0);
    }

    function testCannotClaimZeroEarnings() public {
        vm.prank(lender);
        vm.expectRevert(ItemRentalVault.NothingToClaim.selector);
        rentalVault.claimEarnings();
    }

    function _listDefaultItem() private returns (uint256 listingId) {
        vm.prank(lender);
        listingId = rentalVault.listItem(sword, 2, 1 ether);
    }

    function _rentDefaultItem() private returns (uint256 rentalId) {
        uint256 listingId = _listDefaultItem();

        vm.prank(renter);
        rentalId = rentalVault.rentItem(listingId, 1, 10);
    }
}
