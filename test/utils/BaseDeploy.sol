//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import {Test, console2} from "forge-std/Test.sol";

import {SwapRouter} from "contracts/v3-periphery/SwapRouter.sol";
import {TransferHelper} from "contracts/v3-periphery/libraries/TransferHelper.sol";
import {NonfungiblePositionManager} from "contracts/v3-periphery/NonfungiblePositionManager.sol";
import {NonfungibleTokenPositionDescriptor} from "contracts/v3-periphery/NonfungibleTokenPositionDescriptor.sol";
import {IPoolInitializer} from "contracts/v3-periphery/interfaces/IPoolInitializer.sol";
import {INonfungiblePositionManager} from "contracts/v3-periphery/interfaces/INonfungiblePositionManager.sol";

import {IUniswapV3Factory} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Factory.sol";
import {IUniswapV3Pool} from "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "@uniswap/v3-core/contracts/interfaces/IERC20Minimal.sol";
import {encodePriceSqrt} from "test/utils/Math.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "contracts/v3-periphery/test/TestERC20.sol";
import "forge-std/StdUtils.sol";

// string constant v3FactoryArtifact = "node_modules/@uniswap/v3-core/artifacts/contracts/UniswapV3Factory.sol/UniswapV3Factory.json";
string constant v3FactoryArtifact = "out/UniswapV3Factory.sol/UniswapV3Factory.json";
string constant weth9Artifact = "test/utils/WETH9.json";

interface WETH9 is IERC20Minimal {
    function deposit() external payable;
}

contract BaseDeploy is Test {
    address public deployer = vm.envAddress("LOCAL_DEPLOYER");
    address public user = makeAddr("user");

    IUniswapV3Factory internal poolFactory;
    SwapRouter internal swapRouter;
    NonfungiblePositionManager internal nonfungiblePositionManager;

    WETH9 internal weth9;

    uint24 public constant poolFee = 3000;
    uint160 internal INIT_PRICE;
    uint256 immutable tokenNumber = 3;

    address[] tokens;
    /* 
    初始化：建立好一个测试环境，包括部署池子工厂合约，创建测试代币，创建测试账户等。
     */

    function setUp() public virtual {
        /* 配置Uniswap环境 */
        vm.startPrank(deployer);
        // Deploy WETH9 token
        address _weth9 = deployCode(weth9Artifact);
        weth9 = WETH9(_weth9);

        INIT_PRICE = encodePriceSqrt(1, 2);

        // Deploy UniswapV3Factory contract
        address _factory = deployCode(v3FactoryArtifact);
        poolFactory = IUniswapV3Factory(_factory);
        // Deploy SwapRouter contract
        swapRouter = new SwapRouter(address(poolFactory), address(weth9));
        // Deploy TestNonfungible contract
        nonfungiblePositionManager = new NonfungiblePositionManager(
            address(poolFactory),
            address(weth9),
            address(new NonfungibleTokenPositionDescriptor(address(_weth9), bytes32("WETH9")))
        );

        // 部署3个token
        getToken();

        // mintNewPosition(tokens[0], tokens[1]);
        vm.stopPrank();
    }

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
