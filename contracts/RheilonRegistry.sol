// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title RheilonRegistry
/// @notice An immutable configuration that crews point at: base asset, Stock Tokens, price oracle, swap route,
///         protocol fee and the beta value cap. It has no owner and no setters. A new configuration means a new
///         registry; a crew moves to it only by its own vote.
contract RheilonRegistry {
    /// @notice Hard ceiling on the protocol fee: 0.20% of each trade. Enforced here and again in every account.
    uint16 public constant MAX_FEE_BPS = 20;

    address public immutable baseAsset;
    address public immutable oracle;
    address public immutable swapAdapter;
    address public immutable treasury;
    uint16 public immutable feeBps;
    /// @notice Fee on USDG brought in when someone joins an open crew. Capped at MAX_FEE_BPS too.
    uint16 public immutable joinFeeBps;
    /// @notice Largest value (in base-asset units) a single crew may hold. 0 = no cap.
    uint256 public immutable maxCrewValue;

    mapping(address => bool) public isSupported;
    address[] internal _supported;

    error BadConfig();

    constructor(
        address baseAsset_,
        address oracle_,
        address swapAdapter_,
        address treasury_,
        uint16 feeBps_,
        uint16 joinFeeBps_,
        uint256 maxCrewValue_,
        address[] memory stockTokens
    ) {
        if (baseAsset_ == address(0) || oracle_ == address(0) || swapAdapter_ == address(0)) revert BadConfig();
        if (feeBps_ > MAX_FEE_BPS || joinFeeBps_ > MAX_FEE_BPS) revert BadConfig();
        if ((feeBps_ > 0 || joinFeeBps_ > 0) && treasury_ == address(0)) revert BadConfig();
        baseAsset = baseAsset_;
        oracle = oracle_;
        swapAdapter = swapAdapter_;
        treasury = treasury_;
        feeBps = feeBps_;
        joinFeeBps = joinFeeBps_;
        maxCrewValue = maxCrewValue_;

        isSupported[baseAsset_] = true;
        _supported.push(baseAsset_);
        for (uint256 i; i < stockTokens.length; ++i) {
            address t = stockTokens[i];
            if (t == address(0) || isSupported[t]) revert BadConfig();
            isSupported[t] = true;
            _supported.push(t);
        }
    }

    function supportedAssets() external view returns (address[] memory) {
        return _supported;
    }
}
