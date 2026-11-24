# Rheilon contracts

Smart contracts for [Rheilon](https://rheilon.com): a shared stock account for a crew of 2 to 10 people on
Robinhood Chain (chain ID 4663). Members pool USDG, pitch trades in Robinhood Stock Tokens, vote with their own
wallets, and can leave with their share at any time.

The contracts have no owner, no admin keys, no pause and no upgrade path.

## Contents

| Path | What it is |
| --- | --- |
| `contracts/RheilonAccount.sol` | One crew's account: deposits, joins, votes, trades, withdrawals |
| `contracts/RheilonFactory.sol` | Creates crews and lists them |
| `contracts/RheilonRegistry.sol` | Fixed settings crews point at: USDG, supported stocks, oracle, swap route, fees, beta cap |
| `contracts/oracles/ChainlinkOracle.sol` | Values Stock Tokens in USDG with Chainlink feeds |
| `contracts/adapters/UniswapV3Adapter.sol` | Swaps through fixed Uniswap v3 pools |
| `contracts/RheilonLaunch.sol` | One-shot deployer for all of the above on Robinhood Chain |
| `contracts/mocks/` | Test-only contracts (never deployed to mainnet) |
| `test/` | Unit tests, integration tests and fuzz tests |
| `test-fork/` | Tests against a local copy of Robinhood Chain mainnet |
| `scripts/check-deployed.js` | Compares the code on Robinhood Chain with this repository |
| `deployments/robinhood-mainnet.json` | Deployed addresses and every external address used (tokens, feeds, pools) |
| `verification/` | The flattened sources and constructor arguments used to verify on the explorer |
| `docs/` | How a crew works, and the security review |

## Deployed

| Contract | Address |
| --- | --- |
| RheilonLaunch | [`0xd8f941e1B65BEDb7f7a3bCCdE26e244347FcFC34`](https://robinhoodchain.blockscout.com/address/0xd8f941e1B65BEDb7f7a3bCCdE26e244347FcFC34) |
| RheilonFactory | [`0x62306E1C55AE3CA8D6CE874c275eeB3C16c349A8`](https://robinhoodchain.blockscout.com/address/0x62306E1C55AE3CA8D6CE874c275eeB3C16c349A8) |
| RheilonRegistry | [`0x91D1244361560Ca7E1BFFA60FE29981ED2371A63`](https://robinhoodchain.blockscout.com/address/0x91D1244361560Ca7E1BFFA60FE29981ED2371A63) |
| ChainlinkOracle | [`0xc3573a8f0235E12C40667f9d3cCd7251591618a3`](https://robinhoodchain.blockscout.com/address/0xc3573a8f0235E12C40667f9d3cCd7251591618a3) |
| UniswapV3Adapter | [`0x2d2bF902Ee7F51769F8B10D8da13DE68aadD6181`](https://robinhoodchain.blockscout.com/address/0x2d2bF902Ee7F51769F8B10D8da13DE68aadD6181) |
| Treasury (receives fees) | [`0xD8939e5c33904aAF7098881F5e052616Ce40b086`](https://robinhoodchain.blockscout.com/address/0xD8939e5c33904aAF7098881F5e052616Ce40b086) |

All five contracts are verified (exact match) on Blockscout and Sourcify. Compiler: solc 0.8.24, optimizer 200 runs,
EVM version cancun. Every crew is a `RheilonAccount` created by the factory.

Supported Stock Tokens: NVDA, AAPL, TSLA, MSFT, AMZN, GOOGL, META, QQQ. Token, Chainlink feed and Uniswap pool for
each are in `deployments/robinhood-mainnet.json`.

## How a crew works

- 2 to 10 seats. Members add USDG and receive shares at the account's current value.
- Private crews add members by vote. Open crews let anyone join while seats are free; newcomers vote after 3 days
  and open crews vote by shares.
- Trades are proposals. They pass at two thirds by default; unless everyone signed, a 12-hour cool-off follows so
  anyone who disagrees can leave first. Each trade carries the minimum the crew must receive.
- Withdrawing and leaving need no vote and no price: you get your share of every asset the crew holds.

More detail in [`docs/how-it-works.md`](docs/how-it-works.md).

## Fees

| Action | Fee |
| --- | --- |
| Trade | 0.20%, taken in USDG |
| Joining an open crew | 0.20% of the USDG brought in |
| Creating a crew, adding money, withdrawing, leaving | Free |

The registry stores the fee and every account also caps it at 0.20% (`MAX_FEE_BPS = 20`), so it can't go up.

## Run the tests

Node 18 or newer.

```bash
npm install
npm test             # unit, integration and fuzz tests
npm run test:fuzz    # longer fuzz run: 16 campaigns x 400 random steps
npm run test:fork    # forks Robinhood Chain mainnet in memory and runs real trades on the copy
```

## Check the deployed code yourself

```bash
npm run check
```

Compiles this repository and compares it with the bytecode on Robinhood Chain for all five contracts and every
crew the factory has created. Only immutables (values set at deployment) and metadata hashes are ignored. Set
`RH_RPC` to use your own RPC.

## Security

- No owner, admin, pause or upgrade on any contract. Nobody can move a crew's funds or change its rules from outside.
- Exits never depend on the price oracle or a vote.
- Fees are capped in code at 0.20%.
- Beta: each crew can hold up to $25,000.
- **No external audit yet.** A self-review with all findings, including the ones that can't be changed in deployed
  contracts, is in [`docs/security-review.md`](docs/security-review.md).

Found a problem? Please report it privately through this repository's **Security** tab (private vulnerability
reporting), not in a public issue.

## Disclaimer

Experimental software, provided as is. Not investment advice. Stock Tokens are issued by Robinhood and give price
exposure, not shareholder rights; their availability depends on where you live. Rheilon is independent and not
affiliated with Robinhood Markets, Inc.

## License

[MIT](LICENSE)
