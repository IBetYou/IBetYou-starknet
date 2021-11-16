import "/Users/princeraj/Projects/github.com/Shard-Labs/starknet-hardhat-plugin/dist/index.js";

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  cairo: {
    version: "0.5.1"
  },
  networks: {
    starknetLocalhost: {
      url: "http://localhost:5000/"
    }
  },
  mocha: {
    starknetNetwork: "starknetLocalhost"
    // starknetNetwork: "alpha"
  }
};