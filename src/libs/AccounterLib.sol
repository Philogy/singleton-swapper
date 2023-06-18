// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {MemMappingLib, MemMapping, MapKVPair} from "./MemMappingLib.sol";

struct Accounter {
    MemMapping map;
    uint256 totalNonZero;
}

using AccounterLib for Accounter global;

/// @author philogy <https://github.com/philogy>
library AccounterLib {
    function init(Accounter memory self, uint256 mapSize) internal pure {
        self.map = MemMappingLib.init(mapSize);
    }

    function accountChange(Accounter memory self, address asset, int256 change) internal pure {
        uint256 key = _toKey(asset);
        MapKVPair pair = self.map.getPair(key);
        int256 prevTotalChange = int256(pair.value());
        int256 newTotalChange = prevTotalChange + change;

        if (prevTotalChange == 0) self.totalNonZero++;
        if (newTotalChange == 0) self.totalNonZero--;

        // Unsafe cast to ensure negative numbers can also be stored.
        pair.set(key, uint256(newTotalChange));
    }

    function resetChange(Accounter memory self, address asset) internal pure returns (int256 change) {
        uint256 key = _toKey(asset);
        MapKVPair pair = self.map.getPair(key);
        change = int256(pair.value());

        if (change != 0) self.totalNonZero--;

        pair.set(key, 0);
    }

    function getChange(Accounter memory self, address asset) internal pure returns (int256) {
        (, uint256 rawValue) = self.map.get(_toKey(asset));
        return int256(rawValue);
    }

    function _toKey(address asset) private pure returns (uint256 k) {
        assembly {
            k := asset
        }
    }
}
