pragma solidity ^0.7.6;

import "contracts/v3-periphery/libraries/Path.sol";
import {FEE_HIGH, FEE_MEDIUM} from "./TickHelper.sol";

function encodePath(address[] memory path, uint24[] memory fees) returns (bytes memory) {
    bytes memory res;
    for (uint256 i = 0; i < fees.length; i++) {
        res = abi.encodePacked(res, path[i], fees[i]);
    }
    res = abi.encodePacked(res, path[path.length - 1]);
    return res;
}
