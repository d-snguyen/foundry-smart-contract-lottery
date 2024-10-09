// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";
import {console} from "forge-std/Test.sol";
import {AutomationCompatibleInterface} from "@chainlink/contracts/src/v0.8/interfaces/AutomationCompatibleInterface.sol";

/**
 * @title Raffle contract
 * @author Bruce
 * @notice this contract to create sample raffle
 */
contract Raffle is VRFConsumerBaseV2Plus, AutomationCompatibleInterface {
    /* Errors */
    error Raffle__SendMeoreToEnterRaffle();
    error Raffle__TransferFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__TimeIsNotPassYet();
    error Raffle__UpkeepNotNeeded(
        uint256 balance,
        uint256 customerLength,
        uint256 state
    );

    /* Events */
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestId);

    /* Types */
    enum RaffleState {
        OPEN, // 0
        CALCULATING // 1
    }

    /* Constants */
    uint16 private constant REQUEST_CONFORMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    /* Immutable Variables */
    uint256 private immutable i_interval;
    uint256 private immutable i_entranceFee;
    bytes32 private immutable i_keyHash;
    uint256 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;

    /* State Variables */
    address payable[] private s_players;
    address payable private s_recentWinner;

    // @dev interval in seconds
    uint256 private s_lastTimeStamp;
    RaffleState private s_raffleState;

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gasLane,
        uint256 subscriptionId,
        uint32 gasLimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyHash = gasLane;
        i_subscriptionId = subscriptionId;
        i_callbackGasLimit = gasLimit;
        s_raffleState = RaffleState.OPEN;
    }

    function enterRaffle() public payable {
        //require(msg.value >= i_entranceFee, SendMeoreToEnterRaffle__SendMeoreToEnterRaffleRaffle()); <- this is less gas efficient then below?
        if (msg.value < i_entranceFee) {
            revert Raffle__SendMeoreToEnterRaffle();
        }

        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        s_players.push(payable(msg.sender));
        emit RaffleEnter(msg.sender);
    }

    /**
     *  This is function is called by the Keeper Network to determine if work needs to be performed.
     *  The upkeepNeeded function should return two values. The first is a bool that is true if the Keeper should perform work.
     *  1) the time interval has passed between raffle runs
     * 2) the counter is less than the max number of raffles
     * 3) the raffle is open
     * 4) the contract has ETH
     * 5) the contract has LINK
     *
     * @return upkeepNeeded - true if the Keeper should perform work
     * @return ignore - performData is not used
     */
    function checkUpkeep(
        bytes memory /* checkData */
    )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /* performData */)
    {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool raffleIsOpen = s_raffleState == RaffleState.OPEN;
        bool hasPlayers = s_players.length > 0;
        bool hasETH = address(this).balance > 0;

        upkeepNeeded = timeHasPassed && raffleIsOpen && hasPlayers && hasETH;
        return (upkeepNeeded, "");
    }

    // 1. get a random number
    // 2. use random number to pick a winner
    // 3. Be automatically called
    function performUpkeep(bytes calldata /* performData */) external override {
        // check if the time has passed
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }

        s_raffleState = RaffleState.CALCULATING;

        // RandomWordsRequest is a struct from VRFV2PlusClient library
        // Will revert if subscription is not set and funded.
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyHash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFORMATIONS,
                callbackGasLimit: i_callbackGasLimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );

        // Quizz is this redundant?
        // yest with  emit RandomWordsRequested(

        emit RequestedRaffleWinner(requestId);
    }

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] calldata randomWords
    ) internal override {
        // pick a winner
        uint256 index = randomWords[0] % s_players.length;
        s_recentWinner = s_players[index];
        //s_recentWinner.transfer(address(this).balance);
        (bool success, ) = s_recentWinner.call{value: address(this).balance}(
            ""
        );
        if (!success) {
            revert Raffle__TransferFailed();
        }
        s_raffleState = RaffleState.OPEN;
        s_players = new address payable[](0);

        // reset the time
        s_lastTimeStamp = block.timestamp;

        // emit event
        emit WinnerPicked(s_recentWinner);
    }

    // Getter funtions
    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayersLength() public view returns (uint256) {
        return s_players.length;
    }

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function changeRaffleState(RaffleState state) public {
        s_raffleState = state;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getSubscriptionId() public view returns (uint256) {
        return i_subscriptionId;
    }

    function getCallbackGasLimit() public view returns (uint32) {
        return i_callbackGasLimit;
    }

    function getKeyHash() public view returns (bytes32) {
        return i_keyHash;
    }

    function getVrfCoordinator() public view returns (address) {
        return address(s_vrfCoordinator);
    }
}
