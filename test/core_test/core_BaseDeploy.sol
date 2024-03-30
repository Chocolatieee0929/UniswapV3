//SPDX-License-Identifier: MIT
pragma solidity ^0.7.6;
pragma abicoder v2;

import {Test, console2} from "forge-std/Test.sol";
import "forge-std/StdUtils.sol";

import "contracts/v3-core/UniswapV3Factory.sol";
import "contracts/v3-core/interfaces/IERC20Minimal.sol";
import "contracts/v3-periphery/test/TestERC20.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {encodePriceSqrt} from "test/utils/Math.sol";

string constant weth9Artifact = "test/utils/WETH9.json";

interface WETH9 is IERC20Minimal {
    function deposit() external payable;
}

contract core_BaseDeploy is Test {
    address public deployer = vm.envAddress("LOCAL_DEPLOYER");
    address public user = makeAddr("user");

    UniswapV3Factory public poolFactory;

    WETH9 internal weth9;

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

        // 部署3个token
        getToken();

        // Deploy UniswapV3Pool and initialize it
        poolFactory = new UniswapV3Factory();

        // mintNewPosition(tokens[0], tokens[1]);
        vm.stopPrank();
    }

    function getToken() internal {
        for (uint256 i = 0; i < tokenNumber; i++) {
            address token = address(new TestERC20(type(uint256).max / 2));
            tokens.push(token);
        }
    }
}
