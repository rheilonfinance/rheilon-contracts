# Security review, November 2026

> This is our own review of v1. The independent review that followed, by HEY Research Lab, and the v2 fixes are in
> [`review-v2.md`](review-v2.md).

Self-review by the authors of the contracts. Not an independent audit. The public version lives at
https://rheilon.com/docs/review (same findings)..

## Scope
RheilonAccount, RheilonFactory, RheilonRegistry, ChainlinkOracle, UniswapV3Adapter, as deployed on Robinhood Chain
(addresses in `deployments/robinhood-mainnet.json`), plus the website's handling of pitches.

## Method
- Manual review of every external function: caller, money flow, edge cases.
- Slither 0.11.6, high and medium detectors, mocks excluded: 10 results, all triaged (intentional or unreachable).
- Fuzzing: `test/Fuzz.test.js`, 16 runs x 400 random steps (private and open crews). Invariants:
  membership consistent and within seats; shares sum to `totalShares`; non-members hold none; asset list unique;
  no deposit, join, withdrawal, exit or gift lowers other members' claims beyond rounding; fees never above 0.20%;
  everyone can leave at the end and nobody leaves with more than their claim.
  Run: `npm run test:fuzz`
- End-to-end runs of the website against the deployed contracts on a mainnet fork, and one real trade on mainnet.
- Deployed bytecode compared with this repository: `npm run check`.

## Findings
| # | Severity | Finding | Status |
| --- | --- | --- | --- |
| 1 | Medium | Entry minted at the Chainlink value while exits are immediate: when the feed lags the market, deposit-then-withdraw extracts value (test: 5% gap, 10k in, ~260 USDG extra from a 15k crew) | Contracts immutable; beta cap limits exposure; v2: hold new shares before they can be withdrawn |
| 2 | Medium | Website showed every pitch as "fills within 1%" without reading its on-chain minimum | Fixed: minimum read from chain, red warning if more than 3% under today's price or zero |
| 3 | Low | After every share is withdrawn with value left inside, the 1e6 virtual shares dominate the next supply and later entrants are over-minted (test reproduces) | Website blocks deposits and joins in that state; v2: same offset on exit |
| 4 | Info | A pitch's minimum is fixed at posting; favourable moves before execution could be taken by reordering | FCFS sequencer, 3-day expiry, re-pitch at fresh price |
| 5 | Info | In open crews a share majority can pass trades alone after the 3-day wait | 12h+ cool-off, free exit, loose-floor warning (finding 2) |
| 6 | Info | "Checked against the Chainlink price" wording was inaccurate | Fixed on site, docs and launch thread |
