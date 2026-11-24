// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISwapAdapter} from "../interfaces/ISwapAdapter.sol";
import {MockOracle} from "./MockOracle.sol";
import {MockToken} from "./MockToken.sol";

/// @dev Swaps at oracle price: burns-by-holding tokenIn, mints tokenOut. `haircutBps` simulates slippage.
contract MockSwapAdapter is ISwapAdapter {
    MockOracle public immutable oracle;
    address public immutable base;
    uint256 public haircutBps;

    constructor(MockOracle oracle_, address base_) {
        oracle = oracle_;
        base = base_;
    }

    function setHaircut(uint256 bps) external {
        haircutBps = bps;
    }

    function _value(address t, uint256 amt) internal view returns (uint256) {
        return t == base ? amt : oracle.valueInBase(t, amt);
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address to)
        external
        returns (uint256 out)
    {
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        uint256 v = (_value(tokenIn, amountIn) * (10000 - haircutBps)) / 10000;
        out = tokenOut == base ? v : (v * 10 ** IERC20Metadata(tokenOut).decimals()) / oracle.price(tokenOut);
        require(out >= minOut, "adapter: slippage");
        MockToken(tokenOut).mint(to, out);
    }
}
