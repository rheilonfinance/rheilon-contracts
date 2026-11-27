// Runs Rheilon against real Robinhood Chain state (USDG, Stock Tokens, Chainlink feeds, Uniswap v3 pools)
// on a local fork. No real funds move. Run: npx hardhat test test-fork/Mainnet.fork.js
const { expect } = require("chai");
const hre = require("hardhat");
const { ethers } = hre;
const cfg = require("../deployments/robinhood-mainnet.json");

const USD = (n) => ethers.parseUnits(String(n), 6);
const coder = ethers.AbiCoder.defaultAbiCoder();
const ERC20 = [
  "function balanceOf(address) view returns (uint256)",
  "function transfer(address,uint256) returns (bool)",
  "function approve(address,uint256) returns (bool)",
  "function symbol() view returns (string)",
];
const FEED = ["function latestRoundData() view returns (uint80,int256,uint256,uint256,uint80)"];
const V3FACTORY = ["function getPool(address,address,uint24) view returns (address)"];

describe("Robinhood Chain mainnet fork", function () {
  this.timeout(600000);
  let treasury, ana, ben, cai, usdg, oracle, adapter, registry, factory, acct;
  const symbols = Object.keys(cfg.stocks);

  before(async () => {
    await hre.network.provider.request({ method: "hardhat_reset", params: [{ forking: { jsonRpcUrl: process.env.RH_RPC || cfg.rpc } }] });
    [, treasury, ana, ben, cai] = await ethers.getSigners();
    usdg = new ethers.Contract(cfg.USDG, ERC20, ethers.provider);

    const tokens = symbols.map((s) => cfg.stocks[s].token);
    oracle = await (await ethers.getContractFactory("ChainlinkOracle")).deploy(
      cfg.USDG, cfg.sequencerUptimeFeed, 4 * 86400, tokens, symbols.map((s) => cfg.stocks[s].feed),
    );
    adapter = await (await ethers.getContractFactory("UniswapV3Adapter")).deploy(
      cfg.uniswapV3.swapRouter02, tokens.map(() => cfg.USDG), tokens, symbols.map((s) => cfg.stocks[s].poolFee),
    );
    registry = await (await ethers.getContractFactory("RheilonRegistry")).deploy(cfg.USDG, oracle, adapter, treasury, 20, 20, USD(25000), tokens);
    factory = await (await ethers.getContractFactory("RheilonFactory")).deploy(registry);

    // Fund test members with USDG from a pool's balance. This only exists on the local fork.
    const whale = cfg.stocks.NVDA.pool;
    await hre.network.provider.request({ method: "hardhat_impersonateAccount", params: [whale] });
    await hre.network.provider.request({ method: "hardhat_setBalance", params: [whale, "0x56BC75E2D63100000"] });
    const w = await ethers.getSigner(whale);
    for (const s of [ana, ben, cai]) await usdg.connect(w).transfer(s.address, USD(5000));

    const args = ["Fork Crew", [ben.address, cai.address], 0, false, 5, 0];
    const a = await factory.connect(ana).createAccount.staticCall(...args);
    await factory.connect(ana).createAccount(...args);
    acct = await ethers.getContractAt("RheilonAccount", a);
    for (const s of [ana, ben, cai]) {
      await usdg.connect(s).approve(a, USD(5000));
      await acct.connect(s).deposit(USD(5000));
    }
  });

  it("config matches the chain: token symbols and Uniswap pools", async () => {
    const f = new ethers.Contract(cfg.uniswapV3.factory, V3FACTORY, ethers.provider);
    for (const s of symbols) {
      const c = cfg.stocks[s];
      expect(await new ethers.Contract(c.token, ERC20, ethers.provider).symbol()).to.equal(s);
      expect((await f.getPool(cfg.USDG, c.token, c.poolFee)).toLowerCase()).to.equal(c.pool.toLowerCase());
    }
  });

  it("prices every listed Stock Token from its live Chainlink feed", async () => {
    for (const s of symbols) {
      const [, answer] = await new ethers.Contract(cfg.stocks[s].feed, FEED, ethers.provider).latestRoundData();
      const v = await oracle.valueInBase(cfg.stocks[s].token, ethers.parseUnits("1", 18));
      expect(v).to.equal((answer * 10n ** 6n) / 10n ** 8n);
      console.log(`      ${s.padEnd(5)} $${ethers.formatUnits(v, 6)}`);
    }
  });

  async function passAndRun(data) {
    const id = await acct.proposalCount();
    await acct.connect(ana).propose(0, data, "");
    await acct.connect(ben).approve(id);
    await acct.connect(cai).approve(id);
    return (await acct.connect(ana).execute(id)).wait();
  }

  it("buys every stock through its real Uniswap pool, 0.20% fee straight to treasury", async () => {
    for (const s of symbols) {
      const token = cfg.stocks[s].token;
      const price = await oracle.valueInBase(token, ethers.parseUnits("1", 18)); // USDG units per token
      const spend = USD(500);
      const net = (spend * 998n) / 1000n;
      const expected = (net * 10n ** 18n) / price;
      const minOut = (expected * 95n) / 100n; // accept up to 5% away from the oracle price
      const t0 = await usdg.balanceOf(treasury.address);
      await passAndRun(coder.encode(["address", "address", "uint256", "uint256"], [cfg.USDG, token, spend, minOut]));
      const got = await new ethers.Contract(token, ERC20, ethers.provider).balanceOf(await acct.getAddress());
      const fee = (await usdg.balanceOf(treasury.address)) - t0;
      const fill = Number((got * price) / 10n ** 18n) / Number(net);
      console.log(`      ${s.padEnd(5)} got ${ethers.formatUnits(got, 18).slice(0, 9)} · fee ${ethers.formatUnits(fee, 6)} USDG · fill vs oracle ${(fill * 100).toFixed(2)}%`);
      expect(fee).to.equal(USD(1));
      expect(got).to.be.greaterThanOrEqual(minOut);
    }
  });

  it("sells a position back to USDG, fee taken on the USDG side", async () => {
    const token = cfg.stocks.NVDA.token;
    const bal = await new ethers.Contract(token, ERC20, ethers.provider).balanceOf(await acct.getAddress());
    const u0 = await usdg.balanceOf(await acct.getAddress());
    const t0 = await usdg.balanceOf(treasury.address);
    await passAndRun(coder.encode(["address", "address", "uint256", "uint256"], [token, cfg.USDG, bal, 0]));
    const back = (await usdg.balanceOf(await acct.getAddress())) - u0;
    const fee = (await usdg.balanceOf(treasury.address)) - t0;
    console.log(`      sold NVDA for ${ethers.formatUnits(back, 6)} USDG net · fee ${ethers.formatUnits(fee, 6)} USDG`);
    expect(fee).to.be.closeTo((back * 20n) / 9980n, 2n);
    expect(await acct.isHeld(token)).to.equal(false);
  });

  it("a member leaves in kind on mainnet state", async () => {
    const until = await acct.heldUntil(cai.address); // new shares are held for an hour (v2)
    const now = (await ethers.provider.getBlock("latest")).timestamp;
    if (until > BigInt(now)) await ethers.provider.send("evm_increaseTime", [Number(until) - now + 1]);
    await acct.connect(cai).leave();
    expect(await acct.isMember(cai.address)).to.equal(false);
    expect(await usdg.balanceOf(cai.address)).to.be.greaterThan(0n);
  });
});

describe("RheilonLaunch on a mainnet fork", function () {
  this.timeout(600000);
  it("deploys everything in one transaction with only a treasury address, and a crew can trade", async () => {
    await hre.network.provider.request({ method: "hardhat_reset", params: [{ forking: { jsonRpcUrl: process.env.RH_RPC || cfg.rpc } }] });
    const [deployer, treasury, ana, ben] = await ethers.getSigners();
    const Launch = await ethers.getContractFactory("RheilonLaunch");
    console.log(`      launch initcode ${(Launch.bytecode.length - 2) / 2} bytes (limit 49152)`);
    const launch = await Launch.connect(deployer).deploy(treasury.address);
    const receipt = await launch.deploymentTransaction().wait();
    console.log(`      gas used ${receipt.gasUsed}`);
    const factory = await ethers.getContractAt("RheilonFactory", await launch.factory());
    const registry = await ethers.getContractAt("RheilonRegistry", await launch.registry());
    expect(await registry.treasury()).to.equal(treasury.address);
    expect(await registry.feeBps()).to.equal(20);
    expect((await registry.supportedAssets()).length).to.equal(9); // USDG + 8 stocks
    const oracle = await ethers.getContractAt("ChainlinkOracle", await launch.oracle());
    const adapter = await ethers.getContractAt("UniswapV3Adapter", await launch.adapter());
    expect((await adapter.router()).toLowerCase()).to.equal(cfg.uniswapV3.swapRouter02.toLowerCase());
    for (const [sym, c] of Object.entries(cfg.stocks)) {
      expect(await registry.isSupported(c.token), sym).to.equal(true);
      expect((await oracle.feedOf(c.token)).toLowerCase(), sym).to.equal(c.feed.toLowerCase());
      expect(await adapter.poolFee(cfg.USDG, c.token), sym).to.equal(BigInt(c.poolFee));
    }

    const usdg = new ethers.Contract(cfg.USDG, ERC20, ethers.provider);
    const whale = cfg.stocks.NVDA.pool;
    await hre.network.provider.request({ method: "hardhat_impersonateAccount", params: [whale] });
    await hre.network.provider.request({ method: "hardhat_setBalance", params: [whale, "0x56BC75E2D63100000"] });
    for (const s of [ana, ben]) await usdg.connect(await ethers.getSigner(whale)).transfer(s.address, USD(1000));
    const args = ["Launch Crew", [ben.address], 0, false, 2, 0];
    const a = await factory.connect(ana).createAccount.staticCall(...args);
    await factory.connect(ana).createAccount(...args);
    const acct = await ethers.getContractAt("RheilonAccount", a);
    for (const s of [ana, ben]) { await usdg.connect(s).approve(a, USD(1000)); await acct.connect(s).deposit(USD(1000)); }
    await acct.connect(ana).propose(0, coder.encode(["address", "address", "uint256", "uint256"], [cfg.USDG, cfg.stocks.AAPL.token, USD(300), 1]), "");
    await acct.connect(ben).approve(0);
    await acct.connect(ana).execute(0);
    expect(await usdg.balanceOf(treasury.address)).to.equal(USD(0.6));
    expect(await new ethers.Contract(cfg.stocks.AAPL.token, ERC20, ethers.provider).balanceOf(a)).to.be.greaterThan(0n);
  });
});
