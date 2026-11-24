// Checks that the code running on Robinhood Chain is this repository's code.
//
// For each deployed contract (and every crew the factory has created) it compares the runtime bytecode on chain
// with the bytecode compiled here, ignoring only two things that can't match by design:
//   - immutables: values baked in at deployment (addresses, fees); their positions come from the compiler output
//   - metadata hashes, which depend on file paths and line endings, not on the code
// Run: npm run check    (or RH_RPC=<your rpc> npm run check)
const hre = require("hardhat");
const deployed = require("../deployments/robinhood-mainnet.json").deployed;

const CONTRACTS = [
  ["RheilonLaunch", "contracts/RheilonLaunch.sol:RheilonLaunch", deployed.launch],
  ["RheilonFactory", "contracts/RheilonFactory.sol:RheilonFactory", deployed.factory],
  ["RheilonRegistry", "contracts/RheilonRegistry.sol:RheilonRegistry", deployed.registry],
  ["ChainlinkOracle", "contracts/oracles/ChainlinkOracle.sol:ChainlinkOracle", deployed.oracle],
  ["UniswapV3Adapter", "contracts/adapters/UniswapV3Adapter.sol:UniswapV3Adapter", deployed.adapter],
];
const ACCOUNT = "contracts/RheilonAccount.sol:RheilonAccount";

const strip = (hex) => hex.replace(/^0x/, "").toLowerCase();
/**
 * Blanks every metadata block: {"ipfs": <34-byte hash>, "solc": <version>} in CBOR, ending in its 2-byte length.
 * There is one at the end of each contract, and the factory carries a second one inside the crew code it deploys.
 */
const METADATA = /a264697066735822[0-9a-f]{68}64736f6c6343[0-9a-f]{6}0033/g;
const withoutMetadata = (code) => code.replace(METADATA, (m) => "0".repeat(m.length));
function maskImmutables(code, refs) {
  const bytes = code.split("");
  for (const list of Object.values(refs || {}))
    for (const { start, length } of list) for (let i = start * 2; i < (start + length) * 2; i++) bytes[i] = "0";
  return bytes.join("");
}

async function expected(fqn) {
  const art = await hre.artifacts.readArtifact(fqn);
  const info = await hre.artifacts.getBuildInfo(fqn);
  const [file, name] = fqn.split(":");
  const refs = info.output.contracts[file][name].evm.deployedBytecode.immutableReferences;
  return { code: strip(art.deployedBytecode), refs };
}

async function same(label, fqn, address) {
  const want = await expected(fqn);
  const got = strip(await hre.ethers.provider.getCode(address));
  if (!got) return console.log(`  ✗ ${label} ${address}: no code at this address`), false;
  const a = withoutMetadata(maskImmutables(got, want.refs));
  const b = withoutMetadata(maskImmutables(want.code, want.refs));
  const ok = a === b;
  console.log(`  ${ok ? "✓" : "✗"} ${label} ${address}${ok ? "" : ": bytecode differs"}`);
  return ok;
}

async function main() {
  await hre.run("compile", { quiet: true });
  const net = await hre.ethers.provider.getNetwork();
  console.log(`Chain ${net.chainId}: comparing deployed code with this repository\n`);
  let ok = true;
  for (const [label, fqn, address] of CONTRACTS) ok = (await same(label, fqn, address)) && ok;

  const factory = await hre.ethers.getContractAt("RheilonFactory", deployed.factory);
  const n = Number(await factory.accountCount());
  console.log(`\n  crews created by the factory: ${n}`);
  for (let i = 0; i < n; i++) {
    const a = await factory.allAccounts(i);
    const crew = await hre.ethers.getContractAt("RheilonAccount", a);
    ok = (await same(`RheilonAccount "${await crew.name()}"`, ACCOUNT, a)) && ok;
  }

  const launch = await hre.ethers.getContractAt("RheilonLaunch", deployed.launch);
  for (const [fn, want] of [["factory", deployed.factory], ["registry", deployed.registry], ["oracle", deployed.oracle], ["adapter", deployed.adapter]]) {
    const got = await launch[fn]();
    const match = got.toLowerCase() === want.toLowerCase();
    ok = match && ok;
    console.log(`  ${match ? "✓" : "✗"} RheilonLaunch.${fn}() = ${got}`);
  }
  console.log(ok ? "\nAll deployed code matches this repository." : "\nMismatch found.");
  if (!ok) process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
