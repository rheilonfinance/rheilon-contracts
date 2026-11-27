// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ISwapAdapter} from "../interfaces/ISwapAdapter.sol";
import {MockOracle} from "./MockOracle.sol";
import {MockToken} from "./MockToken.sol";

/// @dev Swaps at oracle price: sends tokenIn to a burn address (keeps nothing, like the real adapter), mints tokenOut. `haircutBps` simulates slippage.
contract MockSwapAdapter is ISwapAdapter {
    MockOracle public immutable oracle;
    address public immutable base;
    uint256 public haircutBps;
    uint256 public takeBps = 10000; // share of amountIn actually pulled (partial fills)
    uint256 public keepBps; // share of what was pulled that the adapter keeps instead of swapping

    constructor(MockOracle oracle_, address base_) {
        oracle = oracle_;
        base = base_;
    }

    function setHaircut(uint256 bps) external {
        haircutBps = bps;
    }

    function setTake(uint256 bps) external {
        takeBps = bps;
    }

    function setKeep(uint256 bps) external {
        keepBps = bps;
    }

    function _value(address t, uint256 amt) internal view returns (uint256) {
        // priced straight from the mock's price table, so a pool keeps working while the oracle reports a stale feed
        return t == base ? amt : (amt * oracle.price(t)) / 10 ** IERC20Metadata(t).decimals();
    }

    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address to)
        external
        returns (uint256 out)
    {
        amountIn = (amountIn * takeBps) / 10000;
        IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
        uint256 kept = (amountIn * keepBps) / 10000; // a partial fill: the rest stays here
        amountIn -= kept;
        IERC20(tokenIn).transfer(address(0xdead), amountIn); // like a router: keeps nothing
        uint256 v = (_value(tokenIn, amountIn) * (10000 - haircutBps)) / 10000;
        out = tokenOut == base ? v : (v * 10 ** IERC20Metadata(tokenOut).decimals()) / oracle.price(tokenOut);
        require(out >= minOut, "adapter: slippage");
        MockToken(tokenOut).mint(to, out);
    }
}
