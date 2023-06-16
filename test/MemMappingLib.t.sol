// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MemMappingLib, MemMapping} from "src/utils/MemMappingLib.sol";

/// @author philogy <https://github.com/philogy>
contract MemMappingTest is Test {
    function setUp() public {}

    function testSimple() public {
        MemMapping map = MemMappingLib.init(64);

        (bool isNull, uint256 value) = map.get(34);
        assertTrue(isNull);
        assertEq(value, 0);

        map.set(34, 3);
        (isNull, value) = map.get(34);
        assertFalse(isNull);
        assertEq(value, 3);

        map.set(13, 2987);
        (isNull, value) = map.get(13);
        assertFalse(isNull);
        assertEq(value, 2987);

        uint256 newKey = 64 + 34;
        map.set(newKey, 5);
        (isNull, value) = map.get(newKey);
        assertFalse(isNull);
        assertEq(value, 5);

        (isNull, value) = map.get(34);
        assertFalse(isNull);
        assertEq(value, 3);
    }
}
