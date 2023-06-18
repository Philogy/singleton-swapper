// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

function sign(int256 x) pure returns (string memory) {
    if (x < 0) return "-";
    if (x > 0) return "+";
    return "";
}

function abs(int256 x) pure returns (uint256) {
    return x < 0 ? uint256(-x) : uint256(x);
}
