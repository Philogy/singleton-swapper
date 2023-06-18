// SPDX-License-Identifier: AGPL-3.0-only
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
    error NegativeAmount();
    error NegativeReceive();
    error AmountOutsideBounds();

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

    struct State {
        Accounter tokenDeltas;
        address lastToken;
    }

    function execute(bytes calldata program) external nonReentrant {
        (uint256 ptr, uint256 endPtr) = _getPc(program);

        State memory state;
        {
            uint256 hashMapSize;
            (ptr, hashMapSize) = _readUint(ptr, 2);
            state.tokenDeltas.init(hashMapSize);
        }

        uint256 op;
        while (ptr < endPtr) {
            unchecked {
                (ptr, op) = _readUint(ptr, 1);

                ptr = _interpretOp(state, ptr, op);
            }
        }

        if (state.tokenDeltas.totalNonZero != 0) revert LeftoverDelta();
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

    function _interpretOp(State memory state, uint256 ptr, uint256 op) internal returns (uint256) {
        uint256 mop = op & Ops.MASK_OP;
        if (mop == Ops.SWAP) {
            ptr = _swap(state, ptr, op);
        } else if (mop == Ops.ADD_LIQ) {
            ptr = _addLiquidity(state, ptr);
        } else if (mop == Ops.RM_LIQ) {
            ptr = _removeLiquidity(state, ptr);
        } else if (mop == Ops.SEND) {
            ptr = _send(state, ptr);
        } else if (mop == Ops.RECEIVE) {
            ptr = _receive(state, ptr);
        } else if (mop == Ops.SWAP_HEAD) {
            ptr = _swapHead(state, ptr, op);
        } else if (mop == Ops.SWAP_HOP) {
            ptr = _swapHop(state, ptr);
        } else if (mop == Ops.SEND_ALL) {
            ptr = _sendAll(state, ptr, op);
        } else if (mop == Ops.RECEIVE_ALL) {
            ptr = _receiveAll(state, ptr, op);
        } else if (mop == Ops.PULL_ALL) {
            ptr = _pullAll(state, ptr, op);
        } else {
            revert InvalidOp(op);
        }

        return ptr;
    }

    function _swap(State memory state, uint256 ptr, uint256 op) internal returns (uint256) {
        address token0;
        address token1;
        uint256 amount;
        (ptr, token0) = _readAddress(ptr);
        (ptr, token1) = _readAddress(ptr);
        bool zeroForOne = (op & Ops.SWAP_DIR) != 0;
        (ptr, amount) = _readUint(ptr, 16);

        (int256 delta0, int256 delta1) = _getPool(token0, token1).swap(zeroForOne, amount, FEE_BPS);

        state.tokenDeltas.accountChange(token0, delta0);
        state.tokenDeltas.accountChange(token1, delta1);

        return ptr;
    }

    function _addLiquidity(State memory state, uint256 ptr) internal returns (uint256) {
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

        state.tokenDeltas.accountChange(token0, delta0);
        state.tokenDeltas.accountChange(token1, delta1);

        return ptr;
    }

    function _removeLiquidity(State memory state, uint256 ptr) internal returns (uint256) {
        address token0;
        address token1;
        uint256 liq;
        (ptr, token0) = _readAddress(ptr);
        (ptr, token1) = _readAddress(ptr);
        (ptr, liq) = _readUint(ptr, 32);

        (int256 delta0, int256 delta1) = _getPool(token0, token1).removeLiquidity(msg.sender, liq);

        state.tokenDeltas.accountChange(token0, delta0);
        state.tokenDeltas.accountChange(token1, delta1);

        return ptr;
    }

    function _send(State memory state, uint256 ptr) internal returns (uint256) {
        address token;
        address to;
        uint256 amount;

        (ptr, token) = _readAddress(ptr);
        (ptr, to) = _readAddress(ptr);
        (ptr, amount) = _readUint(ptr, 16);

        state.tokenDeltas.accountChange(token, amount.toInt256());
        token.safeTransfer(to, amount);
        totalReservesOf[token] -= amount;

        return ptr;
    }

    function _receive(State memory state, uint256 ptr) internal returns (uint256) {
        address token;
        uint256 amount;

        (ptr, token) = _readAddress(ptr);
        (ptr, amount) = _readUint(ptr, 16);

        _receive(state, token, amount);

        return ptr;
    }

    function _swapHead(State memory state, uint256 ptr, uint256 op) internal returns (uint256) {
        address token0;
        address token1;
        uint256 amount;
        (ptr, token0) = _readAddress(ptr);
        (ptr, token1) = _readAddress(ptr);
        (ptr, amount) = _readUint(ptr, 16);

        bool zeroForOne = (op & Ops.SWAP_DIR) != 0;

        (int256 delta0, int256 delta1) = _getPool(token0, token1).swap(zeroForOne, amount, FEE_BPS);
        state.lastToken = zeroForOne ? token1 : token0;

        state.tokenDeltas.accountChange(token0, delta0);
        state.tokenDeltas.accountChange(token1, delta1);

        return ptr;
    }

    function _swapHop(State memory state, uint256 ptr) internal returns (uint256) {
        address lastToken = state.lastToken;
        address nextToken;
        (ptr, nextToken) = _readAddress(ptr);

        (address token0, address token1, bool zeroForOne) =
            nextToken > lastToken ? (lastToken, nextToken, true) : (nextToken, lastToken, false);

        int256 delta = state.tokenDeltas.resetChange(lastToken);
        if (delta > 0) revert NegativeAmount();

        (int256 delta0, int256 delta1) = _getPool(token0, token1).swap(zeroForOne, uint256(-delta), FEE_BPS);
        state.lastToken = nextToken;
        state.tokenDeltas.accountChange(nextToken, zeroForOne ? delta1 : delta0);

        return ptr;
    }

    function _sendAll(State memory state, uint256 ptr, uint256 op) internal returns (uint256) {
        address token;
        address to;

        (ptr, token) = _readAddress(ptr);
        int256 delta = state.tokenDeltas.resetChange(token);
        if (delta > 0) revert NegativeAmount();

        uint256 minSend = 0;
        uint256 maxSend = type(uint128).max;

        if (op & Ops.ALL_MIN_BOUND != 0) (ptr, minSend) = _readUint(ptr, 16);
        if (op & Ops.ALL_MAX_BOUND != 0) (ptr, maxSend) = _readUint(ptr, 16);

        uint256 amount = uint256(-delta);
        if (amount < minSend || amount > maxSend) revert AmountOutsideBounds();

        (ptr, to) = _readAddress(ptr);
        totalReservesOf[token] -= amount;
        token.safeTransfer(to, amount);

        return ptr;
    }

    function _receiveAll(State memory state, uint256 ptr, uint256 op) internal returns (uint256) {
        address token;

        (ptr, token) = _readAddress(ptr);

        uint256 minReceive = 0;
        uint256 maxReceive = type(uint128).max;

        if (op & Ops.ALL_MIN_BOUND != 0) (ptr, minReceive) = _readUint(ptr, 16);
        if (op & Ops.ALL_MAX_BOUND != 0) (ptr, maxReceive) = _readUint(ptr, 16);

        int256 delta = state.tokenDeltas.getChange(token);
        if (delta < 0) revert NegativeReceive();

        uint256 amount = uint256(delta);
        if (amount < minReceive || amount > maxReceive) revert AmountOutsideBounds();

        _receive(state, token, amount);

        return ptr;
    }

    function _pullAll(State memory state, uint256 ptr, uint256 op) internal returns (uint256) {
        address token;

        (ptr, token) = _readAddress(ptr);

        uint256 minReceive = 0;
        uint256 maxReceive = type(uint128).max;

        if (op & Ops.ALL_MIN_BOUND != 0) (ptr, minReceive) = _readUint(ptr, 16);
        if (op & Ops.ALL_MAX_BOUND != 0) (ptr, maxReceive) = _readUint(ptr, 16);

        int256 delta = state.tokenDeltas.getChange(token);
        if (delta < 0) revert NegativeReceive();

        uint256 amount = uint256(delta);
        if (amount < minReceive || amount > maxReceive) revert AmountOutsideBounds();

        token.safeTransferFrom(msg.sender, address(this), amount);
        _accountReceived(state, token);

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

    function _receive(State memory state, address token, uint256 amount) internal {
        if (IGiver(msg.sender).give(token, amount) != IGiver.give.selector) {
            revert InvalidGive();
        }
        _accountReceived(state, token);
    }

    function _accountReceived(State memory state, address token) internal {
        uint256 reserves = totalReservesOf[token];
        uint256 directBalance = token.balanceOf(address(this));
        uint256 totalReceived = directBalance - reserves;

        state.tokenDeltas.accountChange(token, -totalReceived.toInt256());
        totalReservesOf[token] = directBalance;
    }

    function _getPool(address token0, address token1) internal pure returns (Pool storage pool) {
        if (token0 >= token1) revert InvalidTokens();

        assembly {
            let freeMem := mload(0x40)
            mstore(0x00, pools.slot)
            mstore(0x20, token0)
            mstore(0x40, token1)
            pool.slot := keccak256(0x00, 0x60)
            mstore(0x40, freeMem)
        }
    }
}
