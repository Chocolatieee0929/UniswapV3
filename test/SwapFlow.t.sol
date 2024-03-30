// SPDX-Identifier-License:MIT
pragma solidity =0.7.6;
pragma abicoder v2;

import {console2} from "forge-std/Test.sol";
import {BaseDeploy} from "test/utils/BaseDeploy.sol";
import {encodePriceSqrt} from "test/utils/Math.sol";
import {TransferHelper} from "contracts/v3-periphery/libraries/TransferHelper.sol";
import {IUniswapV3PoolOwnerActions} from "@uniswap/v3-core/contracts/interfaces/pool/IUniswapV3PoolOwnerActions.sol";

import "test/utils/LiquidityAmount.sol";
import "test/utils/TickHelper.sol";

import {ProviderLiquidity} from "src/ProviderLiquidity.sol";

/* 通过v3-periphery以及ProviderLiquidity.sol进行测试 */

contract SimpleSwapTest is BaseDeploy {
    address public pool;

    function setUp() public override {
        super.setUp();
        pool = mintNewPool(tokens[0], tokens[1], FEE_LOW, INIT_PRICE);
    }

    /* 官方设置手续费 */
    function test_setProtocolFee() public {
        vm.prank(deployer);
        IUniswapV3PoolOwnerActions(pool).setFeeProtocol(5, 5);
    }

    /* 官方提取手续费 */
}
