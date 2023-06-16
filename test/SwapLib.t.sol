// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {SwapLib} from "src/libs/SwapLib.sol";

/// @author philogy <https://github.com/philogy>
contract SwapLibTest is Test {
    function testSimple() public {
        (uint256 x, uint256 y, int256 dx, int256 dy) = SwapLib.swap(10 ether, 20_000e6, 0.2 ether, true, 0.003e4);
        emit log_named_decimal_uint("x", x, 18);
        emit log_named_decimal_uint("y", y, 6);
        emit log_named_decimal_int("dx", dx, 18);
        emit log_named_decimal_int("dy", dy, 6);
    }
}
