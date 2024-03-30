//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "contracts/v3-core/UniswapV3Pool.sol";

import "contracts/v3-core/interfaces/IUniswapV3Pool.sol";
import "contracts/v3-core/interfaces/callback/IUniswapV3MintCallback.sol";

import "forge-std/Test.sol";
import "test/core_test/core_BaseDeploy.sol";
import "contracts/v3-periphery/libraries/PoolAddress.sol";
import "./LiquidityAmount.sol";

import "test/utils/TickHelper.sol";

import {encodePriceSqrt} from "test/utils/Math.sol";

/* 通过v3-periphery以及ProviderLiquidity.sol进行测试 */

contract core_SimpleSwapTest is core_BaseDeploy, IUniswapV3MintCallback {
    /*  State varies */
    address public poolLOW;
    address public poolMEDIUM;
    address public poolHIGH;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    /// @dev deposits[tokenId] => Depositd
    mapping(uint256 => Deposit) public deposits;

    /* 
    初始化：建立好一个测试环境，包括部署池子工厂合约，创建测试代币，创建测试账户等。
     */
    function setUp() public override {
        super.setUp();
        vm.startPrank(deployer);

        // 针对tokens[1],toekns[2] 创建3个池子
        poolLOW = mintNewPool(tokens[1], tokens[2], FEE_LOW, INIT_PRICE);
        poolMEDIUM = mintNewPool(tokens[1], tokens[2], FEE_MEDIUM, INIT_PRICE);
        poolHIGH = mintNewPool(tokens[1], tokens[2], FEE_HIGH, INIT_PRICE);

        IERC20(tokens[1]).transfer(user, type(uint256).max / 5);

        // 给合约授权token
        IERC20(tokens[1]).approve(address(this), type(uint256).max / 5);
        IERC20(tokens[2]).approve(address(this), type(uint256).max / 5);

        vm.stopPrank();
    }

    /* 无法自由添加边界条件,为了探究报错原因，接下来会使用core合约进行部署和测试 */
    /// forge-config: default.fuzz.runs = 1000
    function test_fuzz_core_MintNewPosition(int24 tickLower, int24 tickUpper, uint128 liquidity) public {
        /* "INIT_PRICE", -6932
    * -887271 887271
        */
        // int24 currentTick = TickMath.getTickAtSqrtRatio(INIT_PRICE);
        vm.assume(
            tickLower >= TickMath.MIN_TICK && tickUpper <= TickMath.MAX_TICK
                && tickLower < TickMath.getTickAtSqrtRatio(INIT_PRICE)
                && TickMath.getTickAtSqrtRatio(INIT_PRICE) < tickUpper && liquidity > 10
        );

        uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
        uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);
        (uint256 amount0ToMint, uint256 amount1ToMint) =
            LiquidityAmounts.getAmountsForLiquidity(INIT_PRICE, sqrtRatioAX96, sqrtRatioBX96, liquidity);

        uint128 liquiditymax = tickSpacingToMaxLiquidityPerTick(TICK_LOW);

        console2.log("tickLower:", tickLower);
        console2.log("tickUpper:", tickUpper);
        console2.log("liquidity:", uint256(liquidity));
        console2.log("amount0ToMint:", amount0ToMint);
        console2.log("amount1ToMint:", amount1ToMint);

        if (
            liquidity <= liquiditymax && (amount0ToMint != 0 || amount1ToMint != 0) && tickLower % TICK_LOW == 0
                && tickUpper % TICK_LOW == 0
        ) {
            mintNewPosition(tokens[1], tokens[2], FEE_LOW, tickLower, tickUpper, amount0ToMint, amount1ToMint);
        }

        // vm.stopPrank();
    }

    /* 指定测试 tick特定边界, 用来调试fuzz的测试用例*/
    function test_spMintNewPosition() public {
        uint256 amount0ToMint = 10000;
        uint256 amount1ToMint = 10000;

        mintNewPosition(tokens[1], tokens[2], FEE_LOW, -13570, -340, 4, 2);
    }

    /* 简单测试 tick边界测试的是max & min*/
    function test_simpleMintNewPosition() public {
        uint256 amount0ToMint = 10000;
        uint256 amount1ToMint = 10000;
        // vm.startPrank(deployer);

        mintNewPosition(
            tokens[1], tokens[2], FEE_LOW, getMinTick(TICK_LOW), getMaxTick(TICK_LOW), amount0ToMint, amount1ToMint
        );
        // vm.stopPrank();
    }

    function mintNewPool(address token0, address token1, uint24 fee, uint160 currentPrice) internal returns (address) {
        /* 创建池子 */
        address pool = poolFactory.createPool(token0, token1, fee);
        UniswapV3Pool(pool).initialize(currentPrice);
    }

    function mintSimplePosition()
        internal
        returns (uint128 liquidity, uint256 amount0, uint256 amount1, address pool)
    {
        uint256 amount0ToMint = 10000;
        uint256 amount1ToMint = 10000;

        (liquidity, amount0, amount1, pool) = mintNewPosition(
            tokens[1], tokens[2], FEE_LOW, getMinTick(TICK_LOW), getMaxTick(TICK_LOW), amount0ToMint, amount1ToMint
        );
        console2.log("tickLower", getMinTick(TICK_LOW));
        console2.log("tickUpper", getMaxTick(TICK_LOW));
        console2.log("INIT_PRICE", TickMath.getTickAtSqrtRatio(INIT_PRICE));
    }

    struct MintCallbackData {
        PoolAddress.PoolKey poolKey;
        address payer;
    }

    function mintNewPosition(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0ToMint,
        uint256 amount1ToMint
    ) internal returns (uint128 liquidity, uint256 amount0, uint256 amount1, address pool) {
        // vm.startPrank(deployer);
        pool = poolFactory.getPool(token0, token1, fee);
        if (pool == address(0)) revert();
        PoolAddress.PoolKey memory poolKey = PoolAddress.PoolKey({token0: token0, token1: token1, fee: fee});
        // compute the liquidity amount
        {
            (uint160 sqrtPriceX96,,,,,,) = UniswapV3Pool(pool).slot0();
            uint160 sqrtRatioAX96 = TickMath.getSqrtRatioAtTick(tickLower);
            uint160 sqrtRatioBX96 = TickMath.getSqrtRatioAtTick(tickUpper);

            liquidity = LiquidityAmounts.getLiquidityForAmounts(
                sqrtPriceX96, sqrtRatioAX96, sqrtRatioBX96, amount0ToMint, amount0ToMint
            );
        }

        (amount0, amount1) = IUniswapV3Pool(pool).mint(
            msg.sender,
            tickLower,
            tickUpper,
            liquidity,
            abi.encode(MintCallbackData({poolKey: poolKey, payer: deployer}))
        );
    }

    function uniswapV3MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata data) external override {
        console2.log("uniswapV3MintCallback", address(this));
        MintCallbackData memory decoded = abi.decode(data, (MintCallbackData));

        if (amount0Owed > 0) {
            pay(decoded.poolKey.token0, decoded.payer, msg.sender, amount0Owed);
        }
        if (amount1Owed > 0) {
            pay(decoded.poolKey.token1, decoded.payer, msg.sender, amount1Owed);
        }
    }

    function pay(address token, address payer, address recipient, uint256 value) internal {
        if (payer == address(this)) {
            // pay with tokens already in the contract (for the exact input multihop case)
            TransferHelper.safeTransfer(token, recipient, value);
        } else {
            // pull payment
            IERC20(token).transferFrom(payer, recipient, value);
        }
    }
}
