// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IFlightSuretyData.sol";

contract FlightSuretyData is IFlightSuretyData {
    using SafeMath for uint256;

    /************************************************************************/
    /*                   DATA VARIABLES                                     */
    /************************************************************************/

    struct Airline {
        address airlineAddress;
        bool isPendingDeposit;
    }

    struct Insurance {
        address airline;
        string flight;
        uint256 timestamp;
        uint256 insuranceAmount;
        uint256 creditInsuree;
    }

    struct User {
        mapping(bytes32 => Insurance) insurances;
    }

    mapping(address => Airline) private airlines;
    mapping(address => User) private users;
    mapping(address => bool) private authorizedContracts;

    bool private operational = true;
    uint private airlinesAmount = 0;
    uint256 private maxInsuranceCharge = 1;
    address private contractOwner;

    /************************************************************************/
    /*                   EVENT DEFINITIONS                                  */
    /************************************************************************/

    event AirlineAccepted(address airlineAddress);
    event AirlineRegistred(address airlineAddress);
    event PurchasedInsurance(
        address userAddress,
        address airlineAddress,
        string flightNumber,
        uint256 timestamp
    );
    event InsuranceCreditAvailableToRefund(
        address userAddress,
        uint256 creditInsurees,
        address airlineAddress,
        string flightNumber,
        uint256 timestamp
    );
    event InsuranceCreditRefunded(
        address userAddress,
        uint256 refund,
        address airlineAddress,
        string flightNumber,
        uint256 timestamp
    );

    // Constructor
    constructor() {
        contractOwner = msg.sender;
    }

    /************************************************************************/
    /*                   FUNCTION MODIFIERS                                 */
    /************************************************************************/

    modifier requireIsOperational() {
        require(operational, "Contract is currently not operational");
        _;
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsCallerAuthorized() {
        require(
            authorizedContracts[msg.sender] || msg.sender == contractOwner,
            "Caller not authorized"
        );
        _;
    }

    modifier requireIsAirlinePendingDeposit(address _airlineAddress) {
        require(
            airlines[_airlineAddress].isPendingDeposit,
            "Airline not authorized to deposit funds"
        );
        _;
    }

    modifier requireIsAirlinePaidEnough() {
        require(msg.value >= 10 ether, "Insufficent funds, must be 10 ether");
        _;
    }

    modifier requireIsUserPaidEnough() {
        require(
            msg.value >= 0,
            "Incorrect deposit, must be a maximum of 1 ether"
        );
        _;
    }

    modifier requireIsElegiblePayout(
        address _userAddress,
        address _airlineAddress,
        string memory _flightId,
        uint256 _timestamp
    ) {
        bytes32 flightKey = getFlightKey(
            _airlineAddress,
            _flightId,
            _timestamp
        );
        require(
            users[_userAddress].insurances[flightKey].creditInsuree > 0,
            "User is not elegible to payout"
        );
        _;
    }

    /************************************************************************/
    /*                   UTILITY FUNCTIONS                                  */
    /************************************************************************/

    function isOperational() external view returns (bool) {
        return operational;
    }

    function isAirlineAuthorized() external view returns (bool) {
        return !airlines[msg.sender].isPendingDeposit;
    }

    function setOperatingStatus(bool _mode) external requireContractOwner {
        operational = _mode;
    }

    function authorizeContract(
        address _contractAddress
    ) public requireContractOwner {
        authorizedContracts[_contractAddress] = true;
    }

    function deauthorizeContract(
        address _contractAddress
    ) external requireContractOwner {
        delete authorizedContracts[_contractAddress];
    }

    function setMaxInsuranceCharge(
        uint256 _maxInsuranceCharge
    ) external requireContractOwner {
        maxInsuranceCharge = _maxInsuranceCharge;
    }

    /************************************************************************/
    /*                 SMART CONTRACT FUNCTIONS                             */
    /************************************************************************/

    function getAirlinesAmount()
        external
        view
        requireIsOperational
        requireIsCallerAuthorized
        returns (uint)
    {
        return airlinesAmount;
    }

    function registerAirline(
        address _airlineAddress
    ) public requireIsOperational requireIsCallerAuthorized {
        Airline memory newAirline = Airline(_airlineAddress, true);
        airlines[_airlineAddress] = newAirline;
        airlinesAmount++;

        emit AirlineAccepted(_airlineAddress);
    }

    function buy(
        address _userAddress,
        address _airlineAddress,
        string memory _flightId,
        uint256 _timestamp
    )
        external
        payable
        requireIsOperational
        requireIsCallerAuthorized
        requireIsUserPaidEnough
    {
        bytes32 flightKey = getFlightKey(
            _airlineAddress,
            _flightId,
            _timestamp
        );

        if (msg.value > maxInsuranceCharge) {
            users[_userAddress]
                .insurances[flightKey]
                .insuranceAmount = maxInsuranceCharge;

            uint amountToReturn = msg.value - maxInsuranceCharge;
            payable(_userAddress).transfer(amountToReturn);
        } else {
            users[_userAddress].insurances[flightKey].insuranceAmount = msg
                .value;
        }

        emit PurchasedInsurance(
            msg.sender,
            _airlineAddress,
            _flightId,
            _timestamp
        );
    }

    function getInsurancePaymentAmount(
        address _userAddress,
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp
    )
        external
        view
        requireIsOperational
        requireIsCallerAuthorized
        returns (uint256)
    {
        bytes32 flightKey = getFlightKey(
            _airlineAddress,
            _flightNumber,
            _timestamp
        );

        return users[_userAddress].insurances[flightKey].insuranceAmount;
    }

    function setCreditInsuree(
        address _userAddress,
        uint256 _creditInsurees,
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp
    ) external requireIsOperational requireIsCallerAuthorized {
        bytes32 flightKey = getFlightKey(
            _airlineAddress,
            _flightNumber,
            _timestamp
        );

        users[_userAddress]
            .insurances[flightKey]
            .creditInsuree = _creditInsurees;

        emit InsuranceCreditAvailableToRefund(
            _userAddress,
            _creditInsurees,
            _airlineAddress,
            _flightNumber,
            _timestamp
        );
    }

    function pay(
        address _userAddress,
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp
    )
        external
        payable
        requireIsOperational
        requireIsCallerAuthorized
        requireIsElegiblePayout(
            _userAddress,
            _airlineAddress,
            _flightNumber,
            _timestamp
        )
    {
        bytes32 flightKey = getFlightKey(
            _airlineAddress,
            _flightNumber,
            _timestamp
        );

        uint256 refund = users[_userAddress]
            .insurances[flightKey]
            .creditInsuree;

        users[_userAddress].insurances[flightKey].creditInsuree = 0;
        users[_userAddress].insurances[flightKey].insuranceAmount = 0;

        payable(_userAddress).transfer(refund);

        emit InsuranceCreditRefunded(
            _userAddress,
            refund,
            _airlineAddress,
            _flightNumber,
            _timestamp
        );
    }

    function fund(
        address _airlineAddress
    )
        public
        payable
        requireIsOperational
        requireIsCallerAuthorized
        requireIsAirlinePendingDeposit(_airlineAddress)
        requireIsAirlinePaidEnough
    {
        airlines[_airlineAddress].isPendingDeposit = false;

        uint amountToReturn = msg.value - 10 ether;
        payable(_airlineAddress).transfer(amountToReturn);

        emit AirlineRegistred(airlines[_airlineAddress].airlineAddress);
    }

    function getFlightKey(
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp
    ) internal view requireIsOperational returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(_airlineAddress, _flightNumber, _timestamp)
            );
    }
}
