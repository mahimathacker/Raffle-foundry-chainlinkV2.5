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
import {VRFConsumerBaseV2Plus} from "@chainlink/contracts@1.3.0/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";

/*
 * @title A sample Raffle contract
 * @author mahima
 * @notice This contract is a simple raffle contract
 * @dev Implementing Chainlink VRFv2.5
 */
contract Raffle {
    /* Errors */

    error Raffle_sendMoreToEnterInRaffle();

    uint256 private immutable i_interval;
    // @dev duration of the lottery should be in seconds

    uint256 private immutable i_entranceFee;
    address payable[] private s_player;
    uint256 private s_lastTimeStamp;

    /* EVents */

    event RaffleEntered(address indexed player);

    constructor(uint256 entranceFee, uint256 interval) {
        i_interval = interval;
        i_entranceFee = entranceFee;
        s_lastTimeStamp = block.timestamp;
    }

    function enterRaffel() public payable {
        // require(msg.value >= i_entranceFee, "Not enough ETH sent"); before solidity 0.8
        // require(msg.value >= i_entranceFee, Raffle_sendMoreToEnterInRaffle()); //InSolidity 0.8.22

        if (msg.value < i_entranceFee) {
            revert Raffle_sendMoreToEnterInRaffle(); //after solidity 0.8.4
        }
        s_player.push(payable(msg.sender));

        //1. makes migrations useful for events , we can add upto 3 indexed paramers in the events as an indexed label for unit256 indexed s_player
        //Easier for frontend indexing

        emit RaffleEntered(msg.sender);
    }

    //Get a random number
    //automatically called
    function pickWinner() public {
        block.timestamp - s_lastTimeStamp > i_interval;
        requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: s_keyHash,
                subId: s_subscriptionId,
                requestConfirmations: requestConfirmations,
                callbackGasLimit: callbackGasLimit,
                numWords: numWords,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
    }

    /* getter functions*/

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }
}
