// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ChainlinkOracle} from "./oracles/ChainlinkOracle.sol";
import {UniswapV3Adapter} from "./adapters/UniswapV3Adapter.sol";
import {RheilonRegistry} from "./RheilonRegistry.sol";
import {RheilonFactory} from "./RheilonFactory.sol";

/// @title RheilonLaunch
/// @notice One deployment that sets up all of Rheilon on Robinhood Chain mainnet (chain ID 4663).
///         Every address below comes from an official source and was checked on-chain and in a mainnet-fork test:
///         tokens  - Robinhood asset registry (docs.robinhood.com/chain/contracts)
///         feeds   - Chainlink feed directory for Robinhood Chain
///         router  - Uniswap v3 SwapRouter02 (developers.uniswap.org, Robinhood Chain deployments)
///         pools   - deepest USDG pool per stock, via UniswapV3Factory.getPool
///         The only input is the treasury that receives the 0.20% fees. Nothing here has an owner.
contract RheilonLaunch {
    address public constant USDG = 0x5fc5360D0400a0Fd4f2af552ADD042D716F1d168;
    address public constant SWAP_ROUTER_02 = 0xCaf681a66D020601342297493863E78C959E5cb2;
    uint16 public constant TRADE_FEE_BPS = 20; // 0.20%
    uint16 public constant JOIN_FEE_BPS = 20; // 0.20%
    uint256 public constant BETA_CAP = 25_000e6; // $25,000 per crew
    uint256 public constant PRICE_MAX_AGE = 4 days; // stock feeds update 24/5

    ChainlinkOracle public immutable oracle;
    UniswapV3Adapter public immutable adapter;
    RheilonRegistry public immutable registry;
    RheilonFactory public immutable factory;

    event Launched(address oracle, address adapter, address registry, address factory, address treasury);

    constructor(address treasury) {
        require(treasury != address(0), "treasury required");
        require(block.chainid == 4663, "Robinhood Chain mainnet only");

        address[8] memory tokens = [
            0xd0601CE157Db5bdC3162BbaC2a2C8aF5320D9EEC, // NVDA
            0xaF3D76f1834A1d425780943C99Ea8A608f8a93f9, // AAPL
            0x322F0929c4625eD5bAd873c95208D54E1c003b2d, // TSLA
            0xe93237C50D904957Cf27E7B1133b510C669c2e74, // MSFT
            0x12f190a9F9d7D37a250758b26824B97CE941bF54, // AMZN
            0x2e0847E8910a9732eB3fb1bb4b70a580ADAD4FE3, // GOOGL
            0xc0D6457C16Cc70d6790Dd43521C899C87ce02f35, // META
            0xD5f3879160bc7c32ebb4dC785F8a4F505888de68 // QQQ
        ];
        address[8] memory feeds = [
            0x379EC4f7C378F34a1B47E4F3cbeBCbAC3E8E9F15, // NVDA / USD
            0x6B22A786bAa607d76728168703a39Ea9C99f2cD0, // AAPL / USD
            0x4A1166a659A55625345e9515b32adECea5547C38, // TSLA / USD
            0x45C3C877C15E6BA2EBB19eA114Ea508d14C1Af2E, // MSFT / USD
            0xD5a1508ceD74c084eBf3cBe853e2C968fB2a651C, // AMZN / USD
            0xF6f373a037c30F0e5010d854385cA89185AE638b, // GOOGL / USD
            0x7C38C00C30BEe9378381E7B6135d7283356D71b1, // META / USD
            0x80901d846d5D7B030F26B480776EE3b29374C2ae // QQQ / USD
        ];
        uint24[8] memory poolFees = [uint24(500), 500, 3000, 3000, 3000, 500, 3000, 500];

        address[] memory t = new address[](8);
        address[] memory f = new address[](8);
        address[] memory usdgSide = new address[](8);
        uint24[] memory fees = new uint24[](8);
        for (uint256 i; i < 8; ++i) {
            t[i] = tokens[i];
            f[i] = feeds[i];
            usdgSide[i] = USDG;
            fees[i] = poolFees[i];
        }

        oracle = new ChainlinkOracle(USDG, address(0), PRICE_MAX_AGE, t, f);
        adapter = new UniswapV3Adapter(SWAP_ROUTER_02, usdgSide, t, fees);
        registry = new RheilonRegistry(USDG, address(oracle), address(adapter), treasury, TRADE_FEE_BPS, JOIN_FEE_BPS, BETA_CAP, t);
        factory = new RheilonFactory(registry);
        emit Launched(address(oracle), address(adapter), address(registry), address(factory), treasury);
    }
}
