// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IFlightSuretyData {
    function buy(address passenger, bytes32 flightId) external payable;

    function registerAirline(
        address _airlineAddress,
        string memory _airlineName,
        bool _votingRequired
    ) external;

    function getNumberOfRegisteredAirlines() external view returns (uint256);

    function registerFlight(
        address airlineAddress,
        string memory flightNumber
    ) external;

    function pay(address passenger, bytes32 flightId) external;

    function isOperational() external view returns (bool);

    function fund() external payable;
}
