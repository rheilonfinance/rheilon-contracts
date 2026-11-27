// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RheilonAccount} from "./RheilonAccount.sol";
import {RheilonRegistry} from "./RheilonRegistry.sol";

/// @title RheilonAccountDeployer
/// @notice Holds the account's code so the factory stays under the size limit. The factory creates it in its own
///         constructor and is the only caller it accepts, so every account it makes is one the factory listed.
contract RheilonAccountDeployer {
    address public immutable factory;

    error OnlyFactory();

    constructor() {
        factory = msg.sender;
    }

    function deploy(RheilonRegistry registry, string calldata name, address[] calldata members, RheilonAccount.Config calldata cfg)
        external
        returns (address)
    {
        if (msg.sender != factory) revert OnlyFactory();
        return address(new RheilonAccount(registry, name, members, cfg));
    }
}
