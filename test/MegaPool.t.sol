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

        address user = makeAddr("user");

        token0.mint(address(this), 100e18);
        token1.mint(address(this), 100e18);

        bytes memory program =
            EncoderLib.init(64).appendAddLiquidity(address(token0), address(token1), user, 10e18, 10e18).done();

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
