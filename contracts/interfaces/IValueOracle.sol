// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @notice Values an amount of a supported asset in base-asset (USDG) units.
interface IValueOracle {
    function valueInBase(address asset, uint256 amount) external view returns (uint256);
}
