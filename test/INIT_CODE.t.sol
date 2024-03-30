//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import {Test, console2} from "forge-std/Test.sol";

import {UniswapV3Pool} from "contracts/v3-core/UniswapV3Pool.sol";
import {UniswapV3Factory} from "contracts/v3-core/UniswapV3Factory.sol";
import {SwapRouter} from "contracts/v3-periphery/SwapRouter.sol";
import {TransferHelper} from "contracts/v3-periphery/libraries/TransferHelper.sol";
import {NonfungiblePositionManager} from "contracts/v3-periphery/NonfungiblePositionManager.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/v3-periphery/NonfungibleTokenPositionDescriptor.sol";
import {IPoolInitializer} from "contracts/v3-periphery/interfaces/IPoolInitializer.sol";
import {INonfungiblePositionManager} from "contracts/v3-periphery/interfaces/INonfungiblePositionManager.sol";

import {IPoolInitializer} from "contracts/v3-periphery/interfaces/IPoolInitializer.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {encodePriceSqrt} from "test/utils/Math.sol";
import "test/utils/TickHelper.sol";
import "contracts/v3-periphery/test/TestERC20.sol";
import "forge-std/StdUtils.sol";

string constant weth9Artifact = "test/utils/WETH9.json";

interface WETH9 is IERC20Minimal {
    function deposit() external payable;
}

contract POOLCODETest is Test {
    /* varies 和 BaseDeploy.sol 一样的，后续会实现解耦 */

    address public deployer = vm.envAddress("LOCAL_DEPLOYER");
    address public user = makeAddr("user");

    UniswapV3Factory internal poolFactory;
    SwapRouter internal swapRouter;
    NonfungiblePositionManager internal nonfungiblePositionManager;

    WETH9 internal weth9;

    uint24 public constant poolFee = 3000;
    uint160 internal INIT_PRICE;
    uint256 immutable tokenNumber = 3;

    address[] tokens;

    function setUp() public {
        /* 配置Uniswap环境 */
        vm.startPrank(deployer);
        // Deploy WETH9 token
        address _weth9 = deployCode(weth9Artifact);
        weth9 = WETH9(_weth9);

        INIT_PRICE = encodePriceSqrt(1, 2);

        poolFactory = new UniswapV3Factory();
        swapRouter = new SwapRouter(address(poolFactory), address(weth9));

        nonfungiblePositionManager = new NonfungiblePositionManager(
            address(poolFactory),
            address(weth9),
            address(new NonfungibleTokenPositionDescriptor(address(_weth9), bytes32("WETH9")))
        );
        getToken();

        vm.stopPrank();
    }

    function test_POOL_INIT_CODE_HASH() public {
        bytes32 POOL_INIT_CODE_HASH = keccak256(abi.encodePacked(type(UniswapV3Pool).creationCode));
        console2.log("POOL_INIT_CODE_HASH");
        console2.logBytes32(POOL_INIT_CODE_HASH);
    }

    function test_coreDeploy() public {
        vm.startPrank(deployer);

        // 针对tokens[1],toekns[2] 创建3个池子
        mintNewPool(tokens[1], tokens[2], FEE_LOW, INIT_PRICE);

        // 采用tokens[1]和tokens[2]进行测试
        IERC20(tokens[1]).transfer(address(swapRouter), type(uint256).max / 5);
        IERC20(tokens[2]).transfer(address(swapRouter), type(uint256).max / 5);

        uint256 amount0ToMint = 10000;
        uint256 amount1ToMint = 10000;

        mintNewPosition(
            tokens[1], tokens[2], FEE_LOW, getMinTick(TICK_LOW), getMaxTick(TICK_LOW), amount0ToMint, amount1ToMint
        );

        vm.stopPrank();
    }

    /* 后边和 BaseDeploy.sol 一样的，后续会实现解耦 */
    function getToken() internal {
        for (uint256 i = 0; i < tokenNumber; i++) {
            address token = address(new TestERC20(type(uint256).max / 2));
            tokens.push(token);
            TransferHelper.safeApprove(token, address(nonfungiblePositionManager), type(uint256).max / 2);
            TransferHelper.safeApprove(token, address(swapRouter), type(uint256).max / 2);
        }
    }

    function mintNewPool(address token0, address token1, uint24 fee, uint160 currentPrice)
        internal
        virtual
        returns (address)
    {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        /* 创建池子 */
        return nonfungiblePositionManager.createAndInitializePoolIfNecessary(token0, token1, fee, currentPrice);
    }

    function mintNewPosition(
        address token0,
        address token1,
        uint24 fee,
        int24 tickLower,
        int24 tickUpper,
        uint256 amount0ToMint,
        uint256 amount1ToMint
    ) internal virtual returns (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) {
        (token0, token1) = token0 < token1 ? (token0, token1) : (token1, token0);
        INonfungiblePositionManager.MintParams memory liquidityParams = INonfungiblePositionManager.MintParams({
            token0: token0,
            token1: token1,
            fee: fee,
            tickLower: tickLower,
            tickUpper: tickUpper,
            recipient: deployer,
            amount0Desired: amount0ToMint,
            amount1Desired: amount1ToMint,
            amount0Min: 0,
            amount1Min: 0,
            deadline: 1
        });

        nonfungiblePositionManager.mint(liquidityParams);
    }
}
