// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library YulMath {
    function min(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly {
            result := xor(b, mul(xor(a, b), lt(a, b)))
        }
    }

    function max(uint256 a, uint256 b) internal pure returns (uint256 result) {
        assembly {
            result := xor(a, mul(xor(a, b), lt(a, b)))
        }
    }
}
