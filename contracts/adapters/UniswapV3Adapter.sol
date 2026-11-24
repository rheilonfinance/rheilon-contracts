// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISwapAdapter} from "../interfaces/ISwapAdapter.sol";

/// @notice Uniswap SwapRouter02 single-hop entry point.
interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);
}

/// @title UniswapV3Adapter
/// @notice Swaps through fixed Uniswap v3 pools. Which pool (fee tier) serves each pair is set at deployment.
///         No owner, no setters, holds no funds between calls.
contract UniswapV3Adapter is ISwapAdapter {
    using SafeERC20 for IERC20;

    IV3SwapRouter public immutable router;
    mapping(bytes32 => uint24) internal _fee; // pair key -> pool fee tier (500, 3000, 10000, ...)

    error NoPool(address tokenIn, address tokenOut);
    error BadConfig();

    /// @param tokensA / tokensB / fees  one entry per pool; each pool serves both directions
    constructor(address router_, address[] memory tokensA, address[] memory tokensB, uint24[] memory fees) {
        if (router_ == address(0) || tokensA.length != tokensB.length || tokensA.length != fees.length) revert BadConfig();
        router = IV3SwapRouter(router_);
        for (uint256 i; i < fees.length; ++i) {
            if (fees[i] == 0 || tokensA[i] == tokensB[i]) revert BadConfig();
            _fee[_key(tokensA[i], tokensB[i])] = fees[i];
        }
    }

    function poolFee(address a, address b) public view returns (uint24) {
        return _fee[_key(a, b)];
    }

    /// @inheritdoc ISwapAdapter
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address to)
        external
        returns (uint256 amountOut)
    {
        uint24 fee = poolFee(tokenIn, tokenOut);
        if (fee == 0) revert NoPool(tokenIn, tokenOut);
        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        IERC20(tokenIn).forceApprove(address(router), amountIn);
        amountOut = router.exactInputSingle(
            IV3SwapRouter.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: fee,
                recipient: to,
                amountIn: amountIn,
                amountOutMinimum: minOut,
                sqrtPriceLimitX96: 0
            })
        );
        IERC20(tokenIn).forceApprove(address(router), 0);
    }

    function _key(address a, address b) internal pure returns (bytes32) {
        return a < b ? keccak256(abi.encode(a, b)) : keccak256(abi.encode(b, a));
    }
}
