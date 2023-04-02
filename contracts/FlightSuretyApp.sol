// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

// It's important to avoid vulnerabilities due to numeric overflow bugs
// OpenZeppelin's SafeMath library, when used correctly, protects agains such bugs
// More info: https://www.nccgroup.trust/us/about-us/newsroom-and-events/blog/2018/november/smart-contract-insecurity-bad-arithmetic/

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./IFlightSuretyData.sol";

/************************************************** */
/* FlightSurety Smart Contract                      */
/************************************************** */
contract FlightSuretyApp {
    using SafeMath for uint256;

    IFlightSuretyData private dataContract;

    uint constant REQUIRED_VOTES_TO_VOTE = 50;

    uint8 private constant STATUS_CODE_UNKNOWN = 0;
    uint8 private constant STATUS_CODE_ON_TIME = 10;
    uint8 private constant STATUS_CODE_LATE_AIRLINE = 20;
    uint8 private constant STATUS_CODE_LATE_WEATHER = 30;
    uint8 private constant STATUS_CODE_LATE_TECHNICAL = 40;
    uint8 private constant STATUS_CODE_LATE_OTHER = 50;

    /************************************************************************/
    /*                   DATA VARIABLES                                     */
    /************************************************************************/

    struct Flight {
        bool isRegistered;
        uint8 statusCode;
        uint256 updatedTimestamp;
        address airline;
    }

    mapping(bytes32 => Flight) private flights;
    mapping(address => mapping(address => bool)) private airlinesInVoting;
    mapping(address => uint) private airlinesInVotingAmount;
    mapping(bytes32 => address[]) userInsurancesByFlight;

    address private contractOwner;

    /************************************************************************/
    /*                   EVENT DEFINITIONS                                  */
    /************************************************************************/

    event AirlineVoted(address _airlineAddress);

    constructor(address dataContractAddress) {
        contractOwner = msg.sender;
        dataContract = IFlightSuretyData(dataContractAddress);
    }

    /************************************************************************/
    /*                   FUNCTION MODIFIERS                                 */
    /************************************************************************/

    modifier requireIsOperational() {
        require(
            dataContract.isOperational(),
            "Contract is currently not operational"
        );
        _;
    }

    modifier requireContractOwner() {
        require(msg.sender == contractOwner, "Caller is not contract owner");
        _;
    }

    modifier requireIsAirlineAuthorized() {
        require(
            dataContract.isAirlineAuthorized(),
            "Can't register new airline, the airline caller is not authorized"
        );
        _;
    }

    modifier requireIsNotAirlineInVoting(address _airlineAddress) {
        require(
            !airlinesInVoting[_airlineAddress][msg.sender],
            "The airline has already voted"
        );
        _;
    }

    /************************************************************************/
    /*                   UTILITY FUNCTIONS                                  */
    /************************************************************************/

    function isOperational() external view returns (bool) {
        return dataContract.isOperational();
    }

    /************************************************************************/
    /*                 SMART CONTRACT FUNCTIONS                             */
    /************************************************************************/

    function registerAirline(
        address _airlineAddress
    )
        external
        requireIsOperational
        requireIsAirlineAuthorized
        returns (bool register, uint256 votes)
    {
        uint airlinesAmount = dataContract.getAirlinesAmount();

        if (airlinesAmount <= 4) {
            dataContract.registerAirline(_airlineAddress);
            register = true;
            votes = 1;
        } else {
            (register, votes) = voteForAirline(_airlineAddress);
        }

        return (register, votes);
    }

    function voteForAirline(
        address _airlineAddress
    )
        private
        requireIsNotAirlineInVoting(_airlineAddress)
        returns (bool register, uint256 votes)
    {
        airlinesInVoting[_airlineAddress][msg.sender] = true;
        airlinesInVotingAmount[_airlineAddress]++;

        register = false;
        votes = airlinesInVotingAmount[_airlineAddress];

        emit AirlineVoted(_airlineAddress);

        if (
            (airlinesInVotingAmount[_airlineAddress] * 100) /
                dataContract.getAirlinesAmount() >
            REQUIRED_VOTES_TO_VOTE
        ) {
            dataContract.registerAirline(_airlineAddress);
            register = true;
        }

        return (register, votes);
    }

    function buy(
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp
    ) external payable requireIsOperational {
        dataContract.buy{value: msg.value}(
            msg.sender,
            _airlineAddress,
            _flightNumber,
            _timestamp
        );

        bytes32 flightKey = getFlightKey(
            _airlineAddress,
            _flightNumber,
            _timestamp
        );

        userInsurancesByFlight[flightKey].push(msg.sender);
    }

    function pay(
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp
    ) external requireIsOperational {
        dataContract.pay(
            msg.sender,
            _airlineAddress,
            _flightNumber,
            _timestamp
        );
    }

    function processFlightStatus(
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp,
        uint8 statusCode
    ) internal requireIsOperational {
        address userAddress;
        bytes32 flightKey = getFlightKey(
            _airlineAddress,
            _flightNumber,
            _timestamp
        );

        if (statusCode == STATUS_CODE_LATE_AIRLINE) {
            uint256 idx = 0;
            uint256 creditInsuree;
            uint256 usersToPayAmount = userInsurancesByFlight[flightKey].length;
            uint256 insurancePaymentAmount;

            for (; idx < usersToPayAmount; idx++) {
                userAddress = userInsurancesByFlight[flightKey][idx];
                insurancePaymentAmount = dataContract.getInsurancePaymentAmount(
                    userAddress,
                    _airlineAddress,
                    _flightNumber,
                    _timestamp
                );
                creditInsuree = calculateCreditInsuree(insurancePaymentAmount);
                dataContract.setCreditInsuree(
                    userAddress,
                    creditInsuree,
                    _airlineAddress,
                    _flightNumber,
                    _timestamp
                );
            }

            delete userInsurancesByFlight[flightKey];
        }
    }

    function calculateCreditInsuree(
        uint256 _insuranceAmount
    ) private pure returns (uint256) {
        uint256 creditInsuree = _insuranceAmount * 2;

        return creditInsuree;
    }

    function fetchFlightStatus(
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp
    ) external requireIsOperational {
        uint8 index = getRandomIndex(msg.sender);

        bytes32 key = keccak256(
            abi.encodePacked(index, _airlineAddress, _flightNumber, _timestamp)
        );

        ResponseInfo memory response = ResponseInfo({
            requester: msg.sender,
            isOpen: true
        });

        oracleResponses[key] = response;

        oracleResponseAddresses[key][index] = new address[](0);

        emit OracleRequest(index, _airlineAddress, _flightNumber, _timestamp);
    }

    function fund() external payable {
        dataContract.fund{value: msg.value}(msg.sender);
    }

    /************************************************************************/
    /*                 SMART ORACLE MANAGEMENT                             */
    /************************************************************************/

    uint256 public constant REGISTRATION_FEE = 1 ether;
    uint256 private constant MIN_RESPONSES = 3;

    uint8 private nonce = 0;

    struct Oracle {
        bool isRegistered;
        uint8[3] indexes;
    }

    struct ResponseInfo {
        address requester;
        bool isOpen;
    }

    mapping(address => Oracle) private oracles;
    mapping(bytes32 => ResponseInfo) private oracleResponses;

    mapping(bytes32 => mapping(uint8 => address[]))
        private oracleResponseAddresses;

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

    event OracleRequest(
        uint8 index,
        address airline,
        string flight,
        uint256 timestamp
    );

    function isRegistredOracle() external view returns (bool, uint8[3] memory) {
        bool isReg = oracles[msg.sender].isRegistered;
        uint8[3] memory indexes;

        if (isReg) {
            indexes = getMyIndexes();
        } else {
            indexes[0] = 0;
            indexes[1] = 0;
            indexes[2] = 0;
        }

        return (isReg, indexes);
    }

    function registerOracle() external payable {
        require(msg.value >= REGISTRATION_FEE, "Registration fee is required");

        uint8[3] memory indexes = generateIndexes(msg.sender);

        oracles[msg.sender] = Oracle({isRegistered: true, indexes: indexes});
    }

    function getMyIndexes() public view returns (uint8[3] memory) {
        require(
            oracles[msg.sender].isRegistered,
            "Not registered as an oracle"
        );

        return oracles[msg.sender].indexes;
    }

    function submitOracleResponse(
        uint8 _index,
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp,
        uint8 _statusCode
    ) external {
        require(
            (oracles[msg.sender].indexes[0] == _index) ||
                (oracles[msg.sender].indexes[1] == _index) ||
                (oracles[msg.sender].indexes[2] == _index),
            "Index does not match oracle request"
        );

        bytes32 key = keccak256(
            abi.encodePacked(_index, _airlineAddress, _flightNumber, _timestamp)
        );

        require(
            oracleResponses[key].isOpen,
            "Flight or timestamp do not match oracle request"
        );

        oracleResponseAddresses[key][_statusCode].push(msg.sender);

        emit OracleReport(
            _airlineAddress,
            _flightNumber,
            _timestamp,
            _statusCode
        );

        if (oracleResponseAddresses[key][_statusCode].length >= MIN_RESPONSES) {
            emit FlightStatusInfo(
                _airlineAddress,
                _flightNumber,
                _timestamp,
                _statusCode
            );

            processFlightStatus(
                _airlineAddress,
                _flightNumber,
                _timestamp,
                _statusCode
            );
        }
    }

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

    function getRandomIndex(address account) internal returns (uint8) {
        uint8 maxValue = 10;

        uint8 random = uint8(
            uint256(
                keccak256(
                    abi.encodePacked(blockhash(block.number - nonce++), account)
                )
            ) % maxValue
        );

        if (nonce > 250) {
            nonce = 0;
        }

        return random;
    }

    function getFlightKey(
        address _airlineAddress,
        string memory _flightNumber,
        uint256 _timestamp
    ) internal pure returns (bytes32) {
        return
            keccak256(
                abi.encodePacked(_airlineAddress, _flightNumber, _timestamp)
            );
    }

    receive() external payable {
        //
    }
}
