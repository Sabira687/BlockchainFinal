// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MathBenchmark} from "../../../contracts/libraries/MathBenchmark.sol";

contract YulMathTest is Test {
    MathBenchmark private benchmark;

    function setUp() public {
        benchmark = new MathBenchmark();
    }

    function testYulMinMatchesSolidityMin() public view {
        assertEq(benchmark.yulMin(1, 2), benchmark.solidityMin(1, 2));
        assertEq(benchmark.yulMin(2, 1), benchmark.solidityMin(2, 1));
        assertEq(benchmark.yulMin(5, 5), benchmark.solidityMin(5, 5));
    }

    function testYulMaxMatchesSolidityMax() public view {
        assertEq(benchmark.yulMax(1, 2), benchmark.solidityMax(1, 2));
        assertEq(benchmark.yulMax(2, 1), benchmark.solidityMax(2, 1));
        assertEq(benchmark.yulMax(5, 5), benchmark.solidityMax(5, 5));
    }

    function testGasSolidityMin() public view {
        benchmark.solidityMin(123, 456);
    }

    function testGasYulMin() public view {
        benchmark.yulMin(123, 456);
    }

    function testGasSolidityMax() public view {
        benchmark.solidityMax(123, 456);
    }

    function testGasYulMax() public view {
        benchmark.yulMax(123, 456);
    }
}
