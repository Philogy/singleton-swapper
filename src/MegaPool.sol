// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {SafeCastLib} from "solady/utils/SafeCastLib.sol";
import {Pool} from "./libs/PoolLib.sol";
import {Accounter} from "./libs/AccounterLib.sol";
import {BPS} from "./libs/SwapLib.sol";
import {Ops} from "./Ops.sol";

import {IGiver} from "./interfaces/IGiver.sol";

/// @author philogy <https://github.com/philogy>
contract MegaPool {
    using SafeTransferLib for address;
    using SafeCastLib for uint256;

    uint256 public immutable FEE_BPS;

    uint256 internal reentrancyLock = 1;

    mapping(address => Pool) internal pools;
    mapping(address => uint256) public totalReservesOf;

    error InvalidTokens();
    error InvalidOp(uint256 op);
    error LeftoverDelta();
    error InvalidGive();

    constructor(uint256 feeBps) {
        require(feeBps < BPS);
        FEE_BPS = feeBps;
    }

    modifier nonReentrant() {
        require(reentrancyLock == 1);
        reentrancyLock = 2;

        _;

        reentrancyLock = 1;
    }

    function execute(bytes calldata program) external nonReentrant {
        (uint256 ptr, uint256 endPtr) = _getPc(program);

        Accounter memory tokenDeltas;
        {
            uint256 hashMapSize;
            (ptr, hashMapSize) = _readUint(ptr, 2);
            tokenDeltas.init(hashMapSize);
        }

        uint256 op;
        while (ptr < endPtr) {
            unchecked {
                (ptr, op) = _readUint(ptr, 1);

                ptr = _interpretOp(tokenDeltas, ptr, op);
            }
        }

        if (tokenDeltas.totalNonZero != 0) revert LeftoverDelta();
    }

    function getPool(address token0, address token1)
        external
        view
        returns (uint128 reserves0, uint128 reserves1, uint256 totalLiquidity)
    {
        Pool storage pool = _getPool(token0, token1);
        reserves0 = pool.reserves0;
        reserves1 = pool.reserves1;
        totalLiquidity = pool.totalLiquidity;
    }

    function getPosition(address token0, address token1, address owner) external view returns (uint256) {
        return _getPool(token0, token1).positions[owner];
    }

    function _interpretOp(Accounter memory tokenDeltas, uint256 ptr, uint256 op) internal returns (uint256) {
        uint256 mop = op & Ops.MASK_OP;
        if (mop == Ops.SWAP) {
            ptr = _swap(tokenDeltas, ptr);
        } else if (mop == Ops.ADD_LIQ) {
            ptr = _addLiquidity(tokenDeltas, ptr);
        } else if (mop == Ops.RM_LIQ) {
            ptr = _removeLiquidity(tokenDeltas, ptr);
        } else if (mop == Ops.SEND) {
            ptr = _send(tokenDeltas, ptr);
        } else if (mop == Ops.RECEIVE) {
            ptr = _receive(tokenDeltas, ptr);
        } else {
            revert InvalidOp(op);
        }

        return ptr;
    }

    function _swap(Accounter memory accounter, uint256 ptr) internal returns (uint256) {
        address token0;
        address token1;
        uint256 zeroForOne;
        uint256 amount;
        (ptr, token0) = _readAddress(ptr);
        (ptr, token1) = _readAddress(ptr);
        (ptr, zeroForOne) = _readUint(ptr, 1);
        (ptr, amount) = _readUint(ptr, 16);

        (int256 delta0, int256 delta1) = _getPool(token0, token1).swap(zeroForOne != 0, amount, FEE_BPS);

        accounter.accountChange(token0, delta0);
        accounter.accountChange(token1, delta1);

        return ptr;
    }

    function _addLiquidity(Accounter memory accounter, uint256 ptr) internal returns (uint256) {
        address token0;
        address token1;
        address to;
        uint256 maxAmount0;
        uint256 maxAmount1;
        (ptr, token0) = _readAddress(ptr);
        (ptr, token1) = _readAddress(ptr);
        (ptr, to) = _readAddress(ptr);
        (ptr, maxAmount0) = _readUint(ptr, 16);
        (ptr, maxAmount1) = _readUint(ptr, 16);

        (, int256 delta0, int256 delta1) = _getPool(token0, token1).addLiquidity(to, maxAmount0, maxAmount1);

        accounter.accountChange(token0, delta0);
        accounter.accountChange(token1, delta1);

        return ptr;
    }

    function _removeLiquidity(Accounter memory accounter, uint256 ptr) internal returns (uint256) {
        address token0;
        address token1;
        uint256 liq;
        (ptr, token0) = _readAddress(ptr);
        (ptr, token1) = _readAddress(ptr);
        (ptr, liq) = _readUint(ptr, 32);

        (int256 delta0, int256 delta1) = _getPool(token0, token1).removeLiquidity(msg.sender, liq);

        accounter.accountChange(token0, delta0);
        accounter.accountChange(token1, delta1);

        return ptr;
    }

    function _send(Accounter memory accounter, uint256 ptr) internal returns (uint256) {
        address token;
        address to;
        uint256 amount;

        (ptr, token) = _readAddress(ptr);
        (ptr, to) = _readAddress(ptr);
        (ptr, amount) = _readUint(ptr, 16);

        accounter.accountChange(token, amount.toInt256());
        token.safeTransfer(to, amount);
        totalReservesOf[token] -= amount;

        return ptr;
    }

    function _receive(Accounter memory accounter, uint256 ptr) internal returns (uint256) {
        address token;
        uint256 amount;

        (ptr, token) = _readAddress(ptr);
        (ptr, amount) = _readUint(ptr, 16);

        if (IGiver(msg.sender).give(token, amount) != IGiver.give.selector) {
            revert InvalidGive();
        }
        uint256 reserves = totalReservesOf[token];
        uint256 directBalance = token.balanceOf(address(this));
        uint256 totalReceived = directBalance - reserves;

        accounter.accountChange(token, -totalReceived.toInt256());

        return ptr;
    }

    function _readAddress(uint256 ptr) internal pure returns (uint256 newPtr, address addr) {
        uint256 rawVal;
        (newPtr, rawVal) = _readUint(ptr, 20);
        addr = address(uint160(rawVal));
    }

    function _readUint(uint256 ptr, uint256 size) internal pure returns (uint256 newPtr, uint256 x) {
        require(size >= 1 && size <= 32);
        assembly {
            newPtr := add(ptr, size)
            x := shr(shl(3, sub(32, size)), calldataload(ptr))
        }
    }

    function _getPc(bytes calldata program) internal pure returns (uint256 ptr, uint256 endPtr) {
        assembly {
            ptr := program.offset
            endPtr := add(ptr, program.length)
        }
    }

    function _getPool(address token0, address token1) internal pure returns (Pool storage pool) {
        if (token0 >= token1) revert InvalidTokens();

        assembly {
            let freeMem := mload(0x40)
            mstore(0x00, pools.slot)
            mstore(0x20, token0)
            mstore(0x40, token0)
            pool.slot := keccak256(0x00, 0x60)
            mstore(0x40, freeMem)
        }
    }
}
