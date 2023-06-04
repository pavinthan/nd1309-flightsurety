// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract FlightSuretyData {
    using SafeMath for uint256;

    /************************************************************************/
    /*                             DATA VARIABLES                           */
    /************************************************************************/

    struct Insurance {
        uint256 value;
        address passenger;
        string flightNo;
        bool paidOut;
    }

    struct Airline {
        string name;
        uint256 fundedValue;
        bool isApproved;
    }

    // Account used to deploy contract
    address private contractOwner;

    // Contracts allowed to access data
    mapping(address => bool) private authorizedContracts;

    // Mapping passenfer -> how much he receives
    mapping(address => uint256) private payouts;

    // Contracts allowed to access data
    mapping(address => Airline) private registeredAirlines;

    // Contracts allowed to access data
    mapping(address => EnumerableSet.AddressSet) private airlineToVoters;

    // Contracts allowed to access data
    mapping(bytes32 => Insurance[]) private boughtInsurances;

    EnumerableSet.AddressSet private waitingAirlines;
    EnumerableSet.AddressSet private approvedAirlines;

    // Blocks all state changes throughout the contract if false
    bool private operational = true;

    /************************************************************************/
    /*                             EVENT DEFINITIONS                        */
    /************************************************************************/

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor(address airlineAddress, string memory airlineName) {
        contractOwner = msg.sender;

        // add the first airline
        EnumerableSet.add(approvedAirlines, airlineAddress);

        registeredAirlines[airlineAddress] = Airline({
            name: airlineName,
            isApproved: true,
            fundedValue: 10 ether
        });
    }

    /************************************************************************/
    /*                             UTILITY FUNCTIONS                        */
    /************************************************************************/

    /**
     * @dev Get operating status of contract
     *
     * @return A bool that is the current operating status
     */
    function isOperational() public view returns (bool) {
        return operational;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled,
     * all write transactions except for this one will fail
     */
    function setOperatingStatus(bool mode) external requireContractOwner {
        operational = mode;
    }

    function authorizeContract(
        address contractAddress
    ) external requireContractOwner {
        authorizedContracts[contractAddress] = true;
    }

    function deauthorizeContract(
        address contractAddress
    ) external requireContractOwner {
        authorizedContracts[contractAddress] = false;
    }

    function isRegisteredAirline(
        address airlineAddress
    ) external view returns (bool) {
        return
            EnumerableSet.contains(approvedAirlines, airlineAddress) ||
            EnumerableSet.contains(waitingAirlines, airlineAddress);
    }

    function isApprovedAirline(
        address airlineAddress
    ) external view returns (bool) {
        return
            EnumerableSet.contains(approvedAirlines, airlineAddress) &&
            registeredAirlines[airlineAddress].fundedValue >= 10 ether;
    }

    function isUniqueVote(
        address forAirline,
        address fromAirline
    ) external view returns (bool) {
        return
            !EnumerableSet.contains(airlineToVoters[forAirline], fromAirline);
    }

    function getApprovedAirlinesCount() external view returns (uint256) {
        return EnumerableSet.length(approvedAirlines);
    }

    function isPayoutAvailable(address passenger) external view returns (bool) {
        return payouts[passenger] > 0;
    }

    /************************************************************************/
    /*                             FUNCTION MODIFIERS                       */
    /************************************************************************/

    // Modifiers help avoid duplication of code.
    // They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireAuthorizedContact() {
        require(
            authorizedContracts[msg.sender] == true,
            "Caller is not authorized"
        );
        _;
    }

    modifier requireNotInQueueAirline(address airlineAddress) {
        require(
            !EnumerableSet.contains(waitingAirlines, airlineAddress),
            "Airline is not queueing for registratio"
        );
        _;
    }

    modifier requireInQueueAirline(address airlineAddress) {
        require(
            EnumerableSet.contains(waitingAirlines, airlineAddress),
            "Airline is already waiting for registration"
        );
        _;
    }

    modifier requireApprovedAirline(address airlineAddress) {
        require(
            EnumerableSet.contains(approvedAirlines, airlineAddress) &&
                registeredAirlines[airlineAddress].fundedValue >= 10 ether,
            "Airline was not approved"
        );
        _;
    }

    modifier requireNotApprovedAirline(address airlineAddress) {
        require(
            !(EnumerableSet.contains(approvedAirlines, airlineAddress) &&
                registeredAirlines[airlineAddress].fundedValue >= 10 ether),
            "Airline was approved"
        );
        _;
    }

    modifier requireRegisteredAirline(address airlineAddress) {
        require(
            EnumerableSet.contains(approvedAirlines, airlineAddress) ||
                EnumerableSet.contains(waitingAirlines, airlineAddress),
            "Caller is already in queue or registered"
        );
        _;
    }

    modifier requireAuthorizedContract() {
        require(
            authorizedContracts[msg.sender],
            "Caller is not an authorized contract"
        );
        _;
    }

    modifier requireUniqueVote(address forAirline, address fromAirline) {
        Airline storage airline = registeredAirlines[forAirline];

        require(
            !EnumerableSet.contains(airlineToVoters[forAirline], fromAirline),
            "This address has already voted"
        );
        _;
    }

    /************************************************************************/
    /*                           SMART CONTRACT FUNCTIONS                   */
    /************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(
        address airlineAddress,
        string calldata airlineName,
        bool skipVoting
    )
        external
        requireIsOperational
        requireAuthorizedContact
        requireNotInQueueAirline(airlineAddress)
        requireNotApprovedAirline(airlineAddress)
    {
        EnumerableSet.add(waitingAirlines, airlineAddress);

        registeredAirlines[airlineAddress] = Airline({
            name: airlineName,
            isApproved: skipVoting,
            fundedValue: 0
        });
    }

    function approveAirline(address airlineAddress) internal {
        registeredAirlines[airlineAddress].isApproved = true;

        if (registeredAirlines[airlineAddress].fundedValue >= 10 ether) {
            EnumerableSet.add(approvedAirlines, airlineAddress);
            EnumerableSet.remove(waitingAirlines, airlineAddress);
        }
    }

    function voteForAirline(
        address forAirline,
        address fromAirline
    )
        external
        requireAuthorizedContract
        requireIsOperational
        requireInQueueAirline(forAirline)
        requireApprovedAirline(fromAirline)
        requireUniqueVote(forAirline, fromAirline)
    {
        EnumerableSet.add(airlineToVoters[forAirline], fromAirline);

        if (
            EnumerableSet.length(airlineToVoters[forAirline]) >=
            EnumerableSet.length(approvedAirlines) / 2
        ) {
            approveAirline(forAirline);
        }
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(
        uint256 value,
        address passenger,
        string calldata flightNo,
        address airline,
        uint256 timestamp
    ) external payable requireAuthorizedContact {
        bytes32 flightKey = getFlightKey(airline, flightNo, timestamp);

        Insurance memory insurance = Insurance({
            value: value,
            passenger: passenger,
            flightNo: flightNo,
            paidOut: false
        });
        boughtInsurances[flightKey].push(insurance);
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees(
        address airlineAddress,
        string memory flight,
        uint256 timestamp
    ) external requireIsOperational requireAuthorizedContract {
        bytes32 flightKey = getFlightKey(airlineAddress, flight, timestamp);

        Insurance[] storage toBePaied = boughtInsurances[flightKey];

        for (uint256 index = 0; index < toBePaied.length; index++) {
            Insurance storage ins = toBePaied[index];

            if (ins.paidOut == false) {
                // calc payout
                uint256 payoutValue = (ins.value * 150) / 100;

                ins.paidOut = true;

                payouts[ins.passenger] = payouts[ins.passenger] + payoutValue;
            }
        }
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(
        address passenger
    )
        external
        payable
        requireIsOperational
        requireAuthorizedContract
        returns (uint256)
    {
        require(payouts[passenger] > 0, "There is nothing to be refunded");

        uint256 amount = payouts[passenger];

        payouts[passenger] = 0;
        payable(passenger).transfer(amount);

        return amount;
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund(
        address airlineAddress,
        uint256 amount
    )
        external
        payable
        requireIsOperational
        requireAuthorizedContract
        requireRegisteredAirline(airlineAddress)
    {
        require(amount > 0, "Did not send any funds.");

        registeredAirlines[airlineAddress].fundedValue =
            registeredAirlines[airlineAddress].fundedValue +
            amount;

        if (registeredAirlines[airlineAddress].isApproved) {
            approveAirline(airlineAddress);
        }
    }

    function getInsurance(
        address airline,
        string memory flight,
        uint256 timestamp,
        address passenger
    ) public view returns (Insurance memory) {
        bytes32 key = getFlightKey(airline, flight, timestamp);
        Insurance[] memory insurances = boughtInsurances[key];

        for (uint256 index = 0; index < insurances.length; index++) {
            Insurance memory ins = insurances[index];

            if (ins.passenger == passenger) {
                return ins;
            }
        }

        return
            Insurance({
                value: 0,
                passenger: address(0),
                flightNo: "",
                paidOut: false
            });
    }

    function getFlightKey(
        address airline,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    fallback() external payable {
        //
    }

    receive() external payable {
        //
    }
}
