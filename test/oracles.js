var Test = require("../config/testConfig.js");
//var BigNumber = require('bignumber.js');

contract("Oracles", async (accounts) => {
	const TEST_ORACLES_COUNT = 40;
	// Watch contract events
	const STATUS_CODE_UNKNOWN = 0;
	const STATUS_CODE_ON_TIME = 10;
	const STATUS_CODE_LATE_AIRLINE = 20;
	const STATUS_CODE_LATE_WEATHER = 30;
	const STATUS_CODE_LATE_TECHNICAL = 40;
	const STATUS_CODE_LATE_OTHER = 50;

	var config;
	before("setup contract", async () => {
		config = await Test.Config(accounts);

		config.flightSuretyApp.contract.events
			.allEvents(
				{
					fromBlock: 0,
				},
				function (error, result) {
					if (error) {
						console.log(error);
					}
				}
			)
			.on("connected", function (subscriptionId) {
				console.log("connected: ", subscriptionId);
			})
			.on("data", function (result) {
				if (result.event === "OracleRequest") {
					console.log(
						`\nOracle Requested: index: ${result.returnValues.index}, flight:  ${result.returnValues.flight}, timestamp: ${result.returnValues.timestamp}`
					);
				} else if (result.event == "FlightStatusInfo") {
					console.log(
						`\nFlight Status Available: flight: ${
							result.returnValues.flight
						}, timestamp: ${result.returnValues.timestamp}, status: ${
							result.returnValues.status == STATUS_CODE_ON_TIME
								? "ON TIME"
								: "DELAYED"
						}`
					);
				} else if (result.event == "OracleReport") {
					console.log(
						`\nOracle Report: flight: ${
							result.returnValues.flight
						}, timestamp: ${result.returnValues.timestamp}, status: ${
							result.returnValues.status == STATUS_CODE_ON_TIME
								? "ON TIME"
								: "DELAYED"
						}, verified: ${
							result.returnValues.verified ? "VERIFIED" : "UNVERIFIED"
						}`
					);
				} else {
					console.log("unknown event ", result);
				}
			})
			.on("changed", function (result) {
				// remove event from local database
			})
			.on("error", function (error, receipt) {
				// If the transaction was rejected by the network with a receipt, the second parameter will be the receipt.
				console.log("error: ", error);
			});
	});

	const enableRegister = true;

	it("can register oracles", async () => {
		if (enableRegister) {
			// ARRANGE
			let fee = await config.flightSuretyApp.REGISTRATION_FEE.call();

			// ACT
			for (let a = 1; a < TEST_ORACLES_COUNT; a++) {
				try {
					if (typeof accounts[a] != "undefined") {
						await config.flightSuretyApp.registerOracle({
							from: accounts[a],
							value: fee,
						});
						console.log(`Oracle Registered: ${a} , ${accounts[a]}`);
					}
				} catch (e) {
					console.error(e);
				}
			}
		}
	});

	it("can request flight status", async () => {
		let flight = "ND1309"; // Course number
		let timestamp = Math.floor(Date.now() / 1000);

		await config.flightSuretyApp.fetchFlightStatus(
			config.firstAirline,
			flight,
			timestamp
		);

		for (let a = 1; a < TEST_ORACLES_COUNT; a++) {
			if (typeof accounts[a] != "undefined") {
				// Get oracle information
				let oracleIndexes = await config.flightSuretyApp.getMyIndexes.call({
					from: accounts[a],
				});
				for (let idx = 0; idx < 3; idx++) {
					try {
						// Submit a response...it will only be accepted if there is an Index match
						await config.flightSuretyApp.submitOracleResponse(
							oracleIndexes[idx],
							config.firstAirline,
							flight,
							timestamp,
							STATUS_CODE_ON_TIME,
							{ from: accounts[a] }
						);
					} catch (e) {
						console.log("\nError", e.message);
						console.log(
							"\nError",
							idx,
							oracleIndexes[idx].toNumber(),
							flight,
							timestamp
						);
					}
				}
			}
		}
	});
});
