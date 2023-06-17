// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {Test} from "forge-std/Test.sol";
import {MegaPool} from "src/MegaPool.sol";
import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";
import {MockERC20} from "./mock/MockERC20.sol";
import {IGiver} from "src/interfaces/IGiver.sol";
import {EncoderLib} from "src/utils/EncoderLib.sol";

/// @author philogy <https://github.com/philogy>
contract MegaPoolTest is Test, IGiver {
    using SafeTransferLib for address;
    using EncoderLib for bytes;

    MegaPool pool;

    function setUp() public {
        pool = new MegaPool(0);
    }

    function testMain() public {
        MockERC20 token0 = _newToken("token_0");
        MockERC20 token1 = _newToken("token_1");

        if (token0 >= token1) (token0, token1) = (token1, token0);

        token0.mint(address(this), 100e18);
        token1.mint(address(this), 100e18);

        uint256 startX = 10e18;
        uint256 startY = 10e18;

        // forgefmt: disable-next-item
        bytes memory program = EncoderLib.init(64)
            .appendAddLiquidity(address(token0), address(token1), address(this), 10e18, 10e18)
            .appendReceive(address(token0), 10e18)
            .appendReceive(address(token1), 10e18)
            .done();

        pool.execute(program);

        uint256 inAmount = 0.1e18;
        uint256 outAmount = startY - (startX * startY) / (startX + inAmount);

        // forgefmt: disable-next-item
        program = EncoderLib.init(64)
            .appendSwap(address(token0), address(token1), true, inAmount)
            .appendReceive(address(token0), inAmount)
            .appendSend(address(token1), address(this), outAmount)
            .done();
        pool.execute(program);

        (uint256 x, uint256 y,) = pool.getPool(address(token0), address(token1));
        assertEq(x, startX + inAmount);
        assertEq(y, startY - outAmount);
    }

    function testMultiHop() public {
        MockERC20[] memory tokens = new MockERC20[](4);
        tokens[0] = _newToken("token_0");
        tokens[1] = _newToken("token_1");
        tokens[2] = _newToken("token_2");
        tokens[3] = _newToken("token_3");

        for (uint256 i; i < tokens.length; i++) {
            tokens[i].mint(address(this), 100e18);
        }

        bytes memory program = EncoderLib.init(16);
        for (uint256 i; i < tokens.length - 1; i++) {
            address token0 = address(tokens[i]);
            address token1 = address(tokens[i + 1]);
            // forgefmt: disable-next-item
            program
                .appendAddLiquidity(token0, token1, address(this), 10e18, 10e18)
                .appendReceive(token0, 10e18)
                .appendReceive(token1, 10e18);
        }
        program.done();

        pool.execute(program);

        // forgefmt: disable-next-item
        program = EncoderLib.init(16)
            .appendSwapHead(address(tokens[0]), address(tokens[1]), 0.1e18, true)
            .appendSwapHop(address(tokens[2]))
            .appendSwapHop(address(tokens[3]))
            .appendSend(address(tokens[3]), address(this), 0.0970873786407767e18)
            .appendReceive(address(tokens[0]), 0.1e18)
            .done();

        pool.execute(program);
    }

    function give(address token, uint256 amount) external returns (bytes4) {
        token.safeTransfer(msg.sender, amount);
        return IGiver.give.selector;
    }

    function _newToken(string memory label) internal returns (MockERC20) {
        MockERC20 newToken = new MockERC20();
        vm.label(address(newToken), label);
        return newToken;
    }
}
