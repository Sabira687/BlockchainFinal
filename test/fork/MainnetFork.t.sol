// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface AggregatorV3Interface {
    function latestRoundData()
    external
    view
    returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);

    function decimals() external view returns (uint8);
}

interface IUniswapV2Factory {
    function getPair(address tokenA, address tokenB) external view returns (address pair);
}

contract MainnetForkTest is Test {
    address private constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address private constant CHAINLINK_ETH_USD = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;
    address private constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    function setUp() public {
        vm.createSelectFork(vm.envString("MAINNET_RPC_URL"));
    }

    function testForkReadsUSDCMetadata() public view {
        uint256 supply = IERC20(USDC).totalSupply();

        assertGt(supply, 0);
    }

    function testForkReadsChainlinkETHUSDPrice() public view {
        AggregatorV3Interface feed = AggregatorV3Interface(CHAINLINK_ETH_USD);

        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();

        assertGt(answer, 0);
        assertGt(updatedAt, 0);
        assertEq(feed.decimals(), 8);
    }

    function testForkReadsUniswapV2Pair() public view {
        IUniswapV2Factory factory = IUniswapV2Factory(UNISWAP_V2_FACTORY);

        address pair = factory.getPair(USDC, WETH);

        assertTrue(pair != address(0));
    }
}