//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import {console2} from "forge-std/Test.sol";
import {BaseDeploy} from "test/utils/BaseDeploy.sol";
import "test/utils/LiquidityAmount.sol";
import "test/utils/TickHelper.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import {ISwapRouter} from "contracts/v3-periphery/interfaces/ISwapRouter.sol";

/* 测试通过flash来进行swap */

contract FlashSwapMock {
    ISwapRouter public router;

    uint160 internal constant MIN_SQRT_RATIO = 4295128739;
    uint160 internal constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    // Example tokens[0]/tokens[1]
    // Sell tokens[0] high      -> Buy tokens[0] low        -> tokens[0] profit
    // tokens[0] in -> tokens[1] out -> tokens[1] in -> tokens[0] out -> tokens[0] profit

    constructor(address _router) {
        router = ISwapRouter(_router);
    }

    // amountIn - 期望最低收益
    function flashSwap(address pool0, uint24 fee1, address tokenIn, address tokenOut, uint256 amountIn) external {
        bool zeroForOne = tokenIn < tokenOut;
        uint160 sqrtPriceLimitX96 = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;
        bytes memory data = abi.encode(msg.sender, pool0, fee1, tokenIn, tokenOut, amountIn, zeroForOne);

        IUniswapV3Pool(pool0).swap(address(this), zeroForOne, int256(amountIn), sqrtPriceLimitX96, data);
    }

    function uniswapV3SwapCallback(int256 amount0, int256 amount1, bytes calldata data) external {
        (
            address caller,
            address pool0,
            uint24 fee1,
            address tokenIn,
            address tokenOut,
            uint256 amountIn,
            bool zeroForOne
        ) = abi.decode(data, (address, address, uint24, address, address, uint256, bool));

        require(msg.sender == address(pool0), "not authorized");

        uint256 amountOut;
        if (zeroForOne) {
            amountOut = uint256(-amount1);
        } else {
            amountOut = uint256(-amount0);
        }

        uint256 buyBackAmount = _swap(tokenOut, tokenIn, fee1, amountOut);

        if (buyBackAmount >= amountIn) {
            uint256 profit = buyBackAmount - amountIn;
            IERC20(tokenIn).transfer(address(pool0), amountIn);
            IERC20(tokenIn).transfer(caller, profit);
        } else {
            uint256 loss = amountIn - buyBackAmount;
            IERC20(tokenIn).transferFrom(caller, address(this), loss);
            IERC20(tokenIn).transfer(address(pool0), amountIn);
        }
    }

    function _swap(address tokenIn, address tokenOut, uint24 fee, uint256 amountIn)
        private
        returns (uint256 amountOut)
    {
        IERC20(tokenIn).approve(address(router), amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: tokenIn,
            tokenOut: tokenOut,
            fee: fee,
            recipient: address(this),
            deadline: block.timestamp,
            amountIn: amountIn,
            amountOutMinimum: 0,
            sqrtPriceLimitX96: 0
        });

        amountOut = router.exactInputSingle(params);
    }
}

contract UniswapV3FlashSwapTest is BaseDeploy {
    FlashSwapMock private FlashSwap;
    address public pool1;
    address public pool2;

    function setUp() public override {
        super.setUp();
        vm.startPrank(deployer);
        FlashSwap = new FlashSwapMock(address(swapRouter));

        pool1 = mintNewPool(tokens[0], tokens[1], FEE_MEDIUM, INIT_PRICE);
        pool2 = mintNewPool(tokens[0], tokens[1], FEE_LOW, INIT_PRICE);

        mintNewPosition(tokens[0], tokens[1], FEE_MEDIUM, getMinTick(TICK_MEDIUM), getMaxTick(TICK_MEDIUM), 10e4, 10e7);

        mintNewPosition(tokens[0], tokens[1], FEE_LOW, getMinTick(TICK_MEDIUM), getMaxTick(TICK_MEDIUM), 10e5, 10e5);

        vm.stopPrank();
    }

    function test_FlashSwap() public {
        // tokens[1] / tokens[0] pool
        uint24 fee1 = FEE_MEDIUM;
        uint24 fee2 = FEE_LOW;

        // Approve tokens[0] fee
        uint256 tokensMaxFee = 10e18;
        deal(tokens[0], address(this), tokensMaxFee);
        deal(tokens[1], address(this), tokensMaxFee);

        IERC20(tokens[0]).approve(address(FlashSwap), tokensMaxFee);
        IERC20(tokens[1]).approve(address(FlashSwap), tokensMaxFee);

        uint256 balBefore = IERC20(tokens[1]).balanceOf(address(this));
        FlashSwap.flashSwap(pool1, fee2, tokens[1], tokens[0], 1 * 50);
        uint256 balAfter = IERC20(tokens[1]).balanceOf(address(this));

        if (balAfter >= balBefore) {
            console2.log("tokens[0] profit", balAfter - balBefore);
        } else {
            console2.log("tokens[0] loss", balBefore - balAfter);
        }
    }

    function test_fail_FlashSwap() public {
        // tokens[1] / tokens[0] pool
        uint24 fee1 = FEE_MEDIUM;
        uint24 fee2 = FEE_LOW;

        // Approve tokens[0] fee
        uint256 tokensMaxFee = 10e18;
        deal(tokens[0], address(this), tokensMaxFee);
        IERC20(tokens[0]).approve(address(FlashSwap), tokensMaxFee);

        vm.expectRevert();
        FlashSwap.flashSwap(pool1, fee1, tokens[0], tokens[1], 1 * 10e18);
    }
}
