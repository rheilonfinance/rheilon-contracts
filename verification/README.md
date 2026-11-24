# Verification files

The contracts were deployed from Remix with `RheilonLaunch.flat.sol` (solc 0.8.24, optimizer 200 runs, EVM version
cancun), and verified with these flattened sources on Blockscout and Sourcify.

| File | Used for |
| --- | --- |
| `RheilonLaunch.flat.sol` | RheilonLaunch, which deployed the other four |
| `Rheilon.flat.sol` | RheilonFactory, RheilonRegistry (and RheilonAccount, which the factory creates) |
| `ChainlinkOracle.flat.sol` | ChainlinkOracle |
| `UniswapV3Adapter.flat.sol` | UniswapV3Adapter |
| `args/*.constructor-args.txt` | ABI-encoded constructor arguments for each verified contract |

To check the deployed code against the sources in `contracts/` instead, run `npm run check` from the repository root.
