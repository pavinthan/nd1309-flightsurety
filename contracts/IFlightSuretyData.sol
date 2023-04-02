// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IFlightSuretyData {
    function authorizeContract(address contractAddress) external;

    function registerAirline(address airlineAddress) external;

    function isOperational() external view returns (bool operational);

    function isAirline(address airlineAddress) external view returns (bool);

    function isAirlineAuthorized() external view returns (bool);

    function getAirlinesAmount() external view returns (uint);

    function buy(
        address userAddress,
        address airlineAddress,
        string memory flight,
        uint256 timestamp
    ) external payable;

    function setCreditInsuree(
        address userAddress,
        uint256 creditInsurees,
        address airlineAddress,
        string memory flight,
        uint256 timestamp
    ) external;

    function pay(
        address userAddress,
        address airlineAddress,
        string memory flight,
        uint256 timestamp
    ) external payable;

    function fund(address airlineAddress) external payable;

    function getInsurancePaymentAmount(
        address userAddress,
        address airlineAddress,
        string memory flight,
        uint256 timestamp
    ) external returns (uint256);
}
