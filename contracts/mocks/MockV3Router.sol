// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IV3SwapRouter} from "../adapters/UniswapV3Adapter.sol";
import {MockToken} from "./MockToken.sol";

/// @dev Fills exactInputSingle at a fixed rate (out per 1e18 in) and records the fee tier used.
contract MockV3Router is IV3SwapRouter {
    mapping(address => mapping(address => uint256)) public rate; // tokenIn -> tokenOut -> out per 1e18 in
    uint24 public lastFee;

    function setRate(address a, address b, uint256 r) external {
        rate[a][b] = r;
    }

    function exactInputSingle(ExactInputSingleParams calldata p) external payable returns (uint256 out) {
        IERC20(p.tokenIn).transferFrom(msg.sender, address(this), p.amountIn);
        out = (p.amountIn * rate[p.tokenIn][p.tokenOut]) / 1e18;
        require(out >= p.amountOutMinimum, "Too little received");
        lastFee = p.fee;
        MockToken(p.tokenOut).mint(p.recipient, out);
    }
}
