// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/// @author philogy <https://github.com/philogy>
library Ops {
    uint256 internal constant MASK_OP = 0xf0;

    uint256 internal constant SWAP = 0x00;
    uint256 internal constant SWAP_DIR = 0x01;
    uint256 internal constant ADD_LIQ = 0x10;
    uint256 internal constant RM_LIQ = 0x20;
    uint256 internal constant SEND = 0x30;
    uint256 internal constant RECEIVE = 0x40;

    uint256 internal constant SWAP_HEAD = 0x50;

    uint256 internal constant SWAP_HOP = 0x60;
}
