var Test = require("../config/testConfig.js");

contract("Flight Surety Tests", async (accounts) => {
	const TEN_ETHER = web3.utils.toWei("10", "ether");
	const ONE_ETHER = web3.utils.toWei("1", "ether");

	const AIRLINE_2 = accounts[2];
	const AIRLINE_3 = accounts[3];
	const AIRLINE_4 = accounts[4];
	const AIRLINE_5 = accounts[5];
	const AIRLINE_6 = accounts[6];

	const PASSENGER_1 = accounts[7];
	const PASSENGER_2 = accounts[8];

	var config;
	before("setup contract", async () => {
		config = await Test.Config(accounts);
		await config.flightSuretyData.authorizeContract(
			config.flightSuretyApp.address
		);
	});

	it(`(multiparty) has correct initial isOperational() value`, async function () {
		let status = await config.flightSuretyData.isOperational.call();
		assert.equal(status, true, "Incorrect initial operating status value");
	});

	it(`(multiparty) can block access to setOperatingStatus() for non-Contract Owner account`, async function () {
		let accessDenied = false;
		try {
			await config.flightSuretyData.setOperatingStatus(false, {
				from: config.testAddresses[2],
			});
		} catch (e) {
			accessDenied = true;
		}
		assert.equal(accessDenied, true, "Access not restricted to Contract Owner");
	});

	it(`(multiparty) can allow access to setOperatingStatus() for Contract Owner account`, async function () {
		let accessDenied = false;
		try {
			await config.flightSuretyData.setOperatingStatus(false);
		} catch (e) {
			accessDenied = true;
		}
		assert.equal(
			accessDenied,
			false,
			"Access not restricted to Contract Owner"
		);
	});

	it(`(multiparty) can block access to functions using requireIsOperational when operating status is false`, async function () {
		await config.flightSuretyData.setOperatingStatus(false);

		let reverted = false;
		try {
			await config.flightSurety.setTestingMode(true);
		} catch (e) {
			reverted = true;
		}
		assert.equal(reverted, true, "Access not blocked for requireIsOperational");

		await config.flightSuretyData.setOperatingStatus(true);
	});

	it("(airline) can register Airline its not approved", async () => {
		await config.flightSuretyApp.registerAirline(AIRLINE_2, "AIRLINE_2", {
			from: config.firstAirline,
		});

		let isRegisteredAirline =
			await config.flightSuretyData.isRegisteredAirline.call(AIRLINE_2);

		let isApprovedAirline =
			await config.flightSuretyData.isApprovedAirline.call(AIRLINE_2);

		assert.equal(
			isRegisteredAirline,
			true,
			"Airline should be able to register"
		);
		assert.equal(
			isApprovedAirline,
			false,
			"Airline should not be able to register an approved airline"
		);
	});

	it("(airline) can register an approved Airline", async () => {
		await config.flightSuretyApp.fundAirline({
			from: AIRLINE_2,
			value: TEN_ETHER,
		});

		const result = await config.flightSuretyData.isApprovedAirline.call(
			AIRLINE_2
		);

		assert.equal(
			result,
			true,
			"Airline should be able to register another airline"
		);
	});

	it("(multi-party) consensus is required to approve an airline", async () => {
		await config.flightSuretyApp.registerAirline(AIRLINE_3, "AIRLINE_3", {
			from: config.firstAirline,
		});
		await config.flightSuretyApp.fundAirline({
			from: AIRLINE_3,
			value: TEN_ETHER,
		});

		await config.flightSuretyApp.registerAirline(AIRLINE_4, "AIRLINE_4", {
			from: config.firstAirline,
		});
		await config.flightSuretyApp.fundAirline({
			from: AIRLINE_4,
			value: TEN_ETHER,
		});

		await config.flightSuretyApp.registerAirline(AIRLINE_5, "AIRLINE_5", {
			from: config.firstAirline,
		});
		await config.flightSuretyApp.fundAirline({
			from: AIRLINE_5,
			value: TEN_ETHER,
		});
		const isApprovedAirline =
			await config.flightSuretyData.isApprovedAirline.call(AIRLINE_5);

		assert.equal(isApprovedAirline, false, "Airline should not be approved.");
	});

	it("Airline cannot vote twice", async () => {
		let success;

		try {
			await config.flightSuretyApp.voteAirline(AIRLINE_5, {
				from: config.firstAirline,
			});
			await config.flightSuretyApp.voteAirline(AIRLINE_5, {
				from: config.firstAirline,
			});
			success = await config.flightSuretyData.isApprovedAirline.call(AIRLINE_5);
		} catch (e) {
			success = false;
		}

		assert.equal(success, false, "Airline should not be able to vote twice");
	});

	it("(multi-party) consensus is required to approve an airline", async () => {
		await config.flightSuretyApp.voteAirline(AIRLINE_5, { from: AIRLINE_2 });

		const isApprovedAirline =
			await config.flightSuretyData.isApprovedAirline.call(AIRLINE_5);
		const getApprovedAirlinesCount =
			await config.flightSuretyData.getApprovedAirlinesCount.call();

		assert.equal(isApprovedAirline, true, "Airline should be approved");
		assert.equal(
			getApprovedAirlinesCount,
			5,
			"There should be 5 approved airlines."
		);
	});

	it("(multi-party) consensus - 1 airline from 5 is not enough to approve", async () => {
		await config.flightSuretyApp.registerAirline(AIRLINE_6, "AIRLINE_6", {
			from: config.firstAirline,
		});
		await config.flightSuretyApp.fundAirline({
			from: AIRLINE_6,
			value: TEN_ETHER,
		});

		await config.flightSuretyApp.voteAirline(AIRLINE_6, {
			from: config.firstAirline,
		});

		const isApprovedAirline =
			await config.flightSuretyData.isApprovedAirline.call(AIRLINE_6);
		const getApprovedAirlinesCount =
			await config.flightSuretyData.getApprovedAirlinesCount.call();

		assert.equal(isApprovedAirline, false, "Airline should not be approved");
		assert.equal(
			getApprovedAirlinesCount,
			5,
			"There should be 5 approved airlines."
		);
	});

	it("buy insurance for a flight", async () => {
		let flightNo = "A";
		let timestamp = Math.floor(Date.now() / 1000);

		await config.flightSuretyApp.buyInsurance(AIRLINE_2, flightNo, timestamp, {
			from: PASSENGER_1,
			value: ONE_ETHER,
		});

		let insurances = await config.flightSuretyData.getInsurance(
			AIRLINE_2,
			flightNo,
			timestamp,
			PASSENGER_1
		);

		assert.equal(insurances?.value, ONE_ETHER, "Premium does not match");
	});

	it("test credit all insurees for delayed flight", async () => {
		let flightNo = "C";
		let timestamp = Math.floor(Date.now() / 1000);

		await config.flightSuretyApp.buyInsurance(AIRLINE_2, flightNo, timestamp, {
			from: PASSENGER_2,
			value: ONE_ETHER,
		});
		await config.flightSuretyData.authorizeContract(accounts[0]);
		await config.flightSuretyData.creditInsurees(
			AIRLINE_2,
			flightNo,
			timestamp
		);

		let payout = await config.flightSuretyData.isPayoutAvailable(PASSENGER_2);

		assert.equal(payout, true, "Insurance not credited");
	});

	it("test passenger withdraws insurance", async () => {
		let flightNo = "D";
		let timestamp = Math.floor(Date.now() / 1000);
		let airline = AIRLINE_2;
		let pax = PASSENGER_2;

		await config.flightSuretyApp.buyInsurance(airline, flightNo, timestamp, {
			from: pax,
			value: ONE_ETHER,
		});
		await config.flightSuretyData.authorizeContract(accounts[0]);
		await config.flightSuretyData.creditInsurees(airline, flightNo, timestamp);

		let payout = await config.flightSuretyData.isPayoutAvailable(pax);
		assert.equal(payout, true, "No payout available");

		await config.flightSuretyApp.withdrawPayout({ from: pax });

		payout = await config.flightSuretyData.isPayoutAvailable(pax);

		assert.equal(payout, false, "Withdrawal failed");
	});
});
