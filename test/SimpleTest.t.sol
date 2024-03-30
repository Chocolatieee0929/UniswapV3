//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import {INonfungiblePositionManager} from "contracts/v3-periphery/interfaces/INonfungiblePositionManager.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IUniswapV3Pool} from "contracts/v3-core/interfaces/IUniswapV3Pool.sol";

import {console2} from "forge-std/Test.sol";
import {BaseDeploy} from "test/utils/BaseDeploy.sol";
import {encodePriceSqrt} from "test/utils/Math.sol";
import {TransferHelper} from "contracts/v3-periphery/libraries/TransferHelper.sol";
import "test/utils/LiquidityAmount.sol";
import "test/utils/TickHelper.sol";

import {ProviderLiquidity} from "src/ProviderLiquidity.sol";

/* 通过v3-periphery以及ProviderLiquidity.sol进行测试 */

contract SimpleSwapTest is BaseDeploy {
    /*  State varies */
    ProviderLiquidity public providerLiquidity;

    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;

    /* 
    初始化：建立好一个测试环境，包括部署池子工厂合约，创建测试代币，创建测试账户等。
     */
    function setUp() public override {
        super.setUp();
        vm.startPrank(deployer);

        providerLiquidity = new ProviderLiquidity(nonfungiblePositionManager, swapRouter);

        // 针对tokens[1],toekns[2] 创建3个池子
        mintNewPool(tokens[1], tokens[2], FEE_LOW, INIT_PRICE);
        mintNewPool(tokens[1], tokens[2], FEE_MEDIUM, INIT_PRICE);
        mintNewPool(tokens[1], tokens[2], FEE_HIGH, INIT_PRICE);

        // 采用tokens[1]和tokens[2]进行测试
        IERC20(tokens[1]).transfer(address(providerLiquidity), type(uint256).max / 5);
        IERC20(tokens[2]).transfer(address(providerLiquidity), type(uint256).max / 5);

        IERC20(tokens[1]).transfer(user, type(uint256).max / 5);

        vm.stopPrank();
    }

    function test_mintPool_NotOwner() public {
        /* 没有使用nonfungiblePositionManager的身份进行创建pool*/
        address poolAddress = mintNewPool(tokens[0], tokens[1], FEE_LOW, INIT_PRICE);
    }

    /* 简单测试 tick边界测试的是max & min*/
    function test_simpleMintNewPosition() public {
        uint256 amount0ToMint = 10000;
        uint256 amount1ToMint = 10000;
        vm.startPrank(deployer);

        providerLiquidity.mintNewPosition(
            tokens[1], tokens[2], TICK_LOW, getMinTick(TICK_LOW), getMaxTick(TICK_LOW), amount0ToMint, amount1ToMint
        );
        vm.stopPrank();
    }

    /* burn 需要将 position的liquidity全部提取 以及collet之后才能将position进行销毁 */
    function test_burnLiquidity() public {
        (uint256 tokenId, uint128 liquidity) = mintSimplePosition();
        vm.startPrank(deployer);
        providerLiquidity.decreaseLiquidityFull(tokenId);
        providerLiquidity.collectAllFees(tokenId);
        providerLiquidity.retrieveNFT(tokenId);
        nonfungiblePositionManager.burn(tokenId);

        vm.stopPrank();
    }

    /* 了解部署Postion以及添加流动性和减少流动性 */
    function test_ProviderLiquidity() public {
        (uint256 tokenId, uint128 liquidity0) = mintSimplePosition();
        console2.log("after mint liquidity0:", uint256(liquidity0));
        vm.startPrank(deployer);
        (uint128 liquidity1, uint256 amount0, uint256 amount1) =
            providerLiquidity.increaseLiquidityCurrentRange(tokenId, 10000, 10000);
        console2.log("increase(10000, 10000) liquidity1:", uint256(liquidity1));

        providerLiquidity.decreaseLiquidityInHalf(tokenId);
        console2.log("decreaseLiquidityInHalf() liquidity2:", uint256(liquidity1) / 2);

        (uint128 liquidity3,,) = providerLiquidity.increaseLiquidityCurrentRange(tokenId, 100, 100);
        console2.log("increase(100, 100) liquidity3:", uint256(liquidity3));

        (amount0, amount1) = providerLiquidity.collectAllFees(tokenId);

        providerLiquidity.decreaseLiquidityFull(tokenId);
        providerLiquidity.collectAllFees(tokenId);
        providerLiquidity.retrieveNFT(tokenId);

        vm.stopPrank();
    }

    /* SimpleSawp */
    /* 
    在实际的操作中，用户选择一个token作为输入，并选择一个token作为输出，预言机通过费率进行计算，
    选择收益最高的池子进行单池子swap，这块简化操作，选定费率进行swap。
    */
    function test_simpleSwap() public {
        // 给user测试币进行simpleSwap
        deal(tokens[1], user, 100000);
        (uint256 tokenId, uint128 liquidity0) = mintSimplePosition();
        vm.startPrank(user);
        IERC20(tokens[1]).approve(address(providerLiquidity), 10000);
        uint256 amountOut = providerLiquidity.swapToken(tokens[1], tokens[2], 10000, FEE_LOW);
        assert(amountOut != 0);
    }

    /**
     * forge-config: default.fuzz.runs = 100
     * forge-config: default.fuzz.max-test-rejects = 5
     */
    function test_fuzz_simpleSwap(uint256 amountIn) public {
        vm.assume(amountIn > 0 && amountIn < 10000);

        (uint256 tokenId, uint128 liquidity0) = mintSimplePosition();

        vm.startPrank(user);
        IERC20(tokens[1]).approve(address(providerLiquidity), amountIn);
        uint256 amountOut = providerLiquidity.swapToken(tokens[1], tokens[2], amountIn, FEE_LOW);
        if (amountOut > 2) {
            assert(amountOut != 0);
        }
    }

    function test_mintNewPosition_fail() public {}

    function mintNewPool(address token0, address token1, uint24 fee, uint160 currentPrice)
        internal
        override
        returns (address)
    {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        /* 创建池子 */
        return nonfungiblePositionManager.createAndInitializePoolIfNecessary(token0, token1, fee, currentPrice);
    }

    function mintSimplePosition() internal returns (uint256, uint128) {
        uint256 amount0ToMint = 10000;
        uint256 amount1ToMint = 10000;

        vm.prank(deployer);
        (uint256 tokenId, uint128 liquidity,,) = providerLiquidity.mintNewPosition(
            tokens[1], tokens[2], TICK_LOW, getMinTick(TICK_LOW), getMaxTick(TICK_LOW), amount0ToMint, amount1ToMint
        );
        console2.log("tickLower", getMinTick(TICK_LOW));
        console2.log("tickUpper", getMaxTick(TICK_LOW));
        console2.log("INIT_PRICE", getTick(INIT_PRICE));
        return (tokenId, liquidity);
    }
}
