const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const USD = (n) => ethers.parseUnits(String(n), 6);
const ONE = (n) => ethers.parseUnits(String(n), 18);
const Kind = { Trade: 0, AddMember: 1, SetRules: 2, MoveRegistry: 3 };
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
}

async function passAll(c, kind, data) {
  const id = await c.acct.proposalCount();
  await c.acct.connect(c.ana).propose(kind, data, "");
  await c.acct.connect(c.ben).approve(id);
  await c.acct.connect(c.cai).approve(id);
  await c.acct.connect(c.ana).execute(id);
  return id;
}

describe("Registry has no owner", () => {
  it("exposes no admin functions and rejects fees above 0.20%", async () => {
    const c = await deploy();
    for (const fn of ["owner", "setOracle", "setSwapAdapter", "setSupported", "transferOwnership", "renounceOwnership"]) {
      expect(c.registry[fn]).to.equal(undefined);
    }
    await expect(c.Registry.deploy(c.usdg, c.oracle, c.adapter, c.treasury, 21, 0, 0, [])).to.be.revertedWithCustomError(c.registry, "BadConfig");
    expect(await c.registry.supportedAssets()).to.deep.equal([await c.usdg.getAddress(), await c.nvda.getAddress()]);
  });
});

describe("Money in and out", () => {
  it("prices shares by value and pays out fairly", async () => {
    const c = await deploy();
    await fund(c);
    expect(await c.acct.sharesOf(c.cai)).to.be.closeTo((await c.acct.sharesOf(c.ana)) * 2n, 2n);
    expect(await c.acct.accountValue()).to.equal(USD(4000));
  });

  it("partial withdraw pays in kind and keeps membership", async () => {
    const c = await deploy({ fee: 0 });
    await fund(c);
    await passAll(c, Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(2000), 0)); // 10 NVDA
    const half = (await c.acct.sharesOf(c.cai)) / 2n; // cai owns 50% -> half = 25% of the account
    const u0 = await c.usdg.balanceOf(c.cai);
    await c.acct.connect(c.cai).withdraw(half);
    expect((await c.usdg.balanceOf(c.cai)) - u0).to.be.closeTo(USD(500), 2n);
    expect(await c.nvda.balanceOf(c.cai)).to.be.closeTo(ONE(2.5), 10n);
    expect(await c.acct.isMember(c.cai)).to.equal(true);
    await expect(c.acct.connect(c.cai).withdraw((await c.acct.sharesOf(c.cai)) + 1n)).to.be.revertedWithCustomError(c.acct, "ZeroAmount");
  });

  it("leaving is free, takes everything owed, and removes the member", async () => {
    const c = await deploy();
    await fund(c);
    const u0 = await c.usdg.balanceOf(c.ana);
    await c.acct.connect(c.ana).leave();
    expect((await c.usdg.balanceOf(c.ana)) - u0).to.be.closeTo(USD(1000), 2n);
    expect(await c.acct.isMember(c.ana)).to.equal(false);
    expect(await c.usdg.balanceOf(c.treasury)).to.equal(0n);
  });

  it("enforces the beta value cap on deposits", async () => {
    const c = await deploy({ cap: USD(5000) });
    await fund(c); // 4000
    await expect(c.acct.connect(c.ana).deposit(USD(1001))).to.be.revertedWithCustomError(c.acct, "OverCap");
    await c.acct.connect(c.ana).deposit(USD(1000));
  });

  it("new deposits after a gain don't dilute earlier members", async () => {
    const c = await deploy({ fee: 0 });
    await fund(c);
    await passAll(c, Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(4000), 0));
    await c.oracle.setPrice(c.nvda, USD(400)); // value doubles to 8000
    const before = await c.acct.totalShares();
    await c.acct.connect(c.ana).deposit(USD(8000));
    expect((await c.acct.totalShares()) - before).to.be.closeTo(before, before / 1_000_000n);
  });

  it("no value is created or lost across random deposits and exits", async () => {
    const c = await deploy({ fee: 0 });
    await fund(c);
    await passAll(c, Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(2000), 0));
    let seed = 7;
    const rnd = () => ((seed = (seed * 1103515245 + 12345) % 2147483648), seed / 2147483648);
    const signers = [c.ana, c.ben, c.cai];
    let deposited = 0n;
    for (let i = 0; i < 12; i++) {
      const amt = USD(1 + Math.floor(rnd() * 900));
      await c.acct.connect(signers[Math.floor(rnd() * 3)]).deposit(amt);
      deposited += amt;
    }
    const valueOf = async (s) => (await c.usdg.balanceOf(s)) + ((await c.nvda.balanceOf(s)) * USD(200)) / ONE(1);
    const start = {};
    for (const s of signers) start[s.address] = await valueOf(s);
    for (let i = 0; i < 4; i++) {
      const s = signers[Math.floor(rnd() * 3)];
      await c.acct.connect(s).withdraw((await c.acct.sharesOf(s)) / 5n);
    }
    for (const s of signers) await c.acct.connect(s).leave();
    let received = 0n;
    for (const s of signers) received += (await valueOf(s)) - start[s.address];
    expect(await c.acct.totalShares()).to.equal(0n);
    expect(received).to.be.closeTo(USD(4000) + deposited, 20n); // everything that went in comes back out, minus dust
  });
});

describe("Fees", () => {
  it("charges 0.20% in USDG on buys", async () => {
    const c = await deploy();
    await fund(c);
    await passAll(c, Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(1000), 0));
    expect(await c.usdg.balanceOf(c.treasury)).to.equal(USD(2)); // 0.2% of 1000
    expect(await c.nvda.balanceOf(c.acct)).to.equal(ONE(4.99)); // 998 / 200
  });

  it("charges 0.20% in USDG on sells, and minOut protects the net amount", async () => {
    const c = await deploy();
    await fund(c);
    await passAll(c, Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(1000), 0));
    const t0 = await c.usdg.balanceOf(c.treasury);
    await passAll(c, Kind.Trade, trade(await c.nvda.getAddress(), await c.usdg.getAddress(), ONE(4.99), USD(996)));
    expect((await c.usdg.balanceOf(c.treasury)) - t0).to.be.closeTo(USD(1.996), 1n);

    await passAll(c, Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(1000), 0));
    const id = await c.acct.proposalCount();
    await c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.nvda.getAddress(), await c.usdg.getAddress(), ONE(4.99), USD(998)), "");
    await c.acct.connect(c.ben).approve(id);
    await c.acct.connect(c.cai).approve(id);
    await expect(c.acct.connect(c.ana).execute(id)).to.be.revertedWithCustomError(c.acct, "Slippage");
  });
});

describe("Voting", () => {
  it("heads mode: two thirds of members, then a 12h cool-off", async () => {
    const c = await deploy();
    await fund(c);
    await c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(100), 0), "");
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "ThresholdNotMet");
    await c.acct.connect(c.ben).approve(0);
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
    await time.increase(12 * 3600);
    await c.acct.connect(c.ana).execute(0);
  });

  it("shares mode: a big holder alone can pass, small holders alone cannot", async () => {
    const c = await deploy({ mode: Mode.Shares });
    await c.acct.connect(c.ana).deposit(USD(100));
    await c.acct.connect(c.ben).deposit(USD(100));
    await c.acct.connect(c.cai).deposit(USD(4800)); // 96%
    await c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(100), 0), "");
    await c.acct.connect(c.ben).approve(0);
    const [yes, needed] = await c.acct.tally(0);
    expect(yes).to.be.lessThan(needed);
    await c.acct.connect(c.cai).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(100), 0), "");
    const [y2, n2] = await c.acct.tally(1);
    expect(y2).to.be.greaterThanOrEqual(n2);
    await expect(c.acct.connect(c.cai).execute(1)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
  });

  it("withdrawing signatures below the threshold restarts the cool-off", async () => {
    const c = await deploy();
    await fund(c);
    await c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(100), 0), "");
    await c.acct.connect(c.ben).approve(0);
    await c.acct.connect(c.ben).unapprove(0);
    expect((await c.acct.getProposal(0)).readyAt).to.equal(0n);
    await time.increase(13 * 3600);
    await c.acct.connect(c.ben).approve(0);
    await expect(c.acct.connect(c.ana).execute(0)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
  });

  it("a dissenter can leave during the cool-off", async () => {
    const c = await deploy({ fee: 0 });
    await fund(c);
    await c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(3000), 0), "all in");
    await c.acct.connect(c.ben).approve(0);
    const u0 = await c.usdg.balanceOf(c.cai);
    await c.acct.connect(c.cai).leave();
    expect((await c.usdg.balanceOf(c.cai)) - u0).to.be.closeTo(USD(2000), 2n);
  });

  it("stale approvals don't survive leaving and rejoining", async () => {
    const c = await deploy();
    await fund(c);
    await c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(100), 0), "");
    await c.acct.connect(c.ben).approve(0);
    await c.acct.connect(c.ben).leave();
    await c.acct.connect(c.ana).propose(Kind.AddMember, addr(c.ben.address), "");
    await c.acct.connect(c.cai).approve(1);
    await c.acct.connect(c.ana).execute(1);
    expect(await c.acct.hasApproved(0, c.ben)).to.equal(false);
  });

  it("rules change only by vote and within bounds; proposals expire", async () => {
    const c = await deploy();
    await expect(c.acct.connect(c.ana).propose(Kind.SetRules, coder.encode(["uint16", "uint32"], [5000, 3600]), "")).to.be.revertedWithCustomError(c.acct, "BadRules");
    await passAll(c, Kind.SetRules, coder.encode(["uint16", "uint32"], [7500, 3600]));
    expect(await c.acct.thresholdBps()).to.equal(7500);
    await c.acct.connect(c.ana).propose(Kind.AddMember, addr(c.dee.address), "");
    await time.increase(3 * 86400 + 1);
    await expect(c.acct.connect(c.ben).approve(1)).to.be.revertedWithCustomError(c.acct, "NotActive");
  });

  it("outsiders can't deposit, propose, approve or execute", async () => {
    const c = await deploy();
    await expect(c.acct.connect(c.outsider).deposit(USD(1))).to.be.revertedWithCustomError(c.acct, "NotMember");
    await c.acct.connect(c.ana).propose(Kind.AddMember, addr(c.dee.address), "");
    await expect(c.acct.connect(c.outsider).approve(0)).to.be.revertedWithCustomError(c.acct, "NotMember");
    await expect(c.acct.connect(c.outsider).execute(0)).to.be.revertedWithCustomError(c.acct, "NotMember");
  });
});

describe("Assets and registries", () => {
  it("can't sell what isn't held or buy what isn't supported", async () => {
    const c = await deploy();
    await fund(c);
    await expect(c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.nvda.getAddress(), await c.usdg.getAddress(), 1, 0), "")).to.be.revertedWithCustomError(c.acct, "NotHeld");
    await expect(c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), c.outsider.address, 1, 0), "")).to.be.revertedWithCustomError(c.acct, "UnsupportedAsset");
  });

  it("moves to a new registry only by vote; held assets stay sellable even if not listed there", async () => {
    const c = await deploy();
    await fund(c);
    await passAll(c, Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(1000), 0));
    const r2 = await c.Registry.deploy(c.usdg, c.oracle, c.adapter, c.treasury, 10, 0, 0, []); // NVDA not listed
    await passAll(c, Kind.MoveRegistry, addr(await r2.getAddress()));
    expect(await c.acct.registry()).to.equal(await r2.getAddress());
    expect(await c.acct.feeBps()).to.equal(10);
    await passAll(c, Kind.Trade, trade(await c.nvda.getAddress(), await c.usdg.getAddress(), ONE(1), 0));
    await expect(c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(1), 0), "")).to.be.revertedWithCustomError(c.acct, "UnsupportedAsset");
  });

  it("rejects a registry with a different base asset", async () => {
    const c = await deploy();
    const Token = await ethers.getContractFactory("MockToken");
    const other = await Token.deploy("Other", "OTH", 6);
    const r2 = await c.Registry.deploy(other, c.oracle, c.adapter, c.treasury, 0, 0, 0, []);
    await expect(c.acct.connect(c.ana).propose(Kind.MoveRegistry, addr(await r2.getAddress()), "")).to.be.revertedWithCustomError(c.acct, "BadRegistry");
  });
});

describe("Crew size", () => {
  it("allows 2 to 10 seats and never more members than seats", async () => {
    const c = await deploy();
    const [, , ana, ben] = await ethers.getSigners();
    await expect(c.factory.connect(ana).createAccount("Big", [], Mode.Heads, false, 11, 0)).to.be.revertedWithCustomError(c.acct, "BadConfig");
    await expect(c.factory.connect(ana).createAccount("Tiny", [], Mode.Heads, false, 1, 0)).to.be.revertedWithCustomError(c.acct, "BadConfig");
    await expect(c.factory.connect(ana).createAccount("Over", [ben, c.cai, c.dee], Mode.Heads, false, 3, 0)).to.be.revertedWithCustomError(c.acct, "BadConfig");
    // private crew with 3 seats, already 3 members: a 4th can't be voted in
    const a = await c.factory.connect(ana).createAccount.staticCall("Three", [ben, c.cai], Mode.Heads, false, 3, 0);
    await c.factory.connect(ana).createAccount("Three", [ben, c.cai], Mode.Heads, false, 3, 0);
    const three = await ethers.getContractAt("RheilonAccount", a);
    await three.connect(ana).propose(Kind.AddMember, addr(c.dee.address), "");
    await three.connect(ben).approve(0);
    await three.connect(c.cai).approve(0);
    await expect(three.connect(ana).execute(0)).to.be.revertedWithCustomError(three, "TooManyMembers");
  });
});

describe("Open crews", () => {
  it("anyone can join while seats are free, paying a 0.20% join fee; then it's full", async () => {
    const c = await deploy({ open: true, seats: 5, minJoin: USD(50) });
    await fund(c);
    await expect(c.acct.connect(c.dee).join(USD(49))).to.be.revertedWithCustomError(c.acct, "BelowMinimum");
    await c.acct.connect(c.dee).join(USD(1000));
    expect(await c.usdg.balanceOf(c.treasury)).to.equal(USD(2));
    expect(await c.acct.accountValue()).to.equal(USD(4998));
    await c.acct.connect(c.outsider).join(USD(100));
    expect(await c.acct.seatsLeft()).to.equal(0n);
    await expect(c.acct.connect(c.rest[0]).join(USD(100))).to.be.revertedWithCustomError(c.acct, "Full");
    // leaving frees a seat, and leaving is free
    const t0 = await c.usdg.balanceOf(c.treasury);
    await c.acct.connect(c.dee).leave();
    expect(await c.usdg.balanceOf(c.treasury)).to.equal(t0);
    await c.acct.connect(c.rest[0]).join(USD(100));
  });

  it("open crews must vote by shares", async () => {
    const c = await deploy();
    await expect(c.factory.connect(c.ana).createAccount("O", [], Mode.Heads, true, 5, 0)).to.be.revertedWithCustomError(c.acct, "BadConfig");
  });

  it("private crews can't be joined directly", async () => {
    const c = await deploy();
    await expect(c.acct.connect(c.dee).join(USD(100))).to.be.revertedWithCustomError(c.acct, "Closed");
  });

  it("newcomers vote only after 3 days and don't count until then", async () => {
    const c = await deploy({ open: true, seats: 5 });
    await fund(c);
    await c.acct.connect(c.dee).join(USD(500));
    await expect(c.acct.connect(c.dee).propose(Kind.AddMember, addr(c.outsider.address), "")).to.be.revertedWithCustomError(c.acct, "NotMember");
    await c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(100), 0), "");
    await expect(c.acct.connect(c.dee).approve(0)).to.be.revertedWithCustomError(c.acct, "NotMember");
    expect(await c.acct.voterCount()).to.equal(3n); // dee doesn't raise the bar either
    await c.acct.connect(c.ben).approve(0);
    await c.acct.connect(c.cai).approve(0);
    await c.acct.connect(c.ana).execute(0); // every current voter signed: runs now
    await time.increase(3 * 86400);
    expect(await c.acct.canVote(c.dee)).to.equal(true);
  });

  it("a wallet swarm can't take over: no instant votes, no registry moves, no short cool-off, and others leave whole", async () => {
    const c = await deploy({ open: true, seats: 10, minJoin: USD(10) });
    await fund(c);
    const swarm = c.rest.slice(0, 7);
    for (const w of swarm) await c.acct.connect(w).join(USD(10));
    // right after joining they can't do anything
    await expect(c.acct.connect(swarm[0]).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(100), 0), "")).to.be.revertedWithCustomError(c.acct, "NotMember");
    await time.increase(3 * 86400);
    // even with 7 of 10 heads, they can't move the crew to a fake registry or shorten the cool-off
    const fake = await c.Registry.deploy(c.usdg, c.oracle, c.adapter, swarm[0].address, 0, 0, 0, []);
    await expect(c.acct.connect(swarm[0]).propose(Kind.MoveRegistry, addr(await fake.getAddress()), "")).to.be.revertedWithCustomError(c.acct, "BadRegistry");
    await expect(c.acct.connect(swarm[0]).propose(Kind.SetRules, coder.encode(["uint16", "uint32"], [6666, 0]), "")).to.be.revertedWithCustomError(c.acct, "BadRules");
    // with votes by shares, 7 wallets x $10 can't pass anything against $4,000 of real members
    await c.acct.connect(swarm[0]).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(3000), 0), "");
    for (const w of swarm.slice(1)) await c.acct.connect(w).approve(0);
    const [yes, needed] = await c.acct.tally(0);
    expect(yes).to.be.lessThan(needed / 10n);
    await expect(c.acct.connect(swarm[0]).execute(0)).to.be.revertedWithCustomError(c.acct, "ThresholdNotMet");
    // and members can always walk away whole
    const before = await c.usdg.balanceOf(c.cai);
    await c.acct.connect(c.cai).leave();
    expect((await c.usdg.balanceOf(c.cai)) - before).to.be.closeTo(USD(2000), USD(1));
  });

  it("votes by shares in an open crew: a big newcomer still waits 3 days", async () => {
    const c = await deploy({ open: true, seats: 5, mode: Mode.Shares });
    await fund(c);
    await c.acct.connect(c.dee).join(USD(20000)); // would be ~83% of shares
    await c.acct.connect(c.ana).propose(Kind.Trade, trade(await c.usdg.getAddress(), await c.nvda.getAddress(), USD(100), 0), "");
    const [yes, needed] = await c.acct.tally(0);
    expect(yes).to.be.lessThan(needed); // ana alone: 25% of voting shares, dee not counted yet
    await expect(c.acct.connect(c.dee).approve(0)).to.be.revertedWithCustomError(c.acct, "NotMember");
  });
});
