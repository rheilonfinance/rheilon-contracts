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
- **Open crews** let anyone call `join(amount, readySet)` while seats are free, bringing at least `minJoin` USDG.
  `readySet` is `readyHash()` as the joiner saw it, a fingerprint of the proposals that could run on their money: the
  join reverts if it changed, so joining never moves anyone's cool-off and nobody joins into a surprise.
  An open crew can close itself to joins, or reopen, by vote (`SetJoins`, `abi.encode(bool open)`). It keeps its
  open-crew limits while closed (12-hour cool-off floor, no registry moves), and a private crew can't open itself. A join fee
  (0.20%) goes to the treasury. Newcomers can vote after `VOTE_DELAY` (3 days); open crews always vote by shares.

## Getting out

- `withdraw(shares)` pays out that fraction of every asset the account holds, in kind. You stay a member.
- `leave()` pays out all of your shares and removes you.
- Neither needs a vote, a price or anyone's permission, and both are free. Only the member can withdraw their own
  shares.
- Shares you got from a deposit or a join in the last hour (`HOLD`) can't be taken out until the hour is up
  (`freeShares`, `heldUntil`). The hour is far shorter than any cool-off, so a newcomer can always leave before a
  pitch made after they joined runs.
- If one asset can't be sent (its issuer paused the token), the rest still goes out. What couldn't be sent is set
  aside as `owed` to you, kept out of the crew's value, and collected later with `claim(asset)`.

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
4. Unless every member signed, it waits `coolOff` (12 hours by default) from the moment it became ready, so anyone who
   disagrees can leave first. "Every member" includes newcomers still waiting to vote, who can't sign, so while
   anyone is waiting nothing skips the wait. Readiness from before the latest change in who votes or how (a member
   voted in, a newcomer's vote starting, new rules; a vote start still counts after that member leaves) doesn't count: the proposal has to pass again with them counted
   (`poke`) and wait a full cool-off from then. When a signer pulls out (withdraws their signature, takes money out
   or leaves) and support drops below the threshold, it stops being ready too. Money added by someone who didn't
   sign doesn't reset anything; it counts when `execute` checks the threshold. Moving to another registry always
   waits at least 12 hours unless every member signed.
5. A member who can vote calls `execute`. Proposals expire after 3 days.

## Fees

- Trades: 0.20%, taken on the USDG side (from USDG going in, or from USDG coming out).
- Joining an open crew: 0.20% of the USDG brought in.
- Both are read from the registry and capped again in every account at `MAX_FEE_BPS = 20`.

## Prices

`ChainlinkOracle` reads Robinhood Chain's Chainlink feeds. It rejects non-positive prices and prices older than
4 days (covers a weekend; stock feeds update 24/5). Prices are used to mint shares on deposit and join, and to bound
trades: a trade may not receive more than 3% less than the oracle value of what it sold, whatever minimum the pitch
carries. A token the oracle can no longer price can still be sold into USDG, held to the pitch's minimum. Exits never
use a price.

Robinhood's Chainlink feeds price one token, with the Stock Token's ERC-8056 multiplier already in the price, so the
oracle never applies it again. Around a corporate action (a split and the like) the token's multiplier and its feed
may not step at the same moment, so deposits and joins pause from 3 days before a held token's scheduled multiplier
change of more than 1% (`effectiveAt`, `newUIMultiplier`; smaller dividend steps don't count) until 1 day after any
change takes effect, and so do trades in that token. Withdrawing and leaving are unaffected.

## Swaps

`UniswapV3Adapter` swaps single-hop through one fixed Uniswap v3 USDG pool per stock, via SwapRouter02. It pulls
exactly the approved amount, keeps nothing between calls, and the account checks what it actually received.

## Beta cap

The registry sets `maxCrewValue = 25,000 USDG`. Deposits and joins that would take a crew above it revert.
