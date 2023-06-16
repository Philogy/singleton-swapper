// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";

uint256 constant BPS = 1e4;

/// @author philogy <https://github.com/philogy>
library SwapLib {
    using SafeCastLib for uint256;

    function swap(uint256 reserves0, uint256 reserves1, bool zeroForOne, uint256 amount, uint256 feeBps)
        internal
        pure
        returns (uint256 newReserves0, uint256 newReserves1, int256 delta0, int256 delta1)
    {
        if (zeroForOne) {
            delta0 = amount.toInt256();
            (newReserves0, newReserves1) = swapXForY(reserves0, reserves1, amount, feeBps);
            delta1 = newReserves1.toInt256() - reserves1.toInt256();
        } else {
            delta1 = amount.toInt256();
            (newReserves1, newReserves0) = swapXForY(reserves1, reserves0, amount, feeBps);
            delta0 = newReserves0.toInt256() - reserves0.toInt256();
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
