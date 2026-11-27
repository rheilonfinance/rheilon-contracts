// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @dev Test / testnet stand-in for USDG and Stock Tokens. Anyone can mint.
contract MockToken is ERC20 {
    uint8 private immutable _dec;

    constructor(string memory n, string memory s, uint8 d) ERC20(n, s) {
        _dec = d;
    }

    function decimals() public view override returns (uint8) {
        return _dec;
    }

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    bool public paused;

    // ERC-8056, for tokens made with `withMultiplier`; plain mock tokens don't answer these
    bool public scaled;
    uint256 public uiMultiplier = 1e18;
    uint256 public newUIMultiplier = 1e18;
    uint256 internal _effectiveAt;

    function withMultiplier() external {
        scaled = true;
    }

    function scheduleMultiplier(uint256 next, uint256 at) external {
        newUIMultiplier = next;
        _effectiveAt = at;
    }

    function effectiveAt() external view returns (uint256) {
        require(scaled, "no ERC-8056");
        return _effectiveAt;
    }

    /// @dev Stand-in for an issuer pause: every transfer reverts while set.
    function setPaused(bool p) external {
        paused = p;
    }

    function _update(address from, address to, uint256 value) internal override {
        require(!paused, "paused");
        super._update(from, to, value);
    }
}
