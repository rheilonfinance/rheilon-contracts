// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {RheilonAccount} from "./RheilonAccount.sol";
import {RheilonRegistry} from "./RheilonRegistry.sol";

/// @title RheilonFactory
/// @notice Opens a shared account for a crew. No owner, no fees to create. The caller is always the first member.
contract RheilonFactory {
    RheilonRegistry public immutable registry;
    address[] public allAccounts;
    mapping(address => address[]) internal _accountsOf;

    event AccountCreated(address indexed account, address indexed creator, string name, bool open, uint8 seats);

    constructor(RheilonRegistry registry_) {
        registry = registry_;
    }

    /// @param open    true = anyone can join while seats are free; false = members join only by vote
    /// @param seats   crew size limit, 2..10
    /// @param minJoin smallest USDG amount a newcomer must bring to join an open crew
    function createAccount(
        string calldata name,
        address[] calldata otherMembers,
        RheilonAccount.VoteMode voteMode,
        bool open,
        uint8 seats,
        uint256 minJoin
    ) external returns (address account) {
        address[] memory members = new address[](otherMembers.length + 1);
        members[0] = msg.sender;
        for (uint256 i; i < otherMembers.length; ++i) {
            members[i + 1] = otherMembers[i];
        }
        account = address(new RheilonAccount(registry, name, members, RheilonAccount.Config(voteMode, open, seats, minJoin)));
        allAccounts.push(account);
        for (uint256 i; i < members.length; ++i) {
            _accountsOf[members[i]].push(account);
        }
        emit AccountCreated(account, msg.sender, name, open, seats);
    }

    /// @notice Accounts an address was a founding member of (later members are tracked through events).
    function accountsOf(address member) external view returns (address[] memory) {
        return _accountsOf[member];
    }

    /// @notice All open crews, for discovery pages.
    function openAccounts() external view returns (address[] memory list) {
        uint256 n;
        for (uint256 i; i < allAccounts.length; ++i) if (RheilonAccount(allAccounts[i]).open()) ++n;
        list = new address[](n);
        n = 0;
        for (uint256 i; i < allAccounts.length; ++i) if (RheilonAccount(allAccounts[i]).open()) list[n++] = allAccounts[i];
    }

    function accountCount() external view returns (uint256) {
        return allAccounts.length;
    }
}
