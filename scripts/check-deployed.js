// Checks that the code running on Robinhood Chain is this repository's code.
//
// For each deployed contract (and every crew a factory has created) it compares the runtime bytecode on chain with
// the bytecode compiled here, ignoring only two things that can't match by design:
//   - immutables: values baked in at deployment (addresses, fees); their positions come from the compiler output
//   - metadata hashes, which depend on file paths and line endings, not on the code
//
// v2 (the factory, its account deployer and v2 crews) is compared with `contracts/`. v1 (RheilonLaunch, the v1
// factory and v1 crews) is compared with `verification/RheilonLaunch.flat.sol`, the source it was deployed and
// verified from, compiled here with the same settings. The registry, oracle and adapter are shared by both versions
// and haven't changed, so they're compared with both.
// Run: npm run check    (or RH_RPC=<your rpc> npm run check)
const fs = require("fs");
const path = require("path");
const hre = require("hardhat");
const { TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD, TASK_COMPILE_SOLIDITY_RUN_SOLC, TASK_COMPILE_SOLIDITY_RUN_SOLCJS } = require("hardhat/builtin-tasks/task-names");
const cfg = require("../deployments/robinhood-mainnet.json");
const v1 = cfg.deployed;
const v2 = cfg.deployedV2;

const strip = (hex) => hex.replace(/^0x/, "").toLowerCase();
/**
 * Blanks every metadata block: {"ipfs": <34-byte hash>, "solc": <version>} in CBOR, ending in its 2-byte length.
 * There is one at the end of each contract, and factories carry a second one inside the crew code they deploy.
 */
const METADATA = /a264697066735822[0-9a-f]{68}64736f6c6343[0-9a-f]{6}0033/g;
const withoutMetadata = (code) => code.replace(METADATA, (m) => "0".repeat(m.length));
function maskImmutables(code, refs) {
  const bytes = code.split("");
  for (const list of Object.values(refs || {}))
    for (const { start, length } of list) for (let i = start * 2; i < (start + length) * 2; i++) bytes[i] = "0";
  return bytes.join("");
}

/** Runtime code and immutable positions of a contract in `contracts/`. */
async function fromRepo(fqn) {
  const art = await hre.artifacts.readArtifact(fqn);
  const info = await hre.artifacts.getBuildInfo(fqn);
  const [file, name] = fqn.split(":");
  return { code: strip(art.deployedBytecode), refs: info.output.contracts[file][name].evm.deployedBytecode.immutableReferences };
}

/** Compiles the v1 flattened source with the settings it was deployed with. */
async function compileV1() {
  const file = "RheilonLaunch.flat.sol";
  const settings = {
    optimizer: { enabled: true, runs: 200 },
    evmVersion: "cancun",
    outputSelection: { "*": { "*": ["evm.deployedBytecode.object", "evm.deployedBytecode.immutableReferences"] } },
  };
  const input = { language: "Solidity", sources: { [file]: { content: fs.readFileSync(path.join(__dirname, "../verification", file), "utf8") } }, settings };
  const build = await hre.run(TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD, { quiet: true, solcVersion: "0.8.24" });
  const out = build.isSolcJs
    ? await hre.run(TASK_COMPILE_SOLIDITY_RUN_SOLCJS, { input, solcJsPath: build.compilerPath })
    : await hre.run(TASK_COMPILE_SOLIDITY_RUN_SOLC, { input, solcPath: build.compilerPath });
  const errors = (out.errors || []).filter((e) => e.severity === "error");
  if (errors.length) throw new Error(errors.map((e) => e.formattedMessage).join("\n"));
  return (name) => {
    const c = out.contracts[file][name].evm.deployedBytecode;
    return { code: strip(c.object), refs: c.immutableReferences };
  };
}

async function same(label, want, address) {
  const got = strip(await hre.ethers.provider.getCode(address));
  if (!got) return console.log(`  ✗ ${label} ${address}: no code at this address`), false;
  const ok = withoutMetadata(maskImmutables(got, want.refs)) === withoutMetadata(maskImmutables(want.code, want.refs));
  console.log(`  ${ok ? "✓" : "✗"} ${label} ${address}${ok ? "" : ": bytecode differs"}`);
  return ok;
}

function line(ok, text) {
  console.log(`  ${ok ? "✓" : "✗"} ${text}`);
  return ok;
}
const eq = (a, b) => a.toLowerCase() === b.toLowerCase();

async function crews(label, factoryAddress, want) {
  const factory = await hre.ethers.getContractAt("RheilonFactory", factoryAddress);
  const n = Number(await factory.accountCount());
  console.log(`\n  ${label} crews: ${n}`);
  let ok = true;
  for (let i = 0; i < n; i++) {
    const a = await factory.allAccounts(i);
    const crew = await hre.ethers.getContractAt("RheilonAccount", a);
    ok = (await same(`RheilonAccount "${await crew.name()}"`, want, a)) && ok;
  }
  return ok;
}

async function main() {
  await hre.run("compile", { quiet: true });
  const net = await hre.ethers.provider.getNetwork();
  console.log(`Chain ${net.chainId}: comparing deployed code with this repository`);
  let ok = true;

  console.log("\nShared by v1 and v2 (contracts/)");
  ok = (await same("RheilonRegistry", await fromRepo("contracts/RheilonRegistry.sol:RheilonRegistry"), v1.registry)) && ok;
  ok = (await same("ChainlinkOracle", await fromRepo("contracts/oracles/ChainlinkOracle.sol:ChainlinkOracle"), v1.oracle)) && ok;
  ok = (await same("UniswapV3Adapter", await fromRepo("contracts/adapters/UniswapV3Adapter.sol:UniswapV3Adapter"), v1.adapter)) && ok;

  console.log("\nv2 (contracts/)");
  ok = (await same("RheilonFactory", await fromRepo("contracts/RheilonFactory.sol:RheilonFactory"), v2.factory)) && ok;
  ok = (await same("RheilonAccountDeployer", await fromRepo("contracts/RheilonAccountDeployer.sol:RheilonAccountDeployer"), v2.accountDeployer)) && ok;
  const f2 = await hre.ethers.getContractAt("RheilonFactory", v2.factory);
  const d2 = await hre.ethers.getContractAt("RheilonAccountDeployer", await f2.deployer());
  ok = line(eq(await f2.registry(), v1.registry), `RheilonFactory.registry() = ${await f2.registry()}`) && ok;
  ok = line(eq(await f2.deployer(), v2.accountDeployer), `RheilonFactory.deployer() = ${await f2.deployer()}`) && ok;
  ok = line(eq(await d2.factory(), v2.factory), `RheilonAccountDeployer.factory() = ${await d2.factory()}`) && ok;
  ok = (await crews("v2", v2.factory, await fromRepo("contracts/RheilonAccount.sol:RheilonAccount"))) && ok;

  console.log("\nv1 (verification/RheilonLaunch.flat.sol)");
  const old = await compileV1();
  ok = (await same("RheilonLaunch", old("RheilonLaunch"), v1.launch)) && ok;
  ok = (await same("RheilonFactory", old("RheilonFactory"), v1.factory)) && ok;
  const launch = await hre.ethers.getContractAt(["function factory() view returns (address)", "function registry() view returns (address)", "function oracle() view returns (address)", "function adapter() view returns (address)"], v1.launch);
  for (const fn of ["factory", "registry", "oracle", "adapter"]) {
    const got = await launch[fn]();
    ok = line(eq(got, v1[fn]), `RheilonLaunch.${fn}() = ${got}`) && ok;
  }
  ok = (await crews("v1", v1.factory, old("RheilonAccount"))) && ok;

  console.log(ok ? "\nAll deployed code matches this repository." : "\nMismatch found.");
  if (!ok) process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
