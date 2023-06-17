// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {FixedPointMathLib as Math} from "solady/utils/FixedPointMathLib.sol";
import {SwapLib} from "./SwapLib.sol";

struct Pool {
    uint256 totalLiquidity;
    mapping(address => uint256) positions;
    uint128 reserves0;
    uint128 reserves1;
}

using PoolLib for Pool global;

/// @author philogy <https://github.com/philogy>
library PoolLib {
    using SafeCastLib for uint256;

    error InsufficientLiquidity();

    function swap(Pool storage self, bool zeroForOne, uint256 amount, uint256 fee)
        internal
        returns (int256 delta0, int256 delta1)
    {
        uint256 newReserves0;
        uint256 newReserves1;
        (newReserves0, newReserves1, delta0, delta1) =
            SwapLib.swap(self.reserves0, self.reserves1, zeroForOne, amount, fee);
        self.reserves0 = newReserves0.toUint128();
        self.reserves1 = newReserves1.toUint128();
    }

    function addLiquidity(Pool storage self, address to, uint256 maxAmount0, uint256 maxAmount1)
        internal
        returns (uint256 newLiquidity, int256 delta0, int256 delta1)
    {
        uint256 total = self.totalLiquidity;

        uint256 amount0;
        uint256 amount1;

        if (total == 0) {
            newLiquidity = Math.sqrt(maxAmount0 * maxAmount1);
            amount0 = maxAmount0;
            amount1 = maxAmount1;

            self.totalLiquidity = newLiquidity;
            self.positions[to] = newLiquidity;
            self.reserves0 = amount0.toUint128();
            self.reserves1 = amount1.toUint128();
        } else {
            uint256 reserves0 = self.reserves0;
            uint256 reserves1 = self.reserves1;
            uint256 liq0 = total * maxAmount0 / reserves0;
            uint256 liq1 = total * maxAmount1 / reserves1;

            if (liq0 > liq1) {
                newLiquidity = liq1;
                amount0 = reserves0 * amount1 / reserves1;
                amount1 = maxAmount1;
            } else {
                // liq0 <= liq1
                newLiquidity = liq0;
                amount0 = maxAmount0;
                amount1 = reserves1 * amount0 / reserves0;
            }
            self.totalLiquidity = total + newLiquidity;
            self.positions[to] += newLiquidity;
            self.reserves0 = (reserves0 + amount0).toUint128();
            self.reserves1 = (reserves1 + amount1).toUint128();
        }

        delta0 = amount0.toInt256();
        delta1 = amount1.toInt256();
    }

    function removeLiquidity(Pool storage self, address from, uint256 liquidity)
        internal
        returns (int256 delta0, int256 delta1)
    {
        uint256 position = self.positions[from];
        if (liquidity > position) revert InsufficientLiquidity();
        uint256 total = self.totalLiquidity;

        uint256 reserves0 = self.reserves0;
        uint256 reserves1 = self.reserves1;

        uint256 amount0 = reserves0 * liquidity / total;
        uint256 amount1 = reserves1 * liquidity / total;

        self.positions[from] = position - liquidity;
        self.reserves0 = (reserves0 - amount0).toUint128();
        self.reserves1 = (reserves1 - amount1).toUint128();
        delta0 = -amount0.toInt256();
        delta1 = -amount1.toInt256();
    }
}
