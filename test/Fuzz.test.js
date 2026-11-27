// Random sequences of everything people can do to a crew, with the rules that must hold after every step.
// Seeds are fixed, so a failure can be replayed exactly. Run: npx hardhat test test/Fuzz.test.js
const { expect } = require("chai");
const { ethers } = require("hardhat");
const { time } = require("@nomicfoundation/hardhat-network-helpers");

const USD = (n) => ethers.parseUnits(String(n), 6);
const coder = ethers.AbiCoder.defaultAbiCoder();
const tradeData = (a, b, amt, min) => coder.encode(["address", "address", "uint256", "uint256"], [a, b, amt, min]);

/** Small deterministic PRNG (mulberry32). */
function rng(seed) {
  let a = seed >>> 0;
  const next = () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
  return { next, int: (n) => Math.floor(next() * n), pick: (arr) => arr[Math.floor(next() * arr.length)] };
}

async function setup(open) {
  const [, treasury, ...people] = await ethers.getSigners();
  const Token = await ethers.getContractFactory("MockToken");
  const usdg = await Token.deploy("Global Dollar", "USDG", 6);
  const nvda = await Token.deploy("NVDA", "NVDA", 18);
  const oracle = await (await ethers.getContractFactory("MockOracle")).deploy();
  await oracle.setPrice(nvda, USD(200));
  const adapter = await (await ethers.getContractFactory("MockSwapAdapter")).deploy(oracle, usdg);
  const registry = await (await ethers.getContractFactory("RheilonRegistry")).deploy(usdg, oracle, adapter, treasury, 20, 20, 0, [await nvda.getAddress()]);
  const factory = await (await ethers.getContractFactory("RheilonFactory")).deploy(registry);
  const founders = people.slice(0, 3);
  const others = people.slice(3, 12);
  const args = ["Fuzz", [founders[1], founders[2]], open ? 1 : 0, open, 6, 0];
  const a = await factory.connect(founders[0]).createAccount.staticCall(...args);
  await factory.connect(founders[0]).createAccount(...args);
  const acct = await ethers.getContractAt("RheilonAccount", a);
  for (const s of [...founders, ...others]) {
    await usdg.mint(s, USD(1_000_000));
    await usdg.connect(s).approve(acct, ethers.MaxUint256);
  }
  return { treasury, founders, others, usdg, nvda, oracle, acct };
}

/** Value of each member's claim in USDG units, at oracle prices. */
async function claims(c) {
  const members = await c.acct.members();
  const total = await c.acct.totalShares();
  const value = await c.acct.accountValue();
  const out = new Map();
  for (const m of members) out.set(m, total === 0n ? 0n : ((await c.acct.sharesOf(m)) * value) / total);
  return out;
}

async function checkInvariants(c, seats) {
  const members = await c.acct.members();
  // 1. membership list is consistent, unique and within the seat limit
  expect(new Set(members).size).to.equal(members.length);
  expect(members.length).to.be.at.most(seats);
  for (const m of members) expect(await c.acct.isMember(m)).to.equal(true);
  // 2. shares add up exactly; people outside the crew hold none
  let sum = 0n;
  for (const m of members) sum += await c.acct.sharesOf(m);
  expect(sum).to.equal(await c.acct.totalShares());
  for (const o of [...c.founders, ...c.others]) if (!members.includes(o.address)) expect(await c.acct.sharesOf(o)).to.equal(0n);
  // 3. the asset list is unique and matches isHeld
  const assets = await c.acct.assets();
  expect(new Set(assets).size).to.equal(assets.length);
  for (const a of assets) expect(await c.acct.isHeld(a)).to.equal(true);
}

/** Someone else's money moving in or out must never make the others poorer (beyond rounding). */
let lastTotalShares = 0n;
// Below this many shares the 1e6 virtual shares used for pricing stop being negligible: see the "near-empty crew"
// known-risk test. That only happens after every share was withdrawn while the crew kept going.
const NORMAL_SUPPLY = 10n ** 12n;
function expectNoLoss(before, after, except) {
  if (lastTotalShares > 0n && lastTotalShares < NORMAL_SUPPLY) return;
  for (const [m, v] of before) {
    if (m === except || !after.has(m)) continue;
    const tolerance = 5n + v / 1_000_000n; // a few base units of rounding
    expect(after.get(m) + tolerance >= v, `member ${m} lost value: ${v} -> ${after.get(m)} (totalShares before: ${lastTotalShares})`).to.equal(true);
  }
}

// Exits respect the hold on new shares: wait until this member's latest deposit is free.
async function freeUp(c, m) {
  const until = await c.acct.heldUntil(m);
  if (until > BigInt(await time.latest())) await time.increaseTo(until);
}

async function run(seed, open, steps) {
  const r = rng(seed);
  const c = await setup(open);
  const seats = 6;
  const usdgA = await c.usdg.getAddress();
  const nvdaA = await c.nvda.getAddress();
  const fees = { trade: 0n, join: 0n };
  for (const f of c.founders) await c.acct.connect(f).deposit(USD(100 + r.int(5000)));

  for (let step = 0; step < steps; step++) {
    const members = await c.acct.members();
    const signerOf = (addr) => [...c.founders, ...c.others].find((s) => s.address === addr);
    const action = r.int(10);
    const t0 = await c.usdg.balanceOf(c.treasury);
    const tN0 = await c.nvda.balanceOf(c.treasury);
    const before = await claims(c);
    lastTotalShares = await c.acct.totalShares();

    if (action <= 1 && members.length) {
      // deposit
      const m = signerOf(r.pick(members));
      await c.acct.connect(m).deposit(USD(1 + r.int(3000)));
      expectNoLoss(before, await claims(c), m.address);
    } else if (action === 2 && open && members.length < seats) {
      // a stranger joins and pays at most 0.20%
      const outsiders = c.others.filter((o) => !members.includes(o.address));
      if (outsiders.length) {
        const o = r.pick(outsiders);
        const amt = USD(1 + r.int(3000));
        await c.acct.connect(o).join(amt, await c.acct.readyHash());
        const fee = (await c.usdg.balanceOf(c.treasury)) - t0;
        expect(fee).to.be.at.most((amt * 20n) / 10000n);
        fees.join += fee;
        expectNoLoss(before, await claims(c), o.address);
      }
    } else if (action === 3 && members.length) {
      // partial withdraw
      const m = signerOf(r.pick(members));
      const s = await c.acct.sharesOf(m);
      if (s > 0n) {
        const part = (s * BigInt(1 + r.int(100))) / 100n;
        await freeUp(c, m);
        if (part > 0n) await c.acct.connect(m).withdraw(part);
        expectNoLoss(before, await claims(c), m.address);
      }
    } else if (action === 4 && members.length > 1) {
      // leave
      const m = signerOf(r.pick(members));
      await freeUp(c, m);
      await c.acct.connect(m).leave();
      expect(await c.acct.isMember(m)).to.equal(false);
      expectNoLoss(before, await claims(c), m.address);
    } else if (action <= 7 && members.length) {
      // a trade: pitch, sign by a random subset, wait, execute; may fail cleanly
      const voters = [];
      for (const m of members) if (await c.acct.canVote(m)) voters.push(signerOf(m));
      if (voters.length) {
        const buy = r.next() < 0.6;
        const held = await c.nvda.balanceOf(c.acct);
        const cash = await c.usdg.balanceOf(c.acct);
        const amt = buy ? (cash * BigInt(1 + r.int(60))) / 100n : (held * BigInt(1 + r.int(100))) / 100n;
        if (amt > 0n && (buy || held > 0n)) {
          const id = await c.acct.proposalCount();
          await c.acct.connect(voters[0]).propose(0, tradeData(buy ? usdgA : nvdaA, buy ? nvdaA : usdgA, amt, 0), "");
          for (const v of voters.slice(1)) if (r.next() < 0.7) await c.acct.connect(v).approve(id);
          await time.increase(13 * 3600);
          await c.acct.poke(id).catch(() => {});
          await time.increase(13 * 3600);
          // readiness from before a newcomer gained their vote doesn't count: re-check it (poke) and wait it out again
          for (let k = 0; k < 4; k++) {
            const p = await c.acct.getProposal(id);
            if (p.readyAt !== 0n && p.readyAt < (await c.acct.latestVoteStart())) await c.acct.poke(id).catch(() => {});
            const ready = (await c.acct.getProposal(id)).readyAt;
            if (ready === 0n) break;
            const at = ready + (await c.acct.coolOff());
            if (at <= BigInt(await time.latest()) && ready >= (await c.acct.latestVoteStart())) break;
            if (at > BigInt(await time.latest())) await time.increaseTo(at);
          }
          const [yes, needed] = await c.acct.tally(id);
          const fresh = (await c.acct.getProposal(id)).readyAt;
          if (yes >= needed && (fresh === 0n || fresh < (await c.acct.latestVoteStart()))) {
            // passes now but its readiness is stale or missing: it waits for a fresh cool-off, it doesn't run
            await expect(c.acct.connect(voters[0]).execute(id)).to.be.revertedWithCustomError(c.acct, "CoolOffRunning");
          } else if (yes >= needed) {
            await c.acct.connect(voters[0]).execute(id);
            // the fee is never more than 0.20% of what was traded
            const feeU = (await c.usdg.balanceOf(c.treasury)) - t0;
            const feeN = (await c.nvda.balanceOf(c.treasury)) - tN0;
            const tradedValue = buy ? amt : await c.oracle.valueInBase(nvdaA, amt);
            const feeValue = feeU + (feeN > 0n ? await c.oracle.valueInBase(nvdaA, feeN) : 0n);
            expect(feeValue).to.be.at.most((tradedValue * 20n) / 10000n + 1n);
            fees.trade += feeValue;
          } else {
            await expect(c.acct.connect(voters[0]).execute(id)).to.be.revertedWithCustomError(c.acct, "ThresholdNotMet");
          }
        }
      }
    } else if (action === 8) {
      // the price moves up to 15% either way
      const p = await c.oracle.price(nvdaA);
      const factor = 85n + BigInt(r.int(31));
      await c.oracle.setPrice(nvdaA, (p * factor) / 100n || 1n);
    } else {
      // someone sends tokens straight to the account: a gift to the members, never a way in
      const giver = r.pick(c.others);
      await c.usdg.connect(giver).transfer(c.acct, USD(1 + r.int(50)));
      expectNoLoss(before, await claims(c), null);
    }
    await checkInvariants(c, seats);
  }

  // 6. everyone can always get out, and the account empties (only rounding dust stays)
  for (const m of await c.acct.members()) {
    const s = [...c.founders, ...c.others].find((x) => x.address === m);
    const claim = (await claims(c)).get(m);
    const u0 = await c.usdg.balanceOf(s);
    const n0 = await c.nvda.balanceOf(s);
    await freeUp(c, s);
    await c.acct.connect(s).leave();
    const got = (await c.usdg.balanceOf(s)) - u0 + (await c.oracle.valueInBase(nvdaA, (await c.nvda.balanceOf(s)) - n0));
    expect(got <= claim + 5n, "nobody leaves with more than their share").to.equal(true);
  }
  expect(await c.acct.totalShares()).to.equal(0n);
  expect(await c.usdg.balanceOf(c.acct)).to.be.at.most(20n);
  return fees;
}

describe("Fuzz: random crews keep their promises", function () {
  this.timeout(0);
  const STEPS = Number(process.env.FUZZ_STEPS || 60);
  for (const seed of [1, 2, 3, 4, 5, 6, 7, 8]) {
    it(`private crew, seed ${seed}`, async () => {
      await run(seed, false, STEPS);
    });
    it(`open crew, seed ${seed}`, async () => {
      await run(1000 + seed, true, STEPS);
    });
  }
});

describe("Known risk: a crew whose shares were all withdrawn", () => {
  // Pricing adds 1e6 virtual shares. With a normal supply (~1e14 and up) that's nothing; if every share was
  // withdrawn while gifts or dust stayed behind, the next supply can be tiny and later entrants get more than fair.
  it("measures what the next person in gets on top of their fair share", async () => {
    const c = await setup(true);
    const [ana, ben] = c.founders;
    for (const f of c.founders) await c.acct.connect(f).deposit(USD(1000));
    await time.increase(3601);
  for (const f of c.founders) await c.acct.connect(f).withdraw(await c.acct.sharesOf(f)); // everyone takes everything out
    expect(await c.acct.totalShares()).to.equal(0n);
    await c.usdg.connect(c.others[0]).transfer(c.acct, USD(500)); // something is left behind (a gift, here)
    await c.acct.connect(ana).deposit(USD(1)); // ana comes back first: tiny supply, owns the 500 left behind
    const anaBefore = (await claims(c)).get(ana.address);
    await c.acct.connect(ben).deposit(USD(1000));
    const after = await claims(c);
    console.log(`      supply after ana: tiny; ana's claim ${ethers.formatUnits(anaBefore, 6)} -> ${ethers.formatUnits(after.get(ana.address), 6)}, ben put in 1000 and holds ${ethers.formatUnits(after.get(ben.address), 6)}`);
    expect(after.get(ana.address) < anaBefore).to.equal(true);
  });
});

describe("Known risk: deposits priced at a stale oracle", () => {
  // When the Chainlink price lags the market, a member can add USDG at the old price and take stock out at once.
  it("measures what a member could take from the others", async () => {
    const c = await setup(true);
    const [ana, ben, cai] = c.founders;
    const usdgA = await c.usdg.getAddress();
    const nvdaA = await c.nvda.getAddress();
    for (const f of c.founders) await c.acct.connect(f).deposit(USD(5000));
    // the crew puts most of its 15,000 into NVDA at 200
    const id = await c.acct.proposalCount();
    await c.acct.connect(ana).propose(0, tradeData(usdgA, nvdaA, USD(12000), 0), "");
    await c.acct.connect(ben).approve(id);
    await c.acct.connect(cai).approve(id);
    await c.acct.connect(ana).execute(id);

    // the market jumps 5% while the oracle still says 200
    const before = await claims(c);
    const u0 = await c.usdg.balanceOf(cai);
    await c.acct.connect(cai).deposit(USD(10000));
    await freeUp(c, cai);
    await c.acct.connect(cai).withdraw(await c.acct.sharesOf(cai));
    const usdgBack = (await c.usdg.balanceOf(cai)) - u0 + USD(5000); // cai's own 5000 came out too
    const nvdaOut = await c.nvda.balanceOf(cai);
    // valued at the real market price (oracle * 1.05)
    const atMarket = (v) => (v * 105n) / 100n;
    const nvdaValue = atMarket(await c.oracle.valueInBase(nvdaA, nvdaOut));
    const fair = atMarket(before.get(cai.address) - USD(3000)) + USD(3000); // cai's fair share at market prices
    const extra = usdgBack + nvdaValue - USD(5000) - fair;
    console.log(`      cai's fair share at market: ${ethers.formatUnits(fair, 6)} USDG, took out ${ethers.formatUnits(usdgBack + nvdaValue - USD(5000), 6)}: extra ${ethers.formatUnits(extra, 6)}`);
    expect(extra > 0n).to.equal(true); // the risk is real
  });
});
