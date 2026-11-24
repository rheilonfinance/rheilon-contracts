const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const USD = (n) => ethers.parseUnits(String(n), 6);
const ONE = (n) => ethers.parseUnits(String(n), 18);
const P8 = (n) => ethers.parseUnits(String(n), 8); // Chainlink USD feeds use 8 decimals
const coder = ethers.AbiCoder.defaultAbiCoder();
const DAY = 86400;

async function base() {
  const [, treasury, ana, ben, cai] = await ethers.getSigners();
  const Token = await ethers.getContractFactory("MockToken");
  const usdg = await Token.deploy("Global Dollar", "USDG", 6);
  const nvda = await Token.deploy("NVIDIA", "NVDA", 18);
  const Agg = await ethers.getContractFactory("MockAggregator");
  const feed = await Agg.deploy(8);
  const seq = await Agg.deploy(0);
  const now = await time.latest();
  await feed.set(P8(186.4), now, now);
  await seq.set(0, now - 2 * 3600, now - 2 * 3600); // up for 2h
  const Oracle = await ethers.getContractFactory("ChainlinkOracle");
  const oracle = await Oracle.deploy(usdg, seq, 4 * DAY, [await nvda.getAddress()], [await feed.getAddress()]);
  return { treasury, ana, ben, cai, usdg, nvda, feed, seq, oracle, Oracle };
}

describe("ChainlinkOracle", () => {
  it("values a stock token in USDG units", async () => {
    const c = await base();
    expect(await c.oracle.valueInBase(c.nvda, ONE(2))).to.equal(USD(372.8));
    expect(await c.oracle.valueInBase(c.usdg, USD(5))).to.equal(USD(5));
  });

  it("rejects stale, zero and unknown prices", async () => {
    const c = await base();
    const now = await time.latest();
    await c.feed.set(P8(186.4), now - 5 * DAY, now - 5 * DAY);
    await expect(c.oracle.valueInBase(c.nvda, ONE(1))).to.be.revertedWithCustomError(c.oracle, "StalePrice");
    await c.feed.set(0, now, now);
    await expect(c.oracle.valueInBase(c.nvda, ONE(1))).to.be.revertedWithCustomError(c.oracle, "BadPrice");
    await expect(c.oracle.valueInBase(c.ana.address, ONE(1))).to.be.revertedWithCustomError(c.oracle, "UnknownAsset");
  });

  it("accepts a Friday close over a weekend", async () => {
    const c = await base();
    const now = await time.latest();
    await c.feed.set(P8(186.4), now - 3 * DAY, now - 3 * DAY); // Fri 4pm -> Mon morning
    expect(await c.oracle.valueInBase(c.nvda, ONE(1))).to.equal(USD(186.4));
  });

  it("refuses prices while the sequencer is down or just restarted", async () => {
    const c = await base();
    const now = await time.latest();
    await c.seq.set(1, now - 600, now - 600);
    await expect(c.oracle.valueInBase(c.nvda, ONE(1))).to.be.revertedWithCustomError(c.oracle, "SequencerDown");
    await c.seq.set(0, now - 600, now - 600); // back up only 10 minutes ago
    await expect(c.oracle.valueInBase(c.nvda, ONE(1))).to.be.revertedWithCustomError(c.oracle, "SequencerDown");
  });

  it("has no owner or setters", async () => {
    const c = await base();
    for (const fn of ["owner", "setFeed", "transferOwnership"]) expect(c.oracle[fn]).to.equal(undefined);
  });
});

describe("UniswapV3Adapter", () => {
  async function withAdapter() {
    const c = await base();
    const router = await (await ethers.getContractFactory("MockV3Router")).deploy();
    await router.setRate(c.usdg, c.nvda, ONE(1) * ONE(1) / USD(186.4) / 10n ** 12n * 10n ** 12n); // ~1/186.4 NVDA per USDG unit scaled
    const Adapter = await ethers.getContractFactory("UniswapV3Adapter");
    const adapter = await Adapter.deploy(router, [await c.usdg.getAddress()], [await c.nvda.getAddress()], [3000]);
    return { ...c, router, adapter, Adapter };
  }

  it("routes through the configured pool in both directions and leaves no allowance", async () => {
    const c = await withAdapter();
    expect(await c.adapter.poolFee(c.nvda, c.usdg)).to.equal(3000);
    await c.router.setRate(c.usdg, c.nvda, ONE(1) * 10n ** 12n / 200n); // 1 USDG(1e6) -> 1/200 NVDA(1e18)
    await c.usdg.mint(c.ana, USD(1000));
    await c.usdg.connect(c.ana).approve(c.adapter, USD(1000));
    await c.adapter.connect(c.ana).swap(c.usdg, c.nvda, USD(1000), ONE(4.9), c.ana);
    expect(await c.nvda.balanceOf(c.ana)).to.equal(ONE(5));
    expect(await c.router.lastFee()).to.equal(3000);
    expect(await c.usdg.allowance(c.adapter, c.router)).to.equal(0n);
    expect(await c.usdg.balanceOf(c.adapter)).to.equal(0n);
  });

  it("enforces minOut and refuses unknown pairs", async () => {
    const c = await withAdapter();
    await c.router.setRate(c.usdg, c.nvda, ONE(1) * 10n ** 12n / 200n);
    await c.usdg.mint(c.ana, USD(1000));
    await c.usdg.connect(c.ana).approve(c.adapter, USD(1000));
    await expect(c.adapter.connect(c.ana).swap(c.usdg, c.nvda, USD(1000), ONE(5.1), c.ana)).to.be.revertedWith("Too little received");
    await expect(c.adapter.connect(c.ana).swap(c.usdg, c.ana.address, USD(1), 0, c.ana)).to.be.revertedWithCustomError(c.adapter, "NoPool");
  });

  it("end to end: crew trade through Chainlink + Uniswap pays the 0.20% fee straight to treasury", async () => {
    const c = await withAdapter();
    await c.router.setRate(c.usdg, c.nvda, ONE(1) * 10n ** 12n / 200n);
    const registry = await (await ethers.getContractFactory("RheilonRegistry")).deploy(c.usdg, c.oracle, c.adapter, c.treasury, 20, 20, 0, [await c.nvda.getAddress()]);
    const factory = await (await ethers.getContractFactory("RheilonFactory")).deploy(registry);
    const a = await factory.connect(c.ana).createAccount.staticCall("Crew", [c.ben, c.cai], 0, false, 5, 0);
    await factory.connect(c.ana).createAccount("Crew", [c.ben, c.cai], 0, false, 5, 0);
    const acct = await ethers.getContractAt("RheilonAccount", a);
    for (const s of [c.ana, c.ben, c.cai]) {
      await c.usdg.mint(s, USD(1000));
      await c.usdg.connect(s).approve(acct, USD(1000));
      await acct.connect(s).deposit(USD(1000));
    }
    const data = coder.encode(["address", "address", "uint256", "uint256"], [await c.usdg.getAddress(), await c.nvda.getAddress(), USD(1000), ONE(4.9)]);
    await acct.connect(c.ana).propose(0, data, "first buy");
    await acct.connect(c.ben).approve(0);
    await acct.connect(c.cai).approve(0);
    await acct.connect(c.ana).execute(0);
    expect(await c.usdg.balanceOf(c.treasury)).to.equal(USD(2)); // fee lands in the treasury in the same transaction
    expect(await c.nvda.balanceOf(acct)).to.equal(ONE(4.99));
    // value now priced by the Chainlink feed ($186.40), not the pool
    expect(await acct.accountValue()).to.equal(USD(2000) + (ONE(4.99) * P8(186.4) * 10n ** 6n) / 10n ** 26n);

    // stale price blocks new money in, but never blocks leaving
    await time.increase(5 * DAY);
    await c.usdg.mint(c.ana, USD(10));
    await c.usdg.connect(c.ana).approve(acct, USD(10));
    await expect(acct.connect(c.ana).deposit(USD(10))).to.be.revertedWithCustomError(c.oracle, "StalePrice");
    await acct.connect(c.cai).leave();
    expect(await c.nvda.balanceOf(c.cai)).to.be.greaterThan(0n);
  });
});
