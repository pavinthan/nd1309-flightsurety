import DOM from "./dom";
import Contract from "./contract";
import "./flightsurety.css";

(async () => {
	const FLIGHTS = [
		{ flight: "UL 301", timestamp: new Date(2023, 2, 1) },
		{ flight: "UL 302", timestamp: new Date(2023, 3, 4) },
		{ flight: "UL 303", timestamp: new Date(2023, 4, 2) },
		{ flight: "SQ 22", timestamp: new Date(2023, 4, 11) },
		{ flight: "SQ 32", timestamp: new Date(2023, 6, 5) },
		{ flight: "SQ 34", timestamp: new Date(2023, 7, 22) },
		{ flight: "SQ 468", timestamp: new Date(2023, 5, 12) },
	];

	let contract = new Contract("localhost", () => {
		// Read transaction
		contract.isOperational((error, result) => {
			console.log(error, result);
			display("Operational Status", "Check if contract is operational", [
				{ label: "Operational Status", error: error, value: result },
			]);
		});

		for (let a = 0; a < FLIGHTS.length; a++) {
			addFlightToDropdown(FLIGHTS[a]);
		}

		contract.flightSuretyApp.events.FlightStatusInfo(
			{
				fromBlock: "latest",
			},
			function (error, result) {
				if (error) {
					console.log(error);
				} else {
					display("Flight Status Info Event", "Flight Status Available", [
						{
							label: "Flight Status",
							error: error,
							value: `flight:  ${result.returnValues.flight}, status: ${
								result.returnValues.status == 10 ? "ON TIME" : "DELAYED"
							}`,
						},
					]);
				}
			}
		);

		contract.flightSuretyApp.events.InsurancePurchased(
			{
				fromBlock: "latest",
			},
			function (error, result) {
				if (error) {
					console.log(error);
				} else {
					display("Insurance Purchased Event", "", [
						{
							label: "Insurance:",
							error: error,
							value: `Passenger: ${result.returnValues.paxAddress} ,Flight: ${result.returnValues.flight}, Amount: ${result.returnValues.amount} ETH`,
						},
					]);
				}
			}
		);

		// User-submitted transaction
		DOM.elid("submit-oracle").addEventListener("click", () => {
			let flight = DOM.elid("flight-number").value;
			contract.fetchFlightStatus(flight, (error, result) => {
				display("Oracles", "Trigger oracles", [
					{
						label: "Fetch Flight Status",
						error: error,
						value: result.flight + " " + result.timestamp,
					},
				]);
			});
		});

		DOM.elid("buyInsurance").addEventListener("click", () => {
			let sel = document.getElementById("select-flight");
			let flight = sel.options[sel.selectedIndex].value;
			let amount = DOM.elid("amount").value;

			DOM.elid("amount").value = "";
			flight = JSON.parse(flight);

			contract.buyInsurance(flight, amount, (error, result) => {
				console.log(error, result, amount);
				if (error || result != "success") {
					alert("Insurance purchase failed, have you entered ETH > 0 and <= 1");
				} else {
					// use event to see this
					//display('Buy Insurance', 'Insurance purchased by the passenger', [ { label: 'Insurance', error: error, value: `Flight: ${flight.flight}, Amount: ${amount} ETH`} ]);
				}
			});
		});
	});
})();

function display(title, description, results) {
	let displayDiv = DOM.elid("display-wrapper");
	let section = DOM.section();
	section.appendChild(DOM.h2(title));
	section.appendChild(DOM.h5(description));
	results.map((result) => {
		let row = section.appendChild(DOM.div({ className: "row" }));
		row.appendChild(DOM.div({ className: "col-sm-4 field" }, result.label));
		row.appendChild(
			DOM.div(
				{ className: "col-sm-8 field-value" },
				result.error ? String(result.error) : String(result.value)
			)
		);
		section.appendChild(row);
	});
	displayDiv.append(section);
}

function addFlightToDropdown(flight) {
	let option = document.createElement("option");

	option.text = `Flight ${flight.flight} departing ${new Date(
		flight.timestamp
	)}`;
	option.value = JSON.stringify(flight);

	DOM.elid("select-flight").add(option);
}
