// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract ResourceAMM is ERC20, Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public immutable tokenA;
    IERC20 public immutable tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    uint256 public constant FEE_NUMERATOR = 997;
    uint256 public constant FEE_DENOMINATOR = 1000;

    error ZeroAddress();
    error InvalidAmount();
    error InvalidLiquidity();
    error InsufficientOutputAmount();
    error InsufficientLiquidity();
    error InvalidToken();

    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB, uint256 liquidity);
    event Swapped(address indexed trader, address indexed tokenIn, uint256 amountIn, uint256 amountOut);

    constructor(address initialOwner, address tokenA_, address tokenB_)
        ERC20("GameFi Resource LP", "GRLP")
        Ownable(initialOwner)
    {
        if (initialOwner == address(0) || tokenA_ == address(0) || tokenB_ == address(0)) {
            revert ZeroAddress();
        }

        if (tokenA_ == tokenB_) {
            revert InvalidToken();
        }

        tokenA = IERC20(tokenA_);
        tokenB = IERC20(tokenB_);
    }

    function addLiquidity(uint256 amountA, uint256 amountB, uint256 minLiquidity)
        external
        nonReentrant
        returns (uint256 liquidity)
    {
        if (amountA == 0 || amountB == 0) {
            revert InvalidAmount();
        }

        uint256 supply = totalSupply();

        if (supply == 0) {
            liquidity = Math.sqrt(amountA * amountB);
        } else {
            uint256 liquidityA = (amountA * supply) / reserveA;
            uint256 liquidityB = (amountB * supply) / reserveB;
            liquidity = Math.min(liquidityA, liquidityB);
        }

        if (liquidity == 0 || liquidity < minLiquidity) {
            revert InvalidLiquidity();
        }

        tokenA.safeTransferFrom(msg.sender, address(this), amountA);
        tokenB.safeTransferFrom(msg.sender, address(this), amountB);

        reserveA += amountA;
        reserveB += amountB;

        _mint(msg.sender, liquidity);

        emit LiquidityAdded(msg.sender, amountA, amountB, liquidity);
    }

    function removeLiquidity(uint256 liquidity, uint256 minAmountA, uint256 minAmountB)
        external
        nonReentrant
        returns (uint256 amountA, uint256 amountB)
    {
        if (liquidity == 0) {
            revert InvalidAmount();
        }

        uint256 supply = totalSupply();

        if (supply == 0 || liquidity > balanceOf(msg.sender)) {
            revert InsufficientLiquidity();
        }

        amountA = (liquidity * reserveA) / supply;
        amountB = (liquidity * reserveB) / supply;

        if (amountA < minAmountA || amountB < minAmountB) {
            revert InsufficientOutputAmount();
        }

        if (amountA == 0 || amountB == 0) {
            revert InvalidLiquidity();
        }

        _burn(msg.sender, liquidity);

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.safeTransfer(msg.sender, amountA);
        tokenB.safeTransfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB, liquidity);
    }

    function swapExactAForB(uint256 amountIn, uint256 minAmountOut) external nonReentrant returns (uint256 amountOut) {
        amountOut = _swap(tokenA, tokenB, amountIn, minAmountOut, true);
    }

    function swapExactBForA(uint256 amountIn, uint256 minAmountOut) external nonReentrant returns (uint256 amountOut) {
        amountOut = _swap(tokenB, tokenA, amountIn, minAmountOut, false);
    }

    function getAmountOut(address tokenIn, uint256 amountIn) public view returns (uint256 amountOut) {
        if (amountIn == 0) {
            revert InvalidAmount();
        }

        if (reserveA == 0 || reserveB == 0) {
            revert InsufficientLiquidity();
        }

        if (tokenIn == address(tokenA)) {
            amountOut = _getAmountOut(amountIn, reserveA, reserveB);
        } else if (tokenIn == address(tokenB)) {
            amountOut = _getAmountOut(amountIn, reserveB, reserveA);
        } else {
            revert InvalidToken();
        }
    }

    function getReserves() external view returns (uint256 currentReserveA, uint256 currentReserveB) {
        return (reserveA, reserveB);
    }

    function _swap(IERC20 inputToken, IERC20 outputToken, uint256 amountIn, uint256 minAmountOut, bool isAForB)
        private
        returns (uint256 amountOut)
    {
        if (amountIn == 0) {
            revert InvalidAmount();
        }

        if (reserveA == 0 || reserveB == 0) {
            revert InsufficientLiquidity();
        }

        uint256 inputReserve = isAForB ? reserveA : reserveB;
        uint256 outputReserve = isAForB ? reserveB : reserveA;

        amountOut = _getAmountOut(amountIn, inputReserve, outputReserve);

        if (amountOut < minAmountOut) {
            revert InsufficientOutputAmount();
        }

        inputToken.safeTransferFrom(msg.sender, address(this), amountIn);

        if (isAForB) {
            reserveA += amountIn;
            reserveB -= amountOut;
        } else {
            reserveB += amountIn;
            reserveA -= amountOut;
        }

        outputToken.safeTransfer(msg.sender, amountOut);

        emit Swapped(msg.sender, address(inputToken), amountIn, amountOut);
    }

    function _getAmountOut(uint256 amountIn, uint256 inputReserve, uint256 outputReserve)
        private
        pure
        returns (uint256)
    {
        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        return (amountInWithFee * outputReserve) / ((inputReserve * FEE_DENOMINATOR) + amountInWithFee);
    }
}
