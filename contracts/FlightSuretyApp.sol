// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./FlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256;

    FlightSuretyData private flightSuretyData;

    /***********************************************************************/
    /*                            DATA VARIABLES                           */
    /***********************************************************************/

    // Flight status codes
    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    // Account used to deploy contract
    address private contractOwner;

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    mapping(bytes32 => Flight) private flights;

    event PayoutWithdrawn(address paxAddress, uint256 value);
    event InsurancePurchased(
        address paxAddress,
        uint256 amount,
        address airlineAddress,
        string flight,
        uint256 timestamp
    );
    event AirlineApproved(address airlineAddress);

    /***********************************************************************/
    /*                            FUNCTION MODIFIERS                       */
    /***********************************************************************/

    // Modifiers help avoid duplication of code. They are typically used to validate something
    // before a function is allowed to be executed.

    /**
     * @dev Modifier that requires the "operational" boolean variable to be "true"
     *      This is used on all state changing functions to pause the contract in
     *      the event there is an issue that needs to be fixed
     */
    modifier requireIsOperational() {
        // Modify to call data contract's status
        require(
            flightSuretyData.isOperational(),
            "Contract is currently not operational"
        );
        _; // All modifiers require an "_" which indicates where the function body will be added
    }

    /**
     * @dev Modifier that requires the "ContractOwner" account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier hasPaidEnough(uint64 insurenceValue) {
        require(msg.value >= insurenceValue, "Not enought Eth sent");
        _;
    }

    modifier requireMinimumAirlineFund() {
        require(
            msg.value >= 10 ether,
            "Airline fund is less than the required minimum"
        );
        _;
    }

    modifier requireInsuranceLimit() {
        require(msg.value <= 1 ether, "Maximal insurence is 1 Eth");
        _;
    }

    modifier requireNotAirline(address airlineAddress) {
        require(
            !flightSuretyData.isRegisteredAirline(airlineAddress),
            "Caller is a registered airline"
        );
        _;
    }

    modifier requireAirline(address airlineAddress) {
        require(
            flightSuretyData.isRegisteredAirline(airlineAddress),
            "Caller is not a registered airline"
        );
        _;
    }

    modifier requireApprovedAirline(address airlineAddress) {
        require(
            flightSuretyData.isApprovedAirline(airlineAddress),
            "Caller is not an approved airline"
        );
        _;
    }

    modifier requireCallerIsApprovedAirline() {
        require(
            flightSuretyData.isApprovedAirline(msg.sender),
            "Caller is not an approved airline"
        );
        _;
    }

    modifier requireCallerUniqueVote(address airlineAddress) {
        require(
            flightSuretyData.isUniqueVote(airlineAddress, msg.sender),
            "Caller has already voted for this airline"
        );
        _;
    }

    modifier requireAvailablePayout() {
        require(
            flightSuretyData.isPayoutAvailable(msg.sender),
            "Passager has no payout"
        );
        _;
    }

    /***********************************************************************/
    /*                            CONSTRUCTOR                              */
    /***********************************************************************/

    /**
     * @dev Contract constructor
     *
     */
    constructor(address payable dataContract) {
        contractOwner = msg.sender;
        flightSuretyData = FlightSuretyData(dataContract);
    }

    /************************************************************************/
    /*                             UTILITY FUNCTIONS                        */
    /************************************************************************/

    function isOperational() public view returns (bool) {
        // Modify to call data contract's status
        return flightSuretyData.isOperational();
    }

    /***********************************************************************/
    /*                           SMART CONTRACT FUNCTIONS                  */
    /***********************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *
     */
    function registerAirline(
        address airline,
        string memory name
    )
        external
        requireIsOperational
        requireNotAirline(airline)
        requireCallerIsApprovedAirline
        returns (bool success)
    {
        uint256 approvedAirlines = flightSuretyData.getApprovedAirlinesCount();

        if (approvedAirlines < 4) {
            flightSuretyData.registerAirline(airline, name, true);
        } else {
            flightSuretyData.registerAirline(airline, name, false);
        }

        return (true);
    }

    function voteAirline(
        address airlineAddress
    )
        external
        requireIsOperational
        requireCallerIsApprovedAirline
        requireCallerUniqueVote(airlineAddress)
    {
        flightSuretyData.voteForAirline(airlineAddress, msg.sender);

        if (flightSuretyData.isApprovedAirline(airlineAddress)) {
            emit AirlineApproved(airlineAddress);
        }
    }

    // this only allows the airline to fund itself
    function fundAirline()
        public
        payable
        requireIsOperational
        requireAirline(msg.sender)
    {
        flightSuretyData.fund(msg.sender, msg.value);

        payable(flightSuretyData).transfer(msg.value);

        if (flightSuretyData.isApprovedAirline(msg.sender)) {
            emit AirlineApproved(msg.sender);
        }
    }

    // purchase insurance for the airline and flight
    // this doesn't yet check whether the passenger has alreday purchased insurance,
    // nor does it check whether the flight is in the past,
    // these would be good improvements
    function buyInsurance(
        address airlineAddress,
        string calldata flightNo,
        uint256 timestamp
    )
        public
        payable
        requireIsOperational
        requireInsuranceLimit
        requireApprovedAirline(airlineAddress)
    {
        flightSuretyData.buy(
            msg.value,
            msg.sender,
            flightNo,
            airlineAddress,
            timestamp
        );

        payable(flightSuretyData).transfer(msg.value);

        emit InsurancePurchased(
            msg.sender,
            msg.value,
            airlineAddress,
            flightNo,
            timestamp
        );
    }

    function withdrawPayout()
        public
        requireIsOperational
        requireAvailablePayout
    {
        uint256 amount = flightSuretyData.pay(msg.sender);
        emit PayoutWithdrawn(msg.sender, amount);
    }

    /**
     * @dev Register a future flight for insuring.
     *
     */
    function registerFlight(
        string calldata flight,
        uint256 timestamp,
        address airline
    ) external {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        flights[flightKey] = Flight({
            isRegistered: true,
            statusCode: STATUS_CODE_UNKNOWN,
            updatedTimestamp: timestamp,
            airline: airline
        });
    }

    /**
     * @dev Called after oracle has updated flight status
     *
     */
    function processFlightStatus(
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    ) internal {
        bytes32 flightKey = getFlightKey(airline, flight, timestamp);

        flights[flightKey].statusCode = statusCode;

        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            flightSuretyData.creditInsurees(airline, flight, timestamp);
        }
    }

    // Generate a request for oracles to fetch flight information
    function fetchFlightStatus(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) external {
        uint8 index = getRandomIndex(msg.sender);

        // Generate a unique key for storing the request
        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );

        ResponseInfo storage response = oracleResponses[key];

        response.requester = msg.sender;
        response.isOpen = true;

        emit OracleRequest(index, airline, flight, timestamp);
    }

    // region ORACLE MANAGEMENT

    // Incremented to add pseudo-randomness at various points
    uint8 private nonce = 0;

    // Fee to be paid when registering oracle
    uint256 public constant REGISTRATION_FEE = 1 ether;

    // Number of oracles that must respond for valid status
    uint256 private constant MIN_RESPONSES = 3;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    // Track all registered oracles
    mapping(address => Oracle) private oracles;

    // Model for responses from oracles
    struct ResponseInfo {
        // Account that requested status
        address requester;
        // If open, oracle responses are accepted
        bool isOpen;
        // Mapping key is the status code reported
        mapping(uint8 => address[]) responses;
        // This lets us group responses and identify
        // the response that majority of the oracles
    }

    // Track all oracle responses
    // Key = hash(index, flight, timestamp)
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    // Event fired each time an oracle submits a response
    event FlightStatusInfo(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    event OracleReport(
        address airline,
        string flight,
        uint256 timestamp,
        uint8 status
    );

    // Event fired when flight status request is submitted
    // Oracles track this and if they have a matching index
    // they fetch data and submit a response
    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    // Register an oracle with the contract
    function registerOracle() external payable {
        // Require registration fee
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() external view returns (uint8[3] memory) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    // Called by oracle when a response is available to an outstanding request
    // For the response to be accepted, there must be a pending request that is open
    // and matches one of the three Indexes randomly assigned to the oracle at the
    // time of registration (i.e. uninvited oracles are not welcome)
    function submitOracleResponse(
        uint8 index,
        address airline,
        string calldata flight,
        uint256 timestamp,
        uint8 statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == index) ||
                (oracles[msg.sender].indexes[1] == index) ||
                (oracles[msg.sender].indexes[2] == index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(index, airline, flight, timestamp)
        );
        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponses[key].responses[statusCode].push(msg.sender);

        // Information isn't considered verified until at least MIN_RESPONSES
        // oracles respond with the *** same *** information
        emit OracleReport(airline, flight, timestamp, statusCode);
        if (
            oracleResponses[key].responses[statusCode].length >= MIN_RESPONSES
        ) {
            emit FlightStatusInfo(airline, flight, timestamp, statusCode);

            // Handle flight status as appropriate
            processFlightStatus(airline, flight, timestamp, statusCode);
        }
    }

    function getFlightKey(
        address airline,
        string calldata flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airline, flight, timestamp));
    }

    // Returns array of three non-duplicating integers from 0-9
    function generateIndexes(
        address account
    ) internal returns (uint8[3] memory) {
        uint8[3] memory indexes;
        indexes[0] = getRandomIndex(account);

        indexes[1] = indexes[0];
        while (indexes[1] == indexes[0]) {
            indexes[1] = getRandomIndex(account);
        }

        indexes[2] = indexes[1];
        while ((indexes[2] == indexes[0]) || (indexes[2] == indexes[1])) {
            indexes[2] = getRandomIndex(account);
        }

        return indexes;
    }

    // Returns array of three non-duplicating integers from 0-9
    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        // Pseudo random number...the incrementing nonce adds variation
        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0; // Can only fetch blockhashes for last 256 blocks so we adapt
        }

        return random;
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
