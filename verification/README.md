# Verification files

## v1

The contracts were deployed from Remix with `RheilonLaunch.flat.sol` (solc 0.8.24, optimizer 200 runs, EVM version
cancun), and verified with these flattened sources on Blockscout and Sourcify.

| File | Used for |
| --- | --- |
| `RheilonLaunch.flat.sol` | RheilonLaunch, which deployed the other four |
| `Rheilon.flat.sol` | RheilonFactory, RheilonRegistry (and RheilonAccount, which the factory creates) |
| `ChainlinkOracle.flat.sol` | ChainlinkOracle |
| `UniswapV3Adapter.flat.sol` | UniswapV3Adapter |
| `args/*.constructor-args.txt` | ABI-encoded constructor arguments for each verified contract |

## v2

The v2 factory was deployed from Remix with `v2/RheilonFactory.flat.sol` (same compiler settings), constructor
argument `registry_` = the v1 registry (`args/RheilonFactoryV2.constructor-args.txt`). The factory creates its
`RheilonAccountDeployer` in its constructor, so one transaction deployed both.

| File | Used for |
| --- | --- |
| `v2/RheilonFactory.flat.sol` | RheilonFactory v2 (Blockscout, partial match: the code matches, only the metadata hash differs) and RheilonAccountDeployer (Sourcify); RheilonAccount v2, which the deployer creates, is in the same file |

To check the deployed code against the sources in `contracts/` instead, run `npm run check` from the repository root.
