// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/*
 * @title A sample Raffle contract
 * @author mahima
 * @notice This contract is a simple raffle contract
 * @dev Implementing Chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */

    error Raffle_sendMoreToEnterInRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle_UpkeepNotNeeded(
        uint256 balance,
        uint256 playersLength,
        uint256 raffleState
    );

    /* Type Decelarations */

    enum RaffleState {
        OPEN, //0
        CALCULATING //1
    }

    /* State variables */

    uint16 private constant REQUEST_CONFIRMATION = 3;
    uint32 private constant NUM_WORDS = 1;
    uint256 private immutable i_interval;
    // @dev duration of the lottery should be in seconds
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;
    uint256 private s_lastTimeStamp;
    bytes32 private immutable i_keyhash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;
    RaffleState private s_raffleState;

    /* EVents */

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinate,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinate) {
        {
            i_interval = interval;
            i_entranceFee = entranceFee;
            i_keyhash = gasLane;
            i_subscriptionId = subscriptionId;
            i_callbackGasLimit = callbackGasLimit;

            s_lastTimeStamp = block.timestamp;
            s_raffleState = RaffleState.OPEN;
        }
    }

    function enterRaffle() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent"); before solidity 0.8
        // require(msg.value >= i_entranceFee, Raffle_sendMoreToEnterInRaffle()); //InSolidity 0.8.22

        if (msg.value < i_entranceFee) {
            revert Raffle_sendMoreToEnterInRaffle(); //after solidity 0.8.4
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }
        s_players.push(payable(msg.sender));

        //1. makes migrations useful for events , we can add upto 3 indexed paramers in the events as an indexed label for unit256 indexed s_players
        //Easier for frontend indexing

        emit RaffleEntered(msg.sender);
    }

    //When the winner should be picked.
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = ((block.timestamp - s_lastTimeStamp) >=
            i_interval);
        bool isOpen = s_raffleState == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        return (upkeepNeeded, ""); //return null
    }

    //Get a random number
    //automatically called

    function performUpkeep() external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        s_raffleState = RaffleState.CALCULATING;
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        if ((block.timestamp - s_lastTimeStamp) < i_interval) {
            revert();
        }
        s_raffleState = RaffleState.CALCULATING;
        VRFV2PlusClient.RandomWordsRequest memory request = VRFV2PlusClient
            .RandomWordsRequest({
                keyHash: i_keyhash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATION,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            });

        uint256 requestId = s_vrfCoordinator.requestRandomWords(request);
        emit RequestedRaffleWinner(requestId);
    }

    /* getter functions*/

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    //CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 requestId,
        uint256[] calldata randomWords
    ) internal virtual override {
        //Random words
        //6667777788888999999988 * 10 = 9 This random no is generate from the chain LINK

        uint256 indexOfWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[indexOfWinner];

        s_recentWinner = recentWinner;
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(s_recentWinner);

        (bool success, ) = recentWinner.call{value: address(this).balance}("");
        if (!success) {
            revert Raffle__TransferFailed();
        }
    }

    /* Getter functions */

    function getRaffleState() external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexOfPlayer) external view returns (address) {
        return s_players[indexOfPlayer];
    }
}
