// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy
interface IGiver {
    function give(address token, uint256 amount) external returns (bytes4);
}
