// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {SolidityMath} from "./SolidityMath.sol";
import {YulMath} from "./YulMath.sol";

contract MathBenchmark {
    function solidityMin(uint256 a, uint256 b) external pure returns (uint256) {
        return SolidityMath.min(a, b);
    }

    function yulMin(uint256 a, uint256 b) external pure returns (uint256) {
        return YulMath.min(a, b);
    }

    function solidityMax(uint256 a, uint256 b) external pure returns (uint256) {
        return SolidityMath.max(a, b);
    }

    function yulMax(uint256 a, uint256 b) external pure returns (uint256) {
        return YulMath.max(a, b);
    }
}
