// The two Medium findings from the Hey Research Lab review (GHSA-fq8r-2cgq-j3gg, GHSA-3chj-vh32-38qv), written as
// properties. Both fail on the first deployed version and pass on the fixed one.
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const USD = (n) => ethers.parseUnits(String(n), 6);
const ONE = (n) => ethers.parseUnits(String(n), 18);
const Kind = { Trade: 0, AddMember: 1, SetRules: 2, MoveRegistry: 3, SetJoins: 4 };
const Mode = { Heads: 0, Shares: 1 };
const coder = ethers.AbiCoder.defaultAbiCoder();
const trade = (a, b, amt, min) => coder.encode(["address", "address", "uint256", "uint256"], [a, b, amt, min]);
const addr = (a) => coder.encode(["address"], [a]);

async function deploy({ fee = 20, joinFee = 20, cap = 0, open = false, mode = open ? Mode.Shares : Mode.Heads, seats = 5, minJoin = 0 } = {}) {
  const [deployer, treasury, ana, ben, cai, dee, outsider, ...rest] = await ethers.getSigners();
  const Token = await ethers.getContractFactory("MockToken");
  const usdg = await Token.deploy("Global Dollar", "USDG", 6);
  const nvda = await Token.deploy("NVDA", "NVDA", 18);
  const oracle = await (await ethers.getContractFactory("MockOracle")).deploy();
  await oracle.setPrice(nvda, USD(200));
  const adapter = await (await ethers.getContractFactory("MockSwapAdapter")).deploy(oracle, usdg);
  const Registry = await ethers.getContractFactory("RheilonRegistry");
  const registry = await Registry.deploy(usdg, oracle, adapter, treasury, fee, joinFee, cap, [await nvda.getAddress()]);
  const factory = await (await ethers.getContractFactory("RheilonFactory")).deploy(registry);
  const a = await factory.connect(ana).createAccount.staticCall("Crew", [ben, cai], mode, open, seats, minJoin);
  await factory.connect(ana).createAccount("Crew", [ben, cai], mode, open, seats, minJoin);
  const acct = await ethers.getContractAt("RheilonAccount", a);
  for (const s of [ana, ben, cai, dee, outsider, ...rest.slice(0, 8)]) {
    await usdg.mint(s, USD(1_000_000));
    await usdg.connect(s).approve(acct, ethers.MaxUint256);
  }
  return { rest, deployer, treasury, ana, ben, cai, dee, outsider, usdg, nvda, oracle, adapter, Registry, registry, factory, acct };
}

async function fund(c) {
  await c.acct.connect(c.ana).deposit(USD(1000));
  await c.acct.connect(c.ben).deposit(USD(1000));
  await c.acct.connect(c.cai).deposit(USD(2000));
  await time.increase(3601); // past the hold on new shares
}

async function passAll(c, kind, data) {
  const id = await c.acct.proposalCount();
  await c.acct.connect(c.ana).propose(kind, data, "");
  await c.acct.connect(c.ben).approve(id);
  await c.acct.connect(c.cai).approve(id);
  await c.acct.connect(c.ana).execute(id);
  return id;
}

const buy = async (c, amt, min = 0) => trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(amt), min);

describe("Review: a newcomer still waiting to vote keeps the cool-off", () => {
  it("every voter signing isn't unanimous while a newcomer can't sign yet", async () => {
    const c = await deploy({ open: true, seats: 5 });
    await fund(c);
    await c.acct.connect(c.dee).join(USD(9980), await c.acct.readyHash());
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 3000), "");
    await c.acct.connect(c.ben).approve(0);
    await c.acct.connect(c.cai).approve(0);
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    // the newcomer has the cool-off to walk away with their money (after the 1h hold on new shares, well inside 12h)
    await expect(c.acct.connect(c.dee).leave()).to.be.revertedWithCustomError(c.acct, "Held");
    await time.increase(3601);
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    const before = await c.usdg.balanceOf(c.dee);
    await c.acct.connect(c.dee).leave();
    expect((await c.usdg.balanceOf(c.dee)) - before).to.be.closeTo(USD(9980 * 0.998), USD(1));
    await time.increase(11 * 3600);
    await c.acct.connect(c.ana).execute(0);
  });

  it("a lone founder can't propose and run in one go once someone has joined", async () => {
    const [, , ana, , , dee] = await ethers.getSigners();
    const c = await deploy({ open: true, seats: 5 });
    // ben and cai leave: ana is the only founder, like a crew with one creator
    await c.acct.connect(c.ana).deposit(USD(10));
    await c.acct.connect(c.ben).leave();
    await c.acct.connect(c.cai).leave();
    await c.acct.connect(dee).join(USD(9980), await c.acct.readyHash());
    await c.acct.connect(ana).propose(Kind.Trade, await buy(c, 9000), "");
    await expect(c.acct.connect(ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
  });

  it("with nobody waiting, a unanimous crew still runs right away", async () => {
    const c = await deploy();
    await fund(c);
    await passAll(c, Kind.Trade, await buy(c, 100));
  });
});

describe("Review: the cool-off restarts whenever support drops below the bar", () => {
  it("deposit, pitch, withdraw: the pitch doesn't stay ready in the background", async () => {
    const c = await deploy({ mode: Mode.Shares });
    await fund(c); // 1000 / 1000 / 2000
    await c.acct.connect(c.ana).deposit(USD(20000)); // ana now ~88%
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 4000), "");
    expect((await c.acct.getProposal(0)).readyAt).to.not.equal(0n);
    const back = (await c.acct.sharesOf(c.ana)) - (await c.acct.sharesOf(c.ben));
    // the hold on new shares: the borrowed weight can't leave in the same moment
    await expect(c.acct.connect(c.ana).withdraw(back)).to.be.revertedWithCustomError(c.acct, "Held");
    await time.increase(3601); // an hour in which the pitch was visibly ready
    await c.acct.connect(c.ana).withdraw(back); // back to ~25%
    expect((await c.acct.getProposal(0)).readyAt).to.equal(0n);
    await time.increase(13 * 3600);
    await c.acct.connect(c.ana).deposit(USD(20000));
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    // it can still pass, but only after a fresh cool-off that everyone can see
    await c.acct.poke(0);
    await time.increase(12 * 3600);
    await c.acct.connect(c.ana).execute(0);
  });

  it("the reviewers' attack, staged in one transaction by a contract, can't move the crew later", async () => {
    const [, treasury, alice, bob] = await ethers.getSigners();
    const Token = await ethers.getContractFactory("MockToken");
    const c = await deploy({ mode: Mode.Shares });
    const atk = await (await ethers.getContractFactory("StagingMember")).deploy();
    // a private crew that votes by shares: alice, bob and the attacker contract
    const a2 = await c.factory.connect(alice).createAccount.staticCall("Friends", [bob, await atk.getAddress()], Mode.Shares, false, 3, 0);
    await c.factory.connect(alice).createAccount("Friends", [bob, await atk.getAddress()], Mode.Shares, false, 3, 0);
    const acct = await ethers.getContractAt("RheilonAccount", a2);
    for (const s of [alice, bob]) { await c.usdg.connect(s).approve(acct, ethers.MaxUint256); await acct.connect(s).deposit(USD(3000)); }
    await c.usdg.mint(atk, USD(29000));
    await atk.deposit(acct, c.usdg, USD(1000));
    const evil = await c.Registry.deploy(c.usdg, c.oracle, c.adapter, treasury, 0, 0, 0, [await c.nvda.getAddress()]);
    await time.increase(3601);
    // staging in one transaction is refused outright: shares just minted can't be withdrawn
    await expect(atk.stage(acct, c.usdg, USD(14000), await evil.getAddress())).to.be.revertedWithCustomError(acct, "Held");
    expect(await acct.proposalCount()).to.equal(0n);
    await time.increase(12 * 3600 + 1);
    expect(await acct.registry()).to.equal(await c.registry.getAddress());
    // alice and bob still leave with their 3,000
    const before = await c.usdg.balanceOf(alice);
    await acct.connect(alice).leave();
    expect((await c.usdg.balanceOf(alice)) - before).to.be.closeTo(USD(3000), USD(1));
  });

  it("a signer leaving resets readiness too", async () => {
    const c = await deploy();
    await fund(c);
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 100), "");
    await c.acct.connect(c.ben).approve(0);
    expect((await c.acct.getProposal(0)).readyAt).to.not.equal(0n);
    await c.acct.connect(c.ben).leave(); // 1 of 2 left, below two thirds
    expect((await c.acct.getProposal(0)).readyAt).to.equal(0n);
  });

  it("N-3: someone who never signed can't stall a pitch by depositing; their weight is checked at execute", async () => {
    const c = await deploy({ mode: Mode.Shares });
    await fund(c); // ana 1000, ben 1000, cai 2000
    await c.acct.connect(c.cai).propose(Kind.Trade, await buy(c, 100), ""); // cai 50%, not enough
    await c.acct.connect(c.ana).approve(0); // 75%: ready
    const ready = (await c.acct.getProposal(0)).readyAt;
    expect(ready).to.not.equal(0n);
    // ben never signs and tries to stall it: deposit to dilute, wait out the hold, take it out, repeat
    for (let i = 0; i < 3; i++) {
      await c.acct.connect(c.ben).deposit(USD(4000));
      expect((await c.acct.getProposal(0)).readyAt).to.equal(ready); // no reset
      await time.increase(3601);
      await c.acct.connect(c.ben).withdraw(await c.acct.freeShares(c.ben) / 2n);
    }
    // while ben's extra weight is in, the pitch simply doesn't pass at execute
    await c.acct.connect(c.ben).deposit(USD(4000));
    await time.increase(12 * 3600);
    await expect(c.acct.connect(c.cai).execute(0)).to.be.revertedWithCustomError(c.acct, "ThresholdNotMet");
    // once it's out again the original cool-off stands, so the pitch runs
    await time.increase(3601);
    await c.acct.connect(c.ben).withdraw((await c.acct.sharesOf(c.ben)) - (await c.acct.sharesOf(c.ana))); // back to 1,000
    await c.acct.connect(c.cai).execute(0);
  });

  it("a signer taking weight out still resets the pitches they signed (M-2 stays closed)", async () => {
    const c = await deploy({ mode: Mode.Shares });
    await fund(c);
    await c.acct.connect(c.cai).propose(Kind.Trade, await buy(c, 100), "");
    await c.acct.connect(c.ana).approve(0); // 75%: ready
    await c.acct.connect(c.cai).withdraw((await c.acct.sharesOf(c.cai)) * 3n / 4n); // cai's own weight falls
    expect((await c.acct.getProposal(0)).readyAt).to.equal(0n);
  });

  it("exits stay cheap and never blocked, even with many pitches waiting", async () => {
    const c = await deploy({ mode: Mode.Shares });
    await fund(c);
    await c.acct.connect(c.cai).deposit(USD(20000));
    await time.increase(3601);
    const max = Number(await c.acct.MAX_READY());
    for (let i = 0; i < max; i++) await c.acct.connect(c.cai).propose(Kind.Trade, await buy(c, 10), "");
    await expect(c.acct.connect(c.cai).propose(Kind.Trade, await buy(c, 10), "")).to.be.revertedWithCustomError(c.acct, "TooManyPending");
    const tx = await c.acct.connect(c.ana).leave();
    const gas = (await tx.wait()).gasUsed;
    expect(gas).to.be.lessThan(1_500_000n);
    const tx2 = await c.acct.connect(c.cai).withdraw(await c.acct.sharesOf(c.cai) / 2n);
    expect((await tx2.wait()).gasUsed).to.be.lessThan(1_500_000n);
  });
});

describe("Review: extra layers from the report", () => {
  it("M-1 fix 2: a trade can't come back more than 3% under the oracle, whatever minOut says", async () => {
    const c = await deploy();
    await fund(c);
    await c.adapter.setHaircut(2000); // a sandwiched fill: 20% worse than Chainlink
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 1000, 1), "minOut 1");
    await c.acct.connect(c.ben).approve(0);
    await c.acct.connect(c.cai).approve(0);
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "OracleBound");
    await c.adapter.setHaircut(250); // 2.5%: inside the bound
    await c.acct.connect(c.ana).execute(0);
  });

  it("M-1 fix 3: a member still waiting to vote can't run a pitch", async () => {
    const c = await deploy({ open: true, seats: 5 });
    await fund(c);
    await c.acct.connect(c.dee).join(USD(500), await c.acct.readyHash());
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 100), "");
    await c.acct.connect(c.cai).approve(0);
    await time.increase(12 * 3600);
    await expect(c.acct.connect(c.dee).execute(0)).to.be.revertedWithCustomError(c.acct, "NotMember");
    await c.acct.connect(c.ben).execute(0);
  });

  it("I-4: moving the registry waits 12 hours even when the crew set its cool-off to 0", async () => {
    const c = await deploy();
    await fund(c);
    await passAll(c, Kind.SetRules, coder.encode(["uint16", "uint32"], [6666, 0]));
    const next = await c.Registry.deploy(c.usdg, c.oracle, c.adapter, c.treasury, 20, 20, 0, [await c.nvda.getAddress()]);
    const id = await c.acct.proposalCount();
    await c.acct.connect(c.ana).propose(Kind.MoveRegistry, addr(await next.getAddress()), "");
    await c.acct.connect(c.ben).approve(id);
    await expect(c.acct.connect(c.ana).execute(id)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    // an ordinary trade with the same 0 cool-off still runs at once
    const t = await c.acct.proposalCount();
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 100), "");
    await c.acct.connect(c.ben).approve(t);
    await c.acct.connect(c.ana).execute(t);
    await time.increase(12 * 3600);
    await c.acct.connect(c.ana).execute(id);
  });

  it("I-5: a swap that doesn't spend exactly what it was given is refused", async () => {
    const c = await deploy();
    await fund(c);
    await c.adapter.setTake(9000); // pool runs dry: only 90% spent
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 1000), "");
    await c.acct.connect(c.ben).approve(0);
    await c.acct.connect(c.cai).approve(0);
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "PartialFill");
  });

  it("I-1: one paused token doesn't lock the rest; what couldn't be sent is owed and claimable", async () => {
    const c = await deploy({ fee: 0 });
    await fund(c);
    await passAll(c, Kind.Trade, await buy(c, 2000));
    await c.nvda.setPaused(true);
    const u0 = await c.usdg.balanceOf(c.cai);
    const v0 = await c.acct.accountValue.staticCall().catch(() => 0n);
    await c.acct.connect(c.cai).leave(); // half the crew
    expect((await c.usdg.balanceOf(c.cai)) - u0).to.be.closeTo(USD(1000), 2n); // the USDG half arrives now
    const owedNvda = await c.acct.owed(c.cai, c.nvda);
    expect(owedNvda).to.be.greaterThan(0n);
    // what cai is owed is no longer the crew's: it isn't valued, paid out again, or tradeable
    expect(await c.acct.accountValue()).to.be.closeTo(v0 / 2n, USD(1));
    await expect(c.acct.connect(c.cai).claim(c.nvda)).to.be.revertedWith("paused");
    await c.nvda.setPaused(false);
    await c.acct.connect(c.cai).claim(c.nvda);
    expect(await c.nvda.balanceOf(c.cai)).to.equal(owedNvda);
    expect(await c.acct.owedTotal(c.nvda)).to.equal(0n);
    // the others still get exactly their half
    await c.acct.connect(c.ana).leave();
    await c.acct.connect(c.ben).leave();
    expect(await c.nvda.balanceOf(c.acct)).to.be.lessThan(10n);
  });
});

describe("Retest: N-1 and follow-ups", () => {
  it("N-1 / R-1: a join must agree to the pitches already ready, so nothing runs on a newcomer by surprise", async () => {
    const c = await deploy({ open: true, seats: 5 });
    await c.acct.connect(c.ana).deposit(USD(10));
    await time.increase(3601);
    await c.acct.connect(c.ben).leave();
    await c.acct.connect(c.cai).leave(); // ana is the crew's only member, so her pitch is unanimous
    const seen = await c.acct.readyHash(); // what a newcomer looking now would see: nothing ready
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 9), "staged");
    await time.increase(13 * 3600);
    // the newcomer's view is out of date: a pitch became ready since, so the join is refused
    await expect(c.acct.connect(c.dee).join(USD(10000), seen)).to.be.revertedWithCustomError(c.acct, "ReadySetChanged");
    expect(await c.acct.readyHash()).to.not.equal(seen);
  });

  it("R-1: joining and leaving never moves anyone's cool-off, so churn can't freeze a crew", async () => {
    const c = await deploy({ open: true, seats: 6, minJoin: USD(10) });
    await fund(c);
    const churner = c.rest[0];
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 100), "");
    await c.acct.connect(c.cai).approve(0); // ana + cai: 75% of shares, ready, not unanimous
    for (let i = 0; i < 3; i++) {
      await c.acct.connect(churner).join(USD(10), await c.acct.readyHash());
      await time.increase(3601);
      await c.acct.connect(churner).leave();
      await time.increase(3 * 3600);
    }
    await c.acct.connect(churner).join(USD(10), await c.acct.readyHash()); // still in, never signs
    await time.increase(3 * 3600);
    await c.acct.connect(c.ana).execute(0); // 12h after it became ready, churn or not
  });

  it("N-1: a pitch can't be sized for money that isn't in the crew yet", async () => {
    const c = await deploy();
    await fund(c); // 4,000
    await expect(c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 9900), "")).to.be.revertedWithCustomError(c.acct, "ZeroAmount");
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 4000), "");
  });

  it("N-2: when a newcomer gains their vote, the cool-off starts over from that moment", async () => {
    const c = await deploy({ open: true, seats: 5 });
    await fund(c);
    await c.acct.connect(c.dee).join(USD(100), await c.acct.readyHash());
    await time.increase(3 * 86400 - 13 * 3600); // 13h before dee can vote
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 100), "");
    await c.acct.connect(c.ben).approve(0);
    await c.acct.connect(c.cai).approve(0); // 3 of 4 once dee counts, still not unanimous
    await time.increase(13 * 3600 + 1); // 13h on: past the pitch's own 12h, and dee just gained the vote
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    // it still passes with dee counted, so poke re-stamps it and a fresh cool-off starts
    await c.acct.poke(0);
    await time.increase(11 * 3600);
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    await time.increase(3600 + 1);
    await c.acct.connect(c.ana).execute(0);
  });

  it("N-2: a pitch that looked dead once newcomers could vote can't run on its old readiness", async () => {
    const c = await deploy({ open: true, seats: 5 });
    await fund(c); // ana 1000, ben 1000, cai 2000
    await c.acct.connect(c.dee).join(USD(3000), await c.acct.readyHash());
    await c.acct.connect(c.rest[0]).join(USD(3000), await c.acct.readyHash());
    await time.increase(3 * 86400 - 3600);
    await c.acct.connect(c.cai).propose(Kind.Trade, await buy(c, 100), ""); // cai 50% of voters: not enough
    await c.acct.connect(c.ana).approve(0); // 75%: ready, while dee and rest[0] can't vote yet
    await time.increase(3600 + 1); // they can vote now: signers hold 3,000 of ~9,000, the pitch looks dead
    const [yes, needed] = await c.acct.tally(0);
    expect(yes).to.be.lessThan(needed);
    await time.increase(12 * 3600);
    // cai brings weight back in for a moment: the old readiness doesn't count, so it can't run at once
    await c.acct.connect(c.cai).deposit(USD(20000));
    await expect(c.acct.connect(c.cai).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    // only a fresh pass, visible to everyone for a full cool-off, can run it
    await c.acct.poke(0);
    await expect(c.acct.connect(c.cai).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
  });

  it("oracle: a token whose feed went stale can still be sold into USDG, held to minOut; buying it can't", async () => {
    const c = await deploy({ fee: 0 });
    await fund(c);
    await passAll(c, Kind.Trade, await buy(c, 1000));
    const held = await c.nvda.balanceOf(c.acct);
    await c.oracle.setStale(c.nvda, true);
    await expect(passAll(c, Kind.Trade, await buy(c, 100))).to.be.revertedWith("StalePrice");
    // selling it into USDG still works, with the pitch's minOut as the only limit
    const sell = trade(await c.nvda.getAddress(), await c.usdg.getAddress(), held, USD(999));
    await expect(passAll(c, Kind.Trade, trade(await c.nvda.getAddress(), await c.usdg.getAddress(), held, USD(1001)))).to.be.revertedWithCustomError(c.acct, "Slippage");
    await passAll(c, Kind.Trade, sell);
    expect(await c.nvda.balanceOf(c.acct)).to.equal(0n);
    // while the feed is live, the 3% bound applies to sales too
    await c.oracle.setStale(c.nvda, false);
    await passAll(c, Kind.Trade, await buy(c, 500));
    await c.adapter.setHaircut(1000);
    await expect(passAll(c, Kind.Trade, trade(await c.nvda.getAddress(), await c.usdg.getAddress(), await c.nvda.balanceOf(c.acct), 1))).to.be.revertedWithCustomError(c.acct, "OracleBound");
  });

  it("I-5: an adapter that keeps part of what it was given is refused", async () => {
    const c = await deploy();
    await fund(c);
    await c.adapter.setKeep(1000); // pulls everything, swaps 90%, keeps 10%
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 1000), "");
    await c.acct.connect(c.ben).approve(0);
    await c.acct.connect(c.cai).approve(0);
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "PartialFill");
  });
});

describe("I-2: corporate actions", () => {
  it("deposits and joins pause around a held token's multiplier change; exits and trades don't", async () => {
    const c = await deploy({ open: true, seats: 5 });
    await fund(c);
    await passAll(c, Kind.Trade, await buy(c, 1000)); // the crew holds NVDA
    await c.nvda.withMultiplier();
    const now = BigInt(await time.latest());
    // a split scheduled 10 days out: too far ahead to matter
    await c.nvda.scheduleMultiplier(ONE(2), now + 10n * 86400n);
    await c.acct.connect(c.ana).deposit(USD(10));
    // 2 days out: paused
    await time.increase(8 * 86400);
    await expect(c.acct.connect(c.ana).deposit(USD(10))).to.be.revertedWithCustomError(c.acct, "CorporateAction");
    await expect(c.acct.connect(c.dee).join(USD(100), await c.acct.readyHash())).to.be.revertedWithCustomError(c.acct, "CorporateAction");
    // exits still work
    await c.acct.connect(c.ben).withdraw((await c.acct.freeShares(c.ben)) / 2n);
    // the day after it takes effect: still paused, then open again
    await time.increase(2 * 86400 + 60);
    await expect(c.acct.connect(c.ana).deposit(USD(10))).to.be.revertedWithCustomError(c.acct, "CorporateAction");
    await time.increase(86400);
    await c.acct.connect(c.ana).deposit(USD(10));
  });

  it("R-3: a small dividend-sized step ahead doesn't pause new money", async () => {
    const c = await deploy();
    await fund(c);
    await passAll(c, Kind.Trade, await buy(c, 1000));
    await c.nvda.withMultiplier();
    const now = BigInt(await time.latest());
    await c.nvda.scheduleMultiplier(ONE(1.004), now + 2n * 86400n); // +0.4%, two days out
    await c.acct.connect(c.ana).deposit(USD(10));
  });

  it("R-2: trades in a token pause around its split; other trades and exits don't", async () => {
    const c = await deploy();
    await fund(c);
    await passAll(c, Kind.Trade, await buy(c, 1000));
    await c.nvda.withMultiplier();
    const now = BigInt(await time.latest());
    await c.nvda.scheduleMultiplier(ONE(10), now + 86400n); // a 10-for-1 split tomorrow
    await expect(passAll(c, Kind.Trade, await buy(c, 100))).to.be.revertedWithCustomError(c.acct, "CorporateAction");
    await c.acct.connect(c.cai).leave(); // exits are fine
  });
});

describe("R-4: the account deployer answers only to its factory", () => {
  it("refuses anyone else, so every account it makes is listed by the factory", async () => {
    const c = await deploy();
    const d = await ethers.getContractAt("RheilonAccountDeployer", await c.factory.deployer());
    expect(await d.factory()).to.equal(await c.factory.getAddress());
    await expect(d.connect(c.ana).deploy(c.registry, "Fake", [c.ana.address], [0, false, 5, 0])).to.be.revertedWithCustomError(d, "OnlyFactory");
  });
});

describe("Self-review: closing an open crew to joins", () => {
  it("an open crew can vote to close itself; churners can't stall that vote or come back", async () => {
    const c = await deploy({ open: true, seats: 8, minJoin: USD(10) });
    await fund(c);
    const churn = c.rest.slice(0, 3);
    for (const w of churn) await c.acct.connect(w).join(USD(10), await c.acct.readyHash());
    await time.increase(3600);
    // ana + cai (75%) vote to close; churners gain their vote mid-way, which would make other pitches start over
    const id = await c.acct.proposalCount();
    await c.acct.connect(c.ana).propose(Kind.SetJoins, coder.encode(["bool"], [false]), "close the door");
    await c.acct.connect(c.cai).approve(id);
    await time.increase(3 * 86400 - 1800); // churners can vote now, past the 12h too, before the pitch expires
    await c.acct.connect(c.ana).execute(id); // SetJoins isn't held off by newcomers' votes starting
    expect(await c.acct.open()).to.equal(false);
    expect(await c.acct.bornOpen()).to.equal(true);
    await c.acct.connect(churn[0]).leave();
    await expect(c.acct.connect(churn[0]).join(USD(10), await c.acct.readyHash())).to.be.revertedWithCustomError(c.acct, "Closed");
    // still an open crew at heart: no registry moves, no short cool-off
    await expect(c.acct.connect(c.ana).propose(Kind.MoveRegistry, addr(await c.registry.getAddress()), "")).to.be.revertedWithCustomError(c.acct, "BadRegistry");
    await expect(c.acct.connect(c.ana).propose(Kind.SetRules, coder.encode(["uint16", "uint32"], [6666, 0]), "")).to.be.revertedWithCustomError(c.acct, "BadRules");
    // and it can reopen the same way
    const id2 = await c.acct.proposalCount();
    await c.acct.connect(c.ana).propose(Kind.SetJoins, coder.encode(["bool"], [true]), "");
    await c.acct.connect(c.cai).approve(id2);
    await time.increase(12 * 3600 + 1);
    await c.acct.connect(c.ana).execute(id2);
    expect(await c.acct.open()).to.equal(true);
  });

  it("a private crew can't open itself", async () => {
    const c = await deploy();
    await fund(c);
    await expect(c.acct.connect(c.ana).propose(Kind.SetJoins, coder.encode(["bool"], [true]), "")).to.be.revertedWithCustomError(c.acct, "BadRules");
  });
});

describe("Final retest: R-5", () => {
  it("a vote start stays a reset point after its member leaves, so stale pitches can't come back", async () => {
    const c = await deploy({ open: true, seats: 5, minJoin: USD(10) });
    await c.acct.connect(c.ana).deposit(USD(10));
    await time.increase(3601);
    await c.acct.connect(c.ben).leave();
    await c.acct.connect(c.cai).leave(); // ana alone: her pitches are unanimous
    // an accomplice joins; shortly before it gains its vote, she stages a pitch; its vote starting makes the pitch stale
    const acc = c.rest[0];
    await c.acct.connect(acc).join(USD(10), await c.acct.readyHash());
    await time.increase(3 * 86400 - 2 * 3600);
    await c.acct.connect(c.ana).propose(Kind.Trade, await buy(c, 9), "staged");
    await time.increase(12 * 3600 + 60); // accomplice can vote, and the pitch's own 12h has run
    const fresh = await c.acct.readyHash(); // the stale pitch is left out
    await c.acct.connect(c.dee).join(USD(10000), fresh); // newcomer consents to what they see: nothing ready
    await c.acct.connect(acc).leave(); // the accomplice walks out
    // the old readiness doesn't come back: ana can't run it on the newcomer's money
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    expect(await c.acct.leftVoteStart()).to.be.greaterThan(0n);
  });
});
