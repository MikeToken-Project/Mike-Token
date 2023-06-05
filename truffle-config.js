const HDWalletProvider = require('@truffle/hdwallet-provider');
const fs = require('fs');

const privateKeyTestnet = fs.readFileSync(".private_key.testnet").toString().trim();
const privateKeyRinkebyTestnet = fs.readFileSync(".private_key.testnet").toString().trim();
const privateKeyMainnet = fs.readFileSync(".private_key.mainnet").toString().trim();
const { BSCSCANAPIKEY } = require('./evn.json');

module.exports = {
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    bscscan: BSCSCANAPIKEY
  },
  networks: {
    testnet: {
      provider: () => new HDWalletProvider(privateKeyTestnet, `https://data-seed-prebsc-1-s2.binance.org:8545`),
      network_id: 97,
      timeoutBlocks: 200,
      skipDryRun: true,
      gasPrice: 10000000000,
      gas: 9000000
    },
    bsc: {
      provider: () => new HDWalletProvider(privateKeyMainnet, `https://bsc-dataseed.binance.org/`),
      network_id: 56,
      timeoutBlocks: 200,
      skipDryRun: true,
      gasPrice: 20000000000
    },
    ganache: {
      provider: () => new HDWalletProvider(privateKeyTestnet, `http://localhost:7545/`),
      network_id: 5777,
      timeoutBlocks: 200,
      skipDryRun: true,
      gasPrice: 20000000000
    },
  },
  mocha: {},
  compilers: {
    solc: {
      version: "0.8.3",    // Fetch exact version from solc-bin (default: truffle's version)
      docker: false,        // Use "0.5.1" you've installed locally with docker (default: false)
      settings: {
        evmVersion: 'byzantium', // Default: "petersburg"
        optimizer: {
          enabled: true,
          runs: 2000
        }
      }
    },
  },
  db: {
    enabled: false
  }
};