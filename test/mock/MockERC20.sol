// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {ERC20} from "openzeppelin/token/ERC20/ERC20.sol";

/// @author philogy <https://github.com/philogy>
contract MockERC20 is ERC20("Mock Token", "MCK") {
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function burn(address to, uint256 amount) external {
        _burn(to, amount);
    }
}
