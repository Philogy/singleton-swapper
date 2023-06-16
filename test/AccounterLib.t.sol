// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {Accounter} from "src/libs/AccounterLib.sol";

/// @author philogy <https://github.com/philogy>
contract AccounterLibTest is Test {
    address internal immutable token1 = 0x0000000000000000000000000000000000000001;
    address internal immutable token2 = 0x0000000000000000000000004000000000000001;

    struct LockState {
        uint256 nonzeroDeltaCount;
        mapping(address => int256) currencyDelta;
    }

    LockState lock;

    function setUp() public {}

    function testAccounter() public {
        Accounter memory accounter;

        accounter.init(64);

        accounter.accountChange(token1, -298);
        accounter.accountChange(token2, 348);
    }

    function testLockAccounter() public {
        _accountDelta(token1, -298);
        _accountDelta(token2, 348);
    }

    function _accountDelta(address currency, int128 delta) internal {
        if (delta == 0) return;

        int256 current = lock.currencyDelta[currency];

        int256 next = current + delta;
        unchecked {
            if (next == 0) {
                lock.nonzeroDeltaCount--;
            } else if (current == 0) {
                lock.nonzeroDeltaCount++;
            }
        }

        lock.currencyDelta[currency] = next;
    }
}
