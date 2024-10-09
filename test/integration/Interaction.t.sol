// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "script/HelperConfig.s.sol";
import {Raffle} from "src/Raffle.sol";
import {CreateSubscription} from "script/Interactions.s.sol";

contract Interaction is Test {
    Raffle public raffle;
    HelperConfig public helperConfig;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_BALANCE = 10 ether;
    uint256 public constant LINK_BALANCE = 100 ether;

    CreateSubscription public createSubscription;

    function setUp() public {
        helperConfig = new HelperConfig();
        createSubscription = new CreateSubscription();
    }

    //// Test create subscription
    function testCreateSubscription() public {
        // Arrange
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account = helperConfig.getConfig().account;

        // Act
        (uint256 subscriptionId, ) = createSubscription.createSubscription(
            vrfCoordinator,
            account
        ); // address vrfCoordinator, address account

        // Assert
        assertTrue(subscriptionId > 0);
    }
}
