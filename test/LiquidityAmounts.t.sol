//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

// test helpers for converting prices
import {encodePriceSqrt} from "./utils/Math.sol";
import "test/utils/LiquidityAmount.sol";
import {Test, console2} from "forge-std/Test.sol";

contract GetLiquidityForAmounts is Test {
    function test_AmountsForPriceInside() public pure {
        uint160 sqrtPriceX96 = encodePriceSqrt(1, 1);
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        uint128 liquidity =
            LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 100, 200);
        require(liquidity == 2148);
    }

    function test_AmountsForPriceBelow() public pure {
        uint160 sqrtPriceX96 = encodePriceSqrt(99, 110);
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        uint128 liquidity =
            LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 100, 200);
        require(liquidity == 1048);
    }

    function test_AmountsForPriceAbove() public pure {
        uint160 sqrtPriceX96 = encodePriceSqrt(111, 100);
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        uint128 liquidity =
            LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 100, 200);
        require(liquidity == 2097);
    }

    function test_AmountsForPriceEqualToLowerBoundary() public pure {
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceX96 = sqrtPriceAX96;
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        uint128 liquidity =
            LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 100, 200);
        require(liquidity == 1048);
    }

    function test_AmountsForPriceEqualToUpperBoundary() public pure {
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        uint160 sqrtPriceX96 = sqrtPriceBX96;
        uint128 liquidity =
            LiquidityAmounts.getLiquidityForAmounts(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 100, 200);
        require(liquidity == 2097);
    }
}

contract GetAmountsForLiquidity is Test {
    function test_AmountsForPriceInside() public pure {
        uint160 sqrtPriceX96 = encodePriceSqrt(1, 1);
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        (uint256 amount0, uint256 amount1) = getAmountsForLiquidity(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 2148);
        require(amount0 == 99);
        require(amount1 == 99);
    }

    function test_AmountsForPriceBelow() public pure {
        uint160 sqrtPriceX96 = encodePriceSqrt(99, 110);
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        (uint256 amount0, uint256 amount1) = getAmountsForLiquidity(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 1048);
        require(amount0 == 99);
        require(amount1 == 0);
    }

    function test_AmountsForPriceAbove() public pure {
        uint160 sqrtPriceX96 = encodePriceSqrt(111, 100);
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        (uint256 amount0, uint256 amount1) = getAmountsForLiquidity(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 2097);
        require(amount0 == 0);
        require(amount1 == 199);
    }

    function test_AmountsForPriceOnLowerBoundary() public pure {
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceX96 = sqrtPriceAX96;
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        (uint256 amount0, uint256 amount1) = getAmountsForLiquidity(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 1048);
        require(amount0 == 99);
        require(amount1 == 0);
    }

    function test_AmountsForPriceOnUpperBoundary() public pure {
        uint160 sqrtPriceAX96 = encodePriceSqrt(100, 110);
        uint160 sqrtPriceBX96 = encodePriceSqrt(110, 100);
        uint160 sqrtPriceX96 = sqrtPriceBX96;
        (uint256 amount0, uint256 amount1) = getAmountsForLiquidity(sqrtPriceX96, sqrtPriceAX96, sqrtPriceBX96, 2097);
        require(amount0 == 0);
        require(amount1 == 199);
    }
}
