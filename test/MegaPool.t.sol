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

        emit log_named_address("address(token0)", address(token0));
        emit log_named_address("address(token1)", address(token1));

        if (token0 >= token1) (token0, token1) = (token1, token0);

        token0.mint(address(this), 100e18);
        token1.mint(address(this), 100e18);

        // forgefmt: disable-next-item
        bytes memory program = EncoderLib.init(64)
            .appendAddLiquidity(address(token0), address(token1), address(this), 10e18, 10e18)
            .appendReceive(address(token0), 10e18)
            .appendReceive(address(token1), 10e18)
            .done();

        pool.execute(program);

        // forgefmt: disable-next-item
        program = EncoderLib.init(64)
            .appendSwap(address(token0), address(token1), true, 0.1e18)
            .appendReceive(address(token0), 0.1e18)
            .appendSend(address(token1), address(this), 0.09900990099009901e18)
            .done();
        pool.execute(program);

        (uint256 x, uint256 y,) = pool.getPool(address(token0), address(token1));
        emit log_named_decimal_uint("x", x, 18);
        emit log_named_decimal_uint("y", y, 18);
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
