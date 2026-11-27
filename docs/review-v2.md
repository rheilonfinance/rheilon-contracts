# v2: the HEY Research Lab security review

**Security review by HEY Research Lab, final commit not retested.** [HEY Research Lab](https://github.com/hey-research-lab)
reviewed the deployed v1 contracts and found two Medium issues in voting, published as
[GHSA-fq8r-2cgq-j3gg](https://github.com/rheilonfinance/rheilon-contracts/security/advisories/GHSA-fq8r-2cgq-j3gg) (M-1)
and [GHSA-3chj-vh32-38qv](https://github.com/rheilonfinance/rheilon-contracts/security/advisories/GHSA-3chj-vh32-38qv) (M-2).
v2 is the fix. They retested each round; the last change (R-5, round 5) is the fix they proposed and tested themselves,
applied as is, and that final commit was not retested.

v1 contracts can't be changed. On rheilon.com, joins into v1 open crews stay off and new crews are created through v2.
Money already in a v1 crew is unaffected: every member can still withdraw or leave.

## Summary

| Finding | Severity | Status in v2 |
| --- | --- | --- |
| M-1: in an open crew, a newcomer's money could be traded the second it arrived, with no cool-off, by whoever held the voting shares | Medium | Fixed (round 1) |
| M-2: the cool-off started once and never started over when share weight left, so a pitch made ready inside one transaction ran 12 hours later with no exit window | Medium | Fixed (rounds 1 to 3) |
| N-1: a pitch ready before someone joined could run on them | | Fixed: a join agrees to the ready pitches it was shown (round 4, R-1) |
| N-2: readiness from before a newcomer could vote | | Fixed: older readiness has to pass again (round 4) |
| N-3: a non-signer could stall a pitch by depositing | | Fixed (round 3) |
| N-4: a token whose feed went stale couldn't be sold | | Fixed: it can be sold into USDG, held to the pitch's minimum (round 2) |
| R-1: join/leave churn could freeze an open crew | | Fixed (round 4) |
| R-2, R-3: trades and new money around a stock split or multiplier change | | Fixed (round 4) |
| R-4: the account deployer answered to anyone | | Fixed (round 4) |
| R-5: stale readiness came back when the member behind it left | | Fixed with their tested patch (round 5), not retested |
| I-1: one paused token could lock every exit | Info | Fixed: what can't be sent is owed and claimable |
| I-2: corporate-action multiplier | Info | Unit confirmed correct; timing covered by R-2/R-3 |
| I-3: some stocks have 24/7 feeds | Info | Open: needs a new oracle and registry, planned for a later version |
| I-4: moving the registry with no cool-off | Info | Fixed: 12-hour floor unless unanimous |
| I-5: a swap that doesn't spend exactly what it was given | Info | Fixed |

What a crew does in v2 is in [`how-it-works.md`](how-it-works.md). The tests for every item are in
`test/Review.test.js`. The rest of this file is the log we kept for the reviewers, round by round. Some early
changes were replaced in later rounds (for example round 1's `_recheck` became the narrower resets of round 3 and
the stale-readiness rule of round 4); the code in `contracts/` is the final state.

## Round 1: the fixes for M-1, M-2 and the informational findings

| Finding | Change in `contracts/RheilonAccount.sol` | Test (`test/Review.test.js` unless noted) |
| --- | --- | --- |
| **M-1** GHSA-fq8r-2cgq-j3gg, fix 1 | `unanimous(id)` is `signerCount(id) == _members.length`. A member inside the vote delay can't sign, so nothing is unanimous while anyone waits, and the cool-off applies | "every voter signing isn't unanimous while a newcomer can't sign yet", "a lone founder can't propose and run in one go once someone has joined" |
| **M-1** fix 2 | Every trade is bounded to the oracle: `valueOf(tokenOut, received) >= valueOf(tokenIn, swapIn) * (1 - 3%)`, whatever `minOut` says. An unpriced side reverts | "M-1 fix 2: a trade can't come back more than 3% under the oracle"; `test/Integrations.test.js` end to end (7% pool gap refused, 0.9% accepted) |
| **M-1** fix 3 | `execute` requires `canVote(msg.sender)` | "M-1 fix 3: a member still waiting to vote can't run a pitch" |
| **M-2** GHSA-3chj-vh32-38qv, fix 1 | Proposals with `readyAt != 0` are kept in a list (`_ready`, at most `MAX_READY = 16`). `_recheck()` runs after `deposit`, `join`, `withdraw`, `leave`, an executed `AddMember` and an executed `SetRules`, and clears `readyAt` (event `ReadyReset`) wherever `yes < needed` | "deposit, pitch, withdraw: the pitch doesn't stay ready in the background", "a signer leaving resets readiness too", "someone else's deposit that dilutes the signers resets readiness" |
| **M-2** fix 2 | Hold on new shares: shares minted by `deposit` or `join` can't be withdrawn, or taken out by `leave`, for `HOLD = 1 hours` (`heldShares`, `heldUntil`, `freeShares`, error `Held`). One hour is far under any cool-off, so a newcomer can still leave before a pitch made after their join runs | "the reviewers' attack, staged in one transaction by a contract, can't move the crew later" (staging reverts `Held`; uses `contracts/mocks/StagingMember.sol`) |
| **I-1** | `_payOut` sends each asset with a non-reverting transfer. What can't be sent is recorded in `owed[member][asset]` / `owedTotal[asset]`, excluded from `accountValue`, payouts and trades (`_free`), and collected later with `claim(asset)` | "I-1: one paused token doesn't lock the rest; what couldn't be sent is owed and claimable" |
| **I-4** | `MoveRegistry` waits at least `MIN_MOVE_COOL_OFF = 12 hours` unless unanimous, whatever the crew's cool-off | "I-4: moving the registry waits 12 hours even when the crew set its cool-off to 0" |
| **I-5** | `_trade` checks the account's `tokenIn` balance fell by exactly `swapIn` (error `PartialFill`) | "I-5: a swap that doesn't spend exactly what it was given is refused" |
| I-2, I-3 | Not changed yet. We're confirming the feed unit with Chainlink before touching the oracle | |

Exits stay unblockable: `_recheck` is bounded by `MAX_READY` ("exits stay cheap and never blocked, even with many
pitches waiting", under 1.5M gas with the list full), and a full list only refuses new readiness (`TooManyPending`),
never `withdraw` or `leave`.

## Run

```bash
npm install
npx hardhat test        # 65 tests, including the fuzz campaigns
```

Existing tests that deposit and exit in the same block now wait out the one-hour hold. The old test that ran a
pitch at once while a newcomer waited ("newcomers vote only after 3 days") now expects `CoolOffRunning`.

## Round 2: after their retest of `d3fe703`

| Item | Change | Test (`test/Review.test.js`) |
| --- | --- | --- |
| **N-1** (pitch made ready before a newcomer joined) | `coolOffStart(id)` is the latest of `readyAt`, every current member's `joinedAt` (set in `_addMember`, so both `join` and a voted `AddMember`), and every current member's `votesFrom` that has passed. `execute` waits `coolOff` (or the 12h registry floor) from there when the pitch isn't unanimous | "N-1: a pitch made ready before someone joined waits a full cool-off after their join" |
| N-1, second half | `_validate` refuses a Trade whose `amountIn` is above the crew's free balance of `tokenIn` when it's pitched | "N-1: a pitch can't be sized for money that isn't in the crew yet" |
| **N-2** (newcomer gaining the vote) | covered by the `votesFrom` term in `coolOffStart` | "N-2: when a newcomer gains their vote, the cool-off starts over from that moment" |
| Oracle bound, unpriced sell | `_checkBound`: if the oracle can't price `tokenIn`, a sale into USDG runs held to `minOut` alone; any other unpriced trade reverts `OracleBound(0, 0)` | "oracle: a token whose feed went stale can still be sold into USDG, held to minOut; buying it can't" |
| **I-5** with the deployed adapter | `_swapExact` also checks the adapter's own `tokenIn` balance is unchanged after the swap (`PartialFill`) | "I-5: an adapter that keeps part of what it was given is refused" |
| Docs | `docs/how-it-works.md` and `README.md` describe v2: unanimity over every member, the three cool-off starts, resets on any drop, the 12h registry floor, the oracle bound and its exception, the hold, owed and `claim` | |
| Size | The account's code now lives in `RheilonAccountDeployer` (stateless, anyone can call it, nothing lists what it makes); `RheilonFactory(registry, deployer)` calls it and keeps the list. Factory 2.7 KB, deployer 22.4 KB. A few internal limits (`MAX_MEMBERS`, `VOTE_DELAY`, `MAX_ASSETS`, `PROPOSAL_TTL`, `MAX_COOL_OFF`, `OPEN_MIN_COOL_OFF`) are no longer public getters, and `cancel` by a non-proposer reverts `NotMember` instead of a string | |

The mocks changed to match the deployed adapter: `MockSwapAdapter` sends what it receives to a burn address instead of
holding it, prices from its own table so a pool keeps working while the oracle is stale, and can keep a share
(`setKeep`) to model a partial fill. `MockOracle.setStale` makes `valueInBase` revert.

I-2 and I-3: see the I-2 section at the end.

70 tests pass (`npx hardhat test`).

## Round 3: N-2 and N-3 from their comments on `d3fe703`

| Item | Change | Test (`test/Review.test.js`) |
| --- | --- | --- |
| **N-2** (vote delay ending) | Already in round 2: `coolOffStart` includes every current member's `votesFrom` that has passed, so a pitch that only passes once a newcomer's shares count waits a fresh cool-off from that moment | "N-2: when a newcomer gains their vote, the cool-off starts over from that moment" |
| **N-3** (a non-signer stalling a pitch) | Readiness resets only when a signer's own weight falls or the voter base grows. `withdraw` and `leave` collect the ready proposals the caller signed before the payout (`_readySignedBy`) and reset those now under the bar (`_resetBelow`). `deposit` and `join` no longer re-check anything; a non-signer's deposit is weighed by the threshold check in `execute`. An executed `AddMember` or `SetRules` still re-checks every ready proposal | "N-3: someone who never signed can't stall a pitch by depositing; their weight is checked at execute", "a signer taking weight out still resets the pitches they signed (M-2 stays closed)" |

M-2's staging still fails: the stager is the signer, so their withdrawal resets the pitch (and the hold stops it inside
one transaction). `deposit` no longer walks the ready list, so its gas no longer grows with it.

71 tests pass (`npx hardhat test`).

## I-2: the multiplier

Chainlink's Robinhood tokenized-equity feeds compute `Underlying Equity Market Price × uiMultiplier`, read from the
token, and Robinhood's docs say not to apply the multiplier again. So the feeds price one token, and the oracle's unit
is right as deployed. What's left is timing: around `effectiveAt` the token and its feed may step at different moments.

`_mint` (deposit and join) now calls `_noCorporateActionNear()`: for each held Stock Token it reads `effectiveAt()`, and
reverts `CorporateAction(asset)` from 3 days before a pending change (`newUIMultiplier() != uiMultiplier()`) until
1 day after `effectiveAt`. Tokens that don't answer (USDG, mocks) are skipped. Exits and trades are unaffected; the
oracle bound stays the limit on trades in that window. On chain today NVDA reads `uiMultiplier == newUIMultiplier`
(1.000775…) with `effectiveAt` in the past, so nothing pauses.

Test: "I-2: corporate actions / deposits and joins pause around a held token's multiplier change; exits and trades
don't". I-3 (24/7 feeds for TSLA, NVDA and GOOGL) needs a new oracle and registry, so it's left for a later version.

72 tests pass (`npx hardhat test`).

## Round 4: R-1, N-2, R-2 to R-4 and the docs, from their retest of `8a8de1c`

| Item | Change | Test (`test/Review.test.js`) |
| --- | --- | --- |
| **R-1** (join/leave churn freezing an open crew) | Your option 2. The `joinedAt` term is gone, so a join never moves anyone's clock. `join(amount, readySet)` takes `readyHash()` as the joiner saw it, a fingerprint of the active ready proposals sorted by id, and reverts `ReadySetChanged` if it changed. N-1 stays closed: a newcomer only ever joins into ready pitches they were shown, and anything that becomes ready after the join waits a full cool-off, well past their one-hour hold | "N-1 / R-1: a join must agree to the pitches already ready, so nothing runs on a newcomer by surprise", "R-1: joining and leaving never moves anyone's cool-off, so churn can't freeze a crew" |
| **N-2** (old readiness after a vote starts) | Your fix. `latestVoteStart()` is the latest of any current member's passed `votesFrom` and `rulesChangedAt`. `execute` treats a pitch whose `readyAt` is older as not ready (`CoolOffRunning`), and `_checkpoint` (so `poke`) re-stamps it only if it passes with the new voters counted. `coolOffStart(id)` is now just `readyAt` | "N-2: when a newcomer gains their vote, the cool-off starts over from that moment", "N-2: a pitch that looked dead once newcomers could vote can't run on its old readiness" |
| Voter base and rules changes | The full re-check after an executed `AddMember` or `SetRules` is replaced by the same rule: a voted-in member gets `votesFrom = now`, and `SetRules` sets `rulesChangedAt = now`, so every earlier readiness has to pass again and wait a fresh cool-off. Stricter than before, and smaller | covered by the suite |
| **R-2** (trades in the multiplier window) | `_actionNear(token)` is shared by `_mint` and `_trade`: a trade whose `tokenIn` or `tokenOut` is in its window reverts `CorporateAction`. Exits are unaffected | "R-2: trades in a token pause around its split; other trades and exits don't" |
| **R-3** (dividend steps) | The window ahead of a change only counts steps above 1% (`|new - cur| * 100 > cur`); the day after any change still counts, since the size can't be read back once it has taken effect | "R-3: a small dividend-sized step ahead doesn't pause new money" |
| **R-4** (deployer open to anyone) | The factory now creates its deployer in its own constructor, and `deploy` reverts `OnlyFactory` for anyone else. Deploying v2 is one transaction | "R-4: the account deployer answers only to its factory" |
| Docs | NatSpec at the old `:23`, `:194` and `:236` no longer says "at any time"; `docs/how-it-works.md` describes the join fingerprint, stale readiness and the 1% rule | |

Sizes: deployer 24,151 bytes, factory 2,710, factory creation code 27,447 (under the 49,152 initcode limit).

77 tests pass (`npx hardhat test`).

## Round 4b: from our own review of round 4

Before their next look, we went through round 4 the way a reviewer would and found one thing worth closing now.

| Item | Change | Test (`test/Review.test.js`) |
| --- | --- | --- |
| Churn through vote starts | Round 4 makes every newcomer's vote starting a reset point (the N-2 rule). A churner with a few addresses could join in turn, wait out VOTE_DELAY, leave and rejoin, so some newcomer's vote starts every few hours. It costs `minJoin` per address locked for 3 days plus join fees, much more than R-1's cents, but it's there. Your option 1 closes it: a new kind `SetJoins` (`abi.encode(bool open)`) lets a crew created open (`bornOpen`, immutable) close or reopen itself to joins by vote. `SetJoins` is left out of the stale-readiness rule since it moves no money, so newcomers' votes starting can't hold it off. A crew closed to joins keeps its open-crew limits (12h cool-off floor, no `MoveRegistry`), and a private crew can't open itself | "an open crew can vote to close itself; churners can't stall that vote or come back", "a private crew can't open itself" |
| Size | To fit, `unanimous`, `signerCount`, `voterCount`, `memberEpoch` and `heldShares` are internal now, and `coolOffStart`, `seatsLeft` and `memberCount` are gone (`getProposal(id).readyAt`, `seats() - members().length`). Deployer 24,110 bytes | |

79 tests pass (`npx hardhat test`).

## Round 5: R-5 from their final retest of `11b16c7`

| Item | Change | Test (`test/Review.test.js`) |
| --- | --- | --- |
| **R-5** (stale readiness undone when the member behind it leaves) | Your tested fix. `leave()` folds the leaver's passed `votesFrom` into a stored `leftVoteStart` before removing them, and `latestVoteStart()` starts from `max(rulesChangedAt, leftVoteStart)`, so a vote start stays a reset point after its member leaves | "a vote start stays a reset point after its member leaves, so stale pitches can't come back" (fails without the fix, passes with it) |
| Join consent on the site | The join dialog lists every pitch that already passed, with when it can run, before the joiner signs, and reads `readyHash()` right before sending. `ReadySetChanged` is explained in plain words | web |
| Docs | `docs/how-it-works.md` describes `SetJoins` and that a vote start counts after its member leaves | |

Deployer 24,198 bytes. 80 tests pass (`npx hardhat test`). This is the code deployed as v2.
