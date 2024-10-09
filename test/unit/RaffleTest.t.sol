// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {DeployRaffle} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "../../script/HelperConfig.s.sol";
import {LinkToken} from "../../test/mock/LinkToken.sol";

contract RaffleTest is Test, CodeConstants {
    /* Events */
    event RaffleEnter(address indexed player);
    event WinnerPicked(address indexed player);

    Raffle public raffle;
    HelperConfig public helperConfig;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint256 subscriptionId;
    uint32 gasLimit;
    LinkToken link;

    function setUp() external {
        // Deploy the Raffle contract
        // console.log("Deploy Raffle contract");
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.deployContract();

        HelperConfig.NetWorkConfig memory networkConfig = helperConfig
            .getConfig();

        entranceFee = networkConfig.entranceFee;
        interval = networkConfig.interval;
        vrfCoordinator = networkConfig.vrfCoordinator;
        gasLane = networkConfig.gasLane;
        subscriptionId = networkConfig.subscriptionId;
        gasLimit = networkConfig.gasLimit;

        vm.deal(PLAYER, STARTING_BALANCE);

        // Add consumer to the VRF Coordinator
        /// vrfCoordinator.addConsumer(address(raffle));
        /*
        vm.startPrank(msg.sender);
        if (block.chainid == LOCAL_CHAIN_ID) {
            link.mint(msg.sender, LINK_BALANCE);
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                LINK_BALANCE
            );
        }
        link.approve(vrfCoordinator, LINK_BALANCE);
        vm.stopPrank();
        */
    }

    function testIninitializedRaffleHasOpenState() public view {
        assertEq(
            uint256(raffle.getRaffleState()),
            uint256(Raffle.RaffleState.OPEN)
        );
    }

    function testEnterRaffleNotEnoughFee() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__SendMeoreToEnterRaffle.selector);
        raffle.enterRaffle{value: 0}();
    }

    function testRaffleRecordLenthWhenUserEnter() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: entranceFee}();
        assertEq(raffle.getPlayersLength(), 1);
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function testEnteringRaffleEvent() public {
        vm.prank(PLAYER);

        // emit RaffleEnter(msg.sender)
        // event RaffleEnter(address indexed player);
        // true - because the player is indexed
        // false - for the rest of the parameters because they are not indexed
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEnter(PLAYER);
        // emit RaffleEnter(address(0)); -> if we change to address 0, then the test will fail because
        // the event is expecting the player address to be emitted
        raffle.enterRaffle{value: entranceFee}();
    }

    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // make sure there is at least one player
        //raffle.changeRaffleState(Raffle.RaffleState.CALCULATING);

        // Wait for the interval to pass
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    function testUserCantEnterWhenRaffleIsCalculating() public raffleEntered {
        raffle.performUpkeep("");

        // Act
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        raffle.enterRaffle{value: entranceFee}();
    }

    // Test for checkUpkeep
    function testNoNeedCheckUpkeep() public {
        // Arrange
        raffle.enterRaffle{value: entranceFee}(); // make sure there is at least one player

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded == false);
    }

    // check upkeep return false because no balance
    function testUpkeepCheckNoBalance() public {
        // Arrange
        // Wait for the interval to pass
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded == false);
    }

    // check upkeep return false because Raffle is not open
    function testUpkeepCheckRaffleNotOpen() public raffleEntered {
        raffle.performUpkeep("");

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded == false);
    }

    // PerformUpkeep is not neede because checkUpkeep return false
    function testPerformUpkeepNotNeededNoPlayer() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // make sure there is at least one player

        // Wait for the interval to pass
        //vm.warp(block.timestamp + interval + 1);
        //vm.roll(block.number + 1);

        // Act
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    // Test the controler of the contract initiate correct values
    function testEntranceFee() public view {
        assertEq(raffle.getEntranceFee(), entranceFee);
    }

    // Test checkUpkeep return false if not enough time passed
    function testUpkeepCheckNotEnoughTime() public {
        // Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}(); // make sure there is at least one player

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded == false);
    }

    // test checkupkeep reutrn false if no player
    function testUpkeepCheckNoPlayer() public {
        // Arrange
        // Wait for the interval to pass
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded == false);
    }

    // test checkupkeep return true if all conditions are met
    function testUpkeepCheckReturnTrue() public raffleEntered {
        // Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");

        // Assert
        assertTrue(upkeepNeeded == true);
    }

    // PerformUpkeep test
    // Test performUpkeep can only able to run if checkUpkeep return true
    function testPerformUpkeepIfCheckUpkeepIstrue() public raffleEntered {
        // Act
        raffle.performUpkeep("");
    }

    function testPerformUpkeepIfCheckUpkeepIsFalse() public {
        // Arrange
        // Wait for the interval to pass
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);

        // Act
        vm.expectRevert();
        raffle.performUpkeep("");
    }

    // What if we need to get data from emmited event in our tests?
    function testPeformUpkeepUpdateUpKeepStateAndTriggerEvent()
        public
        raffleEntered
    {
        // Act
        vm.recordLogs(); // To tell VM to record all the emmited events

        //vm.expectEmit(true, false, false, false, address(raffle));
        raffle.performUpkeep("");

        Vm.Log[] memory logs = vm.getRecordedLogs(); // To stop recording logs and get the logs

        // Get the request id from the logs
        // topics 0 - is the first event that was emmited is RandomWordsRequested
        // topics 1 - is the second event that was emmited is RequestedRaffleWinner
        bytes32 requestId = logs[1].topics[1];

        // Assert

        assertTrue(uint256(requestId) > 0);
        assertTrue(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);

        /**
         * emit RandomWordsRequested(keyHash: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887, requestId: 1, preSeed: 100, subId: 27823241410987273003956152577127418749587136735689993355257812420416930305890 [2.782e76], minimumRequestConfirmations: 3, callbackGasLimit: 500000 [5e5], numWords: 1, extraArgs: 0x92fd13380000000000000000000000000000000000000000000000000000000000000000, sender: Raffle: [0x50EEf481cae4250d252Ae577A09bF514f224C6C4])
    │   │   └─ ← [Return] 1
    │   ├─ emit RequestedRaffleWinner(requestId: 1)
         */
    }

    ///////////// Test fulfillRandomWords
    function testFulfillRandomWordsCanCallAfterPerformUpkeep(
        uint256 requestId
    ) public raffleEntered {
        // Arrange
        vm.expectRevert();
        // Assume we test this one on Anvil
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            requestId,
            address(raffle)
        );

        // Act

        // Assert
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }

    function testFulfillRandomwordPickWinnerResetAndSendMoney()
        public
        raffleEntered
        skipFork
    {
        // Arrange
        uint256 additionalEntraces = 3;
        uint256 startingIndex = 1;
        for (
            uint256 i = startingIndex;
            i < startingIndex + additionalEntraces;
            i++
        ) {
            address newPlayer = address(uint160(i));
            hoax(newPlayer, 1 ether);
            //vm.prank(newPlayer);
            raffle.enterRaffle{value: entranceFee}();
        }

        // At this point we have 4 players
        // Wait for the interval to pass

        // to get requestId
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory logs = vm.getRecordedLogs();
        bytes32 requestId = logs[1].topics[1];

        console.log("requestId: %s", uint256(requestId));
        console.log("SubscriptionId: %s", raffle.getSubscriptionId());

        // fulfillRandomWords
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        // Assert
        Raffle.RaffleState raffleState = raffle.getRaffleState();

        assertEq(uint256(raffleState), uint256(Raffle.RaffleState.OPEN));
    }
}
