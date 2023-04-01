var fs = require("fs");
var HDWalletProvider = require("truffle-hdwallet-provider");

const mnemonic = fs.readFileSync(".secret").toString().trim();
const infuraKey = fs.readFileSync(".infura").toString().trim();

module.exports = {
	networks: {
		development: {
			network_id: "*",
			gas: 9999999,
			provider: function () {
				return new HDWalletProvider(mnemonic, "http://127.0.0.1:8545/", 0, 50);
			},
		},
		georli: {
			provider: () =>
				new HDWalletProvider(
					mnemonic,
					`https://goerli.infura.io/v3/${infuraKey}`
				),
			network_id: 5, // georli's id
			gas: 5500000, // georli has a lower block limit than mainnet
			confirmations: 2, // # of confs to wait between deployments. (default: 0)
			timeoutBlocks: 200, // # of blocks before a deployment times out  (minimum/default: 50)
			skipDryRun: true, // Skip dry run before migrations? (default: false for public nets )
		},
	},
	compilers: {
		solc: {
			version: "^0.8.16",
		},
	},
};
