import FlightSuretyApp from "../../build/contracts/FlightSuretyApp.json";
import Config from "./config.json";
import Web3 from "web3";
import BigNumber from "bignumber.js";

export default class Contract {
	constructor(network, callback) {
		let config = Config[network];
		this.web3 = new Web3(new Web3.providers.HttpProvider(config.url));
		this.web3 = new Web3(
			new Web3.providers.WebsocketProvider(config.url.replace("http", "ws"))
		);
		this.flightSuretyApp = new this.web3.eth.Contract(
			FlightSuretyApp.abi,
			config.appAddress
		);
		this.flightSuretyApp.options.gas = 200000;
		this.owner = null;
		this.airlines = [];
		this.passengers = [];
		this.initialize(callback);
	}

	initialize(callback) {
		this.web3.eth.getAccounts((error, accts) => {
			this.owner = accts[0];

			let counter = 1;

			while (this.airlines.length < 5) {
				this.airlines.push(accts[counter++]);
			}

			while (this.passengers.length < 5) {
				this.passengers.push(accts[counter++]);
			}

			console.log(this.airlines);
			console.log(this.passengers);
			callback();
		});
	}

	isOperational(callback) {
		let self = this;
		self.flightSuretyApp.methods
			.isOperational()
			.call({ from: self.owner }, callback);
	}

	fetchFlightStatus(flight, callback) {
		let self = this;
		let payload = {
			airline: self.airlines[0],
			flight: flight,
			timestamp: Math.floor(Date.now() / 1000),
			status: "",
		};
		self.flightSuretyApp.methods
			.fetchFlightStatus(payload.airline, payload.flight, payload.timestamp)
			.send({ from: self.owner })
			.then((value) => {
				callback("", payload);
			})
			.catch((err) => {
				callback(err, "failed");
			});
	}

	buyInsurance(flight, amount, callback) {
		let self = this;

		self.flightSuretyApp.methods
			.buyInsurance(
				self.airlines[0],
				flight.flight,
				new BigNumber(
					Math.floor(new Date(flight.timestamp).getTime() / 1000).toString()
				)
			)
			.send({
				from: self.passengers[0],
				value: self.web3.utils.toWei(amount, "ether"),
				gas: 450000,
			})
			.then((value) => {
				callback("", "success");
			})
			.catch((err) => {
				callback(err, "failed");
			});
	}
}
