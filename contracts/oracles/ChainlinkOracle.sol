// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {AggregatorV3Interface} from "../interfaces/AggregatorV3Interface.sol";
import {IValueOracle} from "../interfaces/IValueOracle.sol";

/// @title ChainlinkOracle
/// @notice Values Stock Tokens in the base asset (USDG, treated as $1) using Robinhood Chain's Chainlink feeds.
///         The asset-to-feed map is fixed at deployment. No owner, no setters.
/// @dev Reverts on: unknown asset, non-positive or incomplete price, sequencer down or just restarted, stale price.
///      Rheilon accounts only call this when minting shares (deposit / join), so a stale price pauses new money
///      coming in but never blocks withdrawing or leaving.
contract ChainlinkOracle is IValueOracle {
    /// @notice After the sequencer comes back up, prices are ignored for this long.
    uint256 public constant GRACE_PERIOD = 1 hours;

    address public immutable baseAsset;
    uint8 internal immutable baseDecimals;
    AggregatorV3Interface public immutable sequencerUptimeFeed; // address(0) to skip (tests / chains without one)
    /// @notice Oldest price accepted. Stock feeds update 24/5, so this must cover a weekend.
    uint256 public immutable maxAge;

    mapping(address => AggregatorV3Interface) public feedOf;

    error UnknownAsset(address asset);
    error BadPrice(address asset);
    error StalePrice(address asset, uint256 updatedAt);
    error SequencerDown();
    error BadConfig();

    constructor(address baseAsset_, address sequencerUptimeFeed_, uint256 maxAge_, address[] memory assets, address[] memory feeds) {
        if (baseAsset_ == address(0) || assets.length != feeds.length || maxAge_ == 0) revert BadConfig();
        baseAsset = baseAsset_;
        baseDecimals = IERC20Metadata(baseAsset_).decimals();
        sequencerUptimeFeed = AggregatorV3Interface(sequencerUptimeFeed_);
        maxAge = maxAge_;
        for (uint256 i; i < assets.length; ++i) {
            if (assets[i] == address(0) || feeds[i] == address(0) || address(feedOf[assets[i]]) != address(0)) revert BadConfig();
            feedOf[assets[i]] = AggregatorV3Interface(feeds[i]);
        }
    }

    /// @inheritdoc IValueOracle
    function valueInBase(address asset, uint256 amount) external view returns (uint256) {
        if (asset == baseAsset) return amount;
        AggregatorV3Interface feed = feedOf[asset];
        if (address(feed) == address(0)) revert UnknownAsset(asset);
        _checkSequencer();

        (, int256 answer,, uint256 updatedAt,) = feed.latestRoundData();
        if (answer <= 0 || updatedAt == 0) revert BadPrice(asset);
        if (block.timestamp - updatedAt > maxAge) revert StalePrice(asset, updatedAt);

        // amount (asset decimals) * price (feed decimals) -> base decimals
        uint256 assetDecimals = IERC20Metadata(asset).decimals();
        uint256 feedDecimals = feed.decimals();
        return (amount * uint256(answer) * (10 ** baseDecimals)) / (10 ** (assetDecimals + feedDecimals));
    }

    function _checkSequencer() internal view {
        if (address(sequencerUptimeFeed) == address(0)) return;
        (, int256 status, uint256 startedAt,,) = sequencerUptimeFeed.latestRoundData();
        // status 0 = up, 1 = down; startedAt = when the current status began
        if (status != 0 || startedAt == 0 || block.timestamp - startedAt <= GRACE_PERIOD) revert SequencerDown();
    }
}
