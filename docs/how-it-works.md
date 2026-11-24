# How a crew works

Every crew is one `RheilonAccount` contract, created by `RheilonFactory`. It holds USDG and Stock Tokens for its
members and has no owner.

## Shares

- Members add USDG with `deposit(amount)`. Shares are minted at the account's current value, so a deposit neither
  gains nor loses anything: `minted = amount * (totalShares + 1e6) / (accountValue + 1)`.
- `accountValue()` adds up every asset the account holds, Stock Tokens priced by the registry's oracle (Chainlink).
- Shares can't be transferred. Each member's balance is `sharesOf(member)`.
- Gains and losses follow shares: a member with 30% of the shares owns 30% of everything the crew holds.

## Getting in

- **Founders** are set when the crew is created.
- **Private crews** add people through an `AddMember` proposal that passes a vote.
- **Open crews** let anyone call `join(amount)` while seats are free, bringing at least `minJoin` USDG. A join fee
  (0.20%) goes to the treasury. Newcomers can vote after `VOTE_DELAY` (3 days); open crews always vote by shares.

## Getting out

- `withdraw(shares)` pays out that fraction of every asset the account holds, in kind. You stay a member.
- `leave()` pays out all of your shares and removes you.
- Neither needs a vote, a price or anyone's permission, and both are free. Only the member can withdraw their own
  shares.

## Proposals

| Kind | Data | What it does |
| --- | --- | --- |
| `Trade` | tokenIn, tokenOut, amountIn, minOut | Swap through the registry's adapter. Reverts if the crew would receive less than `minOut` |
| `AddMember` | address | Add a member (private crews) |
| `SetRules` | thresholdBps, coolOff | Change the vote threshold (over 50%) and cool-off (up to 2 days; open crews at least 12 hours) |
| `MoveRegistry` | address | Point the crew at another registry with the same USDG (private crews only) |

1. A member who can vote calls `propose`. Proposing counts as signing.
2. Others call `approve` (or `unapprove`). Approvals from someone who left and came back never count again.
3. When signed weight reaches `thresholdBps` (two thirds by default) of members who can vote, by heads or by shares,
   the proposal is ready.
4. If not everyone signed, it waits `coolOff` (12 hours by default) after first becoming ready, so anyone who
   disagrees can leave first. If signatures drop below the threshold, the wait starts over.
5. Any member calls `execute`. Proposals expire after 3 days.

## Fees

- Trades: 0.20%, taken on the USDG side (from USDG going in, or from USDG coming out).
- Joining an open crew: 0.20% of the USDG brought in.
- Both are read from the registry and capped again in every account at `MAX_FEE_BPS = 20`.

## Prices

`ChainlinkOracle` reads Robinhood Chain's Chainlink feeds. It rejects non-positive prices and prices older than
4 days (covers a weekend; stock feeds update 24/5). Prices are only used to mint shares on deposit and join, never
for exits.

## Swaps

`UniswapV3Adapter` swaps single-hop through one fixed Uniswap v3 USDG pool per stock, via SwapRouter02. It pulls
exactly the approved amount, keeps nothing between calls, and the account checks what it actually received.

## Beta cap

The registry sets `maxCrewValue = 25,000 USDG`. Deposits and joins that would take a crew above it revert.
