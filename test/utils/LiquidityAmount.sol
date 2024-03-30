// SPDX-License-Identifier: UNLICENSED
pragma solidity =0.7.6;

import "contracts/v3-periphery/libraries/LiquidityAmounts.sol";

function getAmountsForLiquidity(uint160 sqrtRatioX96, uint160 sqrtRatioAX96, uint160 sqrtRatioBX96, uint128 liquidity)
    pure
    returns (uint256 amount0, uint256 amount1)
{
    return LiquidityAmounts.getAmountsForLiquidity(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, liquidity);
}

function getLiquidityForAmounts(
    uint160 sqrtRatioX96,
    uint160 sqrtRatioAX96,
    uint160 sqrtRatioBX96,
    uint256 amount0,
    uint256 amount1
) pure returns (uint128 liquidity) {
    return LiquidityAmounts.getLiquidityForAmounts(sqrtRatioX96, sqrtRatioAX96, sqrtRatioBX96, amount0, amount1);
}
