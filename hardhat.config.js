require("@nomicfoundation/hardhat-chai-matchers");
require("@nomicfoundation/hardhat-ethers");
const { subtask } = require("hardhat/config");
const { TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD } = require("hardhat/builtin-tasks/task-names");

// Compile with the solc-js 0.8.24 package from npm, the same compiler version the contracts were deployed with.
// No compiler download needed.
subtask(TASK_COMPILE_SOLIDITY_GET_SOLC_BUILD, async (args, hre, runSuper) => {
  if (args.solcVersion === "0.8.24") {
    const solc = require("solc");
    return { compilerPath: require.resolve("solc/soljson.js"), isSolcJs: true, version: args.solcVersion, longVersion: solc.version() };
  }
  return runSuper();
});

module.exports = {
  solidity: {
    version: "0.8.24",
    settings: { optimizer: { enabled: true, runs: 200 }, evmVersion: "cancun" },
  },
  networks: {
    // Same chain ID as Robinhood Chain, so the fork tests can run RheilonLaunch.
    hardhat: { chainId: 4663 },
    // Read-only: used by scripts/check-deployed.js. Nothing in this repo sends transactions.
    robinhood: { url: process.env.RH_RPC || "https://rpc.mainnet.chain.robinhood.com", chainId: 4663 },
  },
};
