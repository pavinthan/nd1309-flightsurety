// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./core/Ownable.sol";
import "./IFlightSuretyData.sol";

contract FlightSuretyData is IFlightSuretyData, Ownable {
    using SafeMath for uint256;

    /************************************************************************/
    /*                   DATA VARIABLES                                     */
    /************************************************************************/

    struct Airline {
        string name;
        address airline;
        bool isVoted;
        bool isFunded;
        bool isApproved;
        address[] voters;
    }

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    struct Insurance {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    // Blocks all state changes throughout the contract if false
    bool private operational = true;

    // Only allow external calls from these contract addressess
    mapping(address => uint256) private authorizedAppContracts;

    // All registerd airlines
    mapping(address => Airline) private airlines;

    uint32 private registeredAirlinesCount = 0;

    // All registerd flights
    mapping(bytes32 => Flight) private flights;

    // All registerd insurances
    mapping(bytes32 => Insurance) private insurances;

    /************************************************************************/
    /*                   EVENT DEFINITIONS                                  */
    /************************************************************************/

    event AirlineAdded(Airline airline);

    event AirlineRemoved(Airline airline);

    event FlightAdded(Flight flight);

    event FlightRemoved(Flight flight);

    event InsurancePurchased(Insurance insurance);

    event InsuranceClaimed(Insurance insurance);

    /**
     * @dev Constructor
     *      The deploying account becomes contractOwner
     */
    constructor() {
        //
    }

    /************************************************************************/
    /*                   FUNCTION MODIFIERS                                 */
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
     * @dev Modifier that requires the "ContractOwner"
     *      account to be the function caller
     */
    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    /**
     * @dev Modifier that requires the "AuthorizedAppContract"
     *      account to be the function caller
     */
    modifier requireAuthorizedAppContract() {
        require(
            authorizedAppContracts[msg.sender] == 1,
            "Caller app is not authorized"
        );
        _;
    }

    /************************************************************************/
    /*                   UTILITY FUNCTIONS                                  */
    /************************************************************************/

    /**
     * @dev Get operating status of contract
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

    /**
     * @dev Get authorized status of contract
     * @return A bool that is the current operating status
     */
    function isAuthorizedAppContract(
        address appContractAddress
    ) public view returns (bool) {
        return authorizedAppContracts[appContractAddress] == 1;
    }

    /**
     * @dev Set authorized app contract addressess
     */
    function setAuthorizedAppContract(
        address appContractAddress
    ) external requireContractOwner {
        authorizedAppContracts[appContractAddress] = 1;
    }

    /**
     * @dev Sets contract operations on/off
     *
     * When operational mode is disabled,
     * all write transactions except for this one will fail
     */
    function unsetAuthorizedAppContract(
        address appContractAddress
    ) external requireContractOwner {
        delete authorizedAppContracts[appContractAddress];
    }

    /************************************************************************/
    /*                 SMART CONTRACT FUNCTIONS                             */
    /************************************************************************/

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function getNumberOfRegisteredAirlines(
        address airlineAddress,
        string memory airlineName,
        bool votingRequired
    ) external requireIsOperational requireAuthorizedAppContract {
        return _registerAirline(airlineAddress);
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerAirline(
        address _airlineAddress,
        string memory _airlineName,
        bool _votingRequired
    ) external requireIsOperational requireAuthorizedAppContract {
        require(
            airlines[_airlineAddress].airline == _airlineAddress,
            "Airline already registered"
        );

        return _registerAirline(_airlineAddress, _airlineName, _votingRequired);
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function _registerAirline(
        address _airlineAddress,
        string memory _airlineName,
        bool _votingRequired
    ) internal {
        //By default, the total number of votes is 0
        uint airlineVotes = 0;
        bool success = false;

        airlines[_airlineAddress] = Airline(true, airlineAddress);
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function registerFlight(
        address airlineAddress,
        string memory flightNumber
    ) external requireIsOperational requireAuthorizedAppContract {
        return _registerFlight(airlineAddress, flightNumber);
    }

    /**
     * @dev Add an airline to the registration queue
     *      Can only be called from FlightSuretyApp contract
     *
     */
    function _registerFlight(
        address airlineAddress,
        string memory flightNumber
    ) internal {
        bytes32 flightId = getFlightKey(
            airlineAddress,
            flightNumber,
            block.timestamp
        );

        require(
            flights[flightId].airline == airlineAddress,
            "Flight already registered"
        );

        flights[flightId] = Flight(true, 0, block.timestamp, airlineAddress);
    }

    /**
     * @dev Buy insurance for a flight
     *
     */
    function buy(address passenger, bytes32 flightId) external payable {
        //
    }

    /**
     *  @dev Credits payouts to insurees
     */
    function creditInsurees() external pure {
        //
    }

    /**
     *  @dev Transfers eligible payout funds to insuree
     *
     */
    function pay(address passenger, bytes32 flightId) external {
        //
    }

    /**
     * @dev Initial funding for the insurance. Unless there are too many delayed flights
     *      resulting in insurance payouts, the contract should be self-sustaining
     *
     */
    function fund() public payable {
        //
    }

    function getFlightKey(
        address airlineAddress,
        string memory flight,
        uint256 timestamp
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(airlineAddress, flight, timestamp));
    }

    /**
     * @dev Fallback function for funding smart contract.
     *
     */
    receive() external payable {
        fund();
    }
}
