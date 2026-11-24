// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Thin wrapper around whichever DEX holds Stock Token liquidity.
interface ISwapAdapter {
    /// @dev Pulls `amountIn` of `tokenIn` from msg.sender and sends at least `minOut` of `tokenOut` to `to`.
    function swap(address tokenIn, address tokenOut, uint256 amountIn, uint256 minOut, address to)
        external
        returns (uint256 amountOut);
}
