// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

function safeSign(uint256 x) pure returns (int256) {
    require(x < (1 << 255));
    return int256(x);
}
