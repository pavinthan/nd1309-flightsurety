var FlightSuretyApp = artifacts.require("FlightSuretyApp");
var FlightSuretyData = artifacts.require("FlightSuretyData");
var BigNumber = require("bignumber.js");

var Config = async function (accounts) {
	// These test addresses are useful when you need to add
	// multiple users in test scripts
	let testAddresses = [
		"0x27D8D15CbC94527cAdf5eC14B69519aE23288B95",
		"0x018C2daBef4904ECbd7118350A0c54DbeaE3549A",
		"0xCe5144391B4aB80668965F2Cc4f2CC102380Ef0A",
		"0x460c31107DD048e34971E57DA2F99f659Add4f02",
		"0xD37b7B8C62BE2fdDe8dAa9816483AeBDBd356088",
		"0x27f184bdc0E7A931b507ddD689D76Dba10514BCb",
		"0xFe0df793060c49Edca5AC9C104dD8e3375349978",
		"0xBd58a85C96cc6727859d853086fE8560BC137632",
		"0xe07b5Ee5f738B2F87f88B99Aac9c64ff1e0c7917",
	];

	let owner = accounts[0];
	let firstAirline = accounts[1];

	let flightSuretyData = await FlightSuretyData.new();

	let flightSuretyApp = await FlightSuretyApp.new(flightSuretyData.address);

	return {
		owner: owner,
		firstAirline: firstAirline,
		weiMultiple: new BigNumber(10).pow(18),
		testAddresses: testAddresses,
		flightSuretyData: flightSuretyData,
		flightSuretyApp: flightSuretyApp,
	};
};

module.exports = {
	Config: Config,
};
