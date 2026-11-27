// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {IValueOracle} from "../interfaces/IValueOracle.sol";

/// @dev price = base-asset units for ONE whole token.
contract MockOracle is IValueOracle {
    mapping(address => uint256) public price;
    mapping(address => bool) public stale;

    /// @dev Stand-in for a feed past its age limit or retired: valueInBase reverts for this asset.
    function setStale(address asset, bool s) external {
        stale[asset] = s;
    }

    function setPrice(address asset, uint256 p) external {
        price[asset] = p;
    }

    function valueInBase(address asset, uint256 amount) public view returns (uint256) {
        require(!stale[asset], "StalePrice");
        return (amount * price[asset]) / (10 ** IERC20Metadata(asset).decimals());
    }
}
