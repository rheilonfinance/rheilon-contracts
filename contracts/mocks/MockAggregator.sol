// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @dev Settable Chainlink-style feed (prices or sequencer status) for tests.
contract MockAggregator {
    uint8 public decimals;
    int256 public answer;
    uint256 public startedAt;
    uint256 public updatedAt;

    constructor(uint8 d) {
        decimals = d;
    }

    function set(int256 a, uint256 started, uint256 updated) external {
        answer = a;
        startedAt = started;
        updatedAt = updated;
    }

    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80) {
        return (1, answer, startedAt, updatedAt, 1);
    }
}
