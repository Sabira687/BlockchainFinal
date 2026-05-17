// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC1155Receiver} from "@openzeppelin/contracts/token/ERC1155/IERC1155Receiver.sol";
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {GameItems} from "../tokens/GameItems.sol";

contract ItemRentalVault is ERC1155Holder, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    GameItems public immutable items;
    IERC20 public immutable paymentToken;

    struct Listing {
        address lender;
        uint256 itemId;
        uint256 amount;
        uint256 pricePerSecond;
        bool active;
    }

    struct Rental {
        address renter;
        uint256 listingId;
        uint256 amount;
        uint256 endTime;
        bool returned;
    }

    uint256 public nextListingId = 1;
    uint256 public nextRentalId = 1;

    mapping(uint256 listingId => Listing listing) public listings;
    mapping(uint256 rentalId => Rental rental) public rentals;
    mapping(address lender => uint256 earnings) public claimableEarnings;

    error ZeroAddress();
    error InvalidAmount();
    error InvalidDuration();
    error ListingNotActive();
    error InsufficientListedAmount();
    error RentalNotFound();
    error UnauthorizedRenter();
    error RentalNotExpired();
    error RentalAlreadyReturned();
    error NothingToClaim();

    event ItemListed(
        uint256 indexed listingId,
        address indexed lender,
        uint256 indexed itemId,
        uint256 amount,
        uint256 pricePerSecond
    );
    event ListingCancelled(uint256 indexed listingId);
    event ItemRented(
        uint256 indexed rentalId,
        uint256 indexed listingId,
        address indexed renter,
        uint256 amount,
        uint256 endTime,
        uint256 totalPrice
    );
    event ItemReturned(uint256 indexed rentalId, address indexed renter);
    event EarningsClaimed(address indexed lender, uint256 amount);

    constructor(address initialOwner, GameItems items_, IERC20 paymentToken_) Ownable(initialOwner) {
        if (initialOwner == address(0) || address(items_) == address(0) || address(paymentToken_) == address(0)) {
            revert ZeroAddress();
        }

        items = items_;
        paymentToken = paymentToken_;
    }

    function listItem(uint256 itemId, uint256 amount, uint256 pricePerSecond)
        external
        nonReentrant
        returns (uint256 listingId)
    {
        if (itemId == 0 || amount == 0 || pricePerSecond == 0) {
            revert InvalidAmount();
        }

        listingId = nextListingId;
        nextListingId++;

        listings[listingId] =
            Listing({lender: msg.sender, itemId: itemId, amount: amount, pricePerSecond: pricePerSecond, active: true});

        items.safeTransferFrom(msg.sender, address(this), itemId, amount, "");

        emit ItemListed(listingId, msg.sender, itemId, amount, pricePerSecond);
    }

    function cancelListing(uint256 listingId) external nonReentrant {
        Listing storage listing = listings[listingId];

        if (!listing.active) {
            revert ListingNotActive();
        }

        if (msg.sender != listing.lender) {
            revert UnauthorizedRenter();
        }

        uint256 amount = listing.amount;
        listing.amount = 0;
        listing.active = false;

        items.safeTransferFrom(address(this), listing.lender, listing.itemId, amount, "");

        emit ListingCancelled(listingId);
    }

    function rentItem(uint256 listingId, uint256 amount, uint256 duration)
        external
        nonReentrant
        returns (uint256 rentalId)
    {
        Listing storage listing = listings[listingId];

        if (!listing.active) {
            revert ListingNotActive();
        }

        if (amount == 0) {
            revert InvalidAmount();
        }

        if (duration == 0) {
            revert InvalidDuration();
        }

        if (amount > listing.amount) {
            revert InsufficientListedAmount();
        }

        uint256 totalPrice = amount * duration * listing.pricePerSecond;

        listing.amount -= amount;

        if (listing.amount == 0) {
            listing.active = false;
        }

        rentalId = nextRentalId;
        nextRentalId++;

        rentals[rentalId] = Rental({
            renter: msg.sender,
            listingId: listingId,
            amount: amount,
            endTime: block.timestamp + duration,
            returned: false
        });

        claimableEarnings[listing.lender] += totalPrice;

        paymentToken.safeTransferFrom(msg.sender, address(this), totalPrice);
        items.safeTransferFrom(address(this), msg.sender, listing.itemId, amount, "");

        emit ItemRented(rentalId, listingId, msg.sender, amount, block.timestamp + duration, totalPrice);
    }

    function returnItem(uint256 rentalId) external nonReentrant {
        Rental storage rental = rentals[rentalId];

        if (rental.renter == address(0)) {
            revert RentalNotFound();
        }

        if (msg.sender != rental.renter) {
            revert UnauthorizedRenter();
        }

        if (rental.returned) {
            revert RentalAlreadyReturned();
        }

        if (block.timestamp < rental.endTime) {
            revert RentalNotExpired();
        }

        Listing storage listing = listings[rental.listingId];

        rental.returned = true;
        listing.amount += rental.amount;
        listing.active = true;

        items.safeTransferFrom(msg.sender, address(this), listing.itemId, rental.amount, "");

        emit ItemReturned(rentalId, msg.sender);
    }

    function claimEarnings() external nonReentrant {
        uint256 amount = claimableEarnings[msg.sender];

        if (amount == 0) {
            revert NothingToClaim();
        }

        claimableEarnings[msg.sender] = 0;

        paymentToken.safeTransfer(msg.sender, amount);

        emit EarningsClaimed(msg.sender, amount);
    }
}
