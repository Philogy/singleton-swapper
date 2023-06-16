// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {safeSign} from "./SafeSign.sol";

/// @author philogy <https://github.com/philogy>
library SwapLib {
    uint256 internal constant BPS = 1e4;

    function swap(uint256 reserves0, uint256 reserves1, uint256 amount, bool zeroForOne, uint256 feeBps)
        internal
        pure
        returns (uint256 newReserves0, uint256 newReserves1, int256 delta0, int256 delta1)
    {
        if (zeroForOne) {
            delta0 = safeSign(amount);
            (newReserves0, newReserves1) = swapXForY(reserves0, reserves1, amount, feeBps);
            delta1 = safeSign(newReserves1) - safeSign(reserves1);
        } else {
            delta1 = safeSign(amount);
            (newReserves1, newReserves0) = swapXForY(reserves1, reserves0, amount, feeBps);
            delta0 = safeSign(newReserves0) - safeSign(reserves0);
        }
    }

    function swapXForY(uint256 x, uint256 y, uint256 dx, uint256 feeBps)
        internal
        pure
        returns (uint256 nx, uint256 ny)
    {
        nx = x + dx;
        ny = (x * y) / (x + dx * (BPS - feeBps) / BPS);
    }
}
