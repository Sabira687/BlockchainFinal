// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface AggregatorV3Interface {
    function decimals() external view returns (uint8);

    function latestRoundData()
        external
        view
        returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract GamePriceOracle {
    AggregatorV3Interface public immutable priceFeed;
    uint256 public immutable maxStaleness;

    error ZeroAddress();
    error InvalidPrice();
    error StalePrice();

    constructor(address priceFeed_, uint256 maxStaleness_) {
        if (priceFeed_ == address(0)) {
            revert ZeroAddress();
        }

        priceFeed = AggregatorV3Interface(priceFeed_);
        maxStaleness = maxStaleness_;
    }

    function getLatestPrice() external view returns (uint256 price, uint8 decimals) {
        (uint80 roundId, int256 answer,, uint256 updatedAt, uint80 answeredInRound) = priceFeed.latestRoundData();

        if (answer <= 0 || answeredInRound < roundId) {
            revert InvalidPrice();
        }

        if (block.timestamp - updatedAt > maxStaleness) {
            revert StalePrice();
        }

        return (uint256(answer), priceFeed.decimals());
    }
}
