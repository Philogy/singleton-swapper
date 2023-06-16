// SPDX-License-Identifier: MIT
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

    function _toKey(address asset) private pure returns (uint256 k) {
        assembly {
            k := asset
        }
    }
}
