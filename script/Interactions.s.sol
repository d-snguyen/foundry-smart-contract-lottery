// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    function createSubscriptionUsingConfig() public returns (uint256, address) {
        // Create subscription
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;

        console.log(
            "Create subscription on vrfCoordinator: %s",
            address(vrfCoordinator)
        );
        // create subscription
        return
            createSubscription(
                vrfCoordinator,
                helperConfig.getConfig().account
            );
    }

    function createSubscription(
        address vrfCoordinator,
        address account
    ) public returns (uint256, address) {
        // create subscription
        console.log("Create subscription on chainId: %s", block.chainid);
        console.log("verfCoordinator: %s", vrfCoordinator);
        console.log("block.number: %s", block.number);
        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.roll(block.number + 1);
        }

        console.logBytes32(blockhash(block.number - 1));

        vm.startBroadcast(account);
        //uint256 subscriptionId = 0;
        uint256 subscriptionId = VRFCoordinatorV2_5Mock(vrfCoordinator)
            .createSubscription();
        vm.stopBroadcast();

        console.log("SubscriptionId: %s", subscriptionId);
        return (subscriptionId, vrfCoordinator);
    }

    function run() public {
        createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint256 public constant FUND_AMOUNT = 3 ether;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    function fundScriptionUsingConfig() public {
        // Fund it
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;

        console.log(
            "Fund subscription on vrfCoordinator: %s",
            address(vrfCoordinator)
        );
        console.log("subscriptionId: %s", subscriptionId);

        // create subscription
        address linkToken = helperConfig.getConfig().linkToken;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionId, linkToken, account);
    }

    function fundSubscription(
        address vrfCoordinator,
        uint256 subscriptionId,
        address linkToken,
        address account
    ) public {
        // fund subscription
        console.log("Fund subscription on chainId: %s", block.chainid);
        console.log("verfCoordinator: %s", vrfCoordinator);
        console.log("subscriptionId: %s", subscriptionId);
        console.log("linkToken: %s", linkToken);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();

            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(
                subscriptionId,
                FUND_AMOUNT * 100
            );

            vm.stopBroadcast();
            return;
        } else {
            vm.startBroadcast(account);

            LinkToken(linkToken).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subscriptionId)
            );

            vm.stopBroadcast();
        }
    }

    function run() public {
        fundScriptionUsingConfig();
    }
}

contract AddSubscriber is Script {
    function addConsumerUsingConfig(address raffleAddress) public {
        // Add consumer to the VRF Coordinator
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionId = helperConfig.getConfig().subscriptionId;

        console.log("Raffle address: %s", raffleAddress);

        console.log(
            "Add consumer on vrfCoordinator: %s",
            address(vrfCoordinator)
        );

        // add consumer
        address account = helperConfig.getConfig().account;
        addConsumer(vrfCoordinator, raffleAddress, subscriptionId, account);
    }

    function addConsumer(
        address vrfCoordinator,
        address raffleAddress,
        uint256 subscriptionId,
        address account
    ) public {
        // add consumer
        console.log("Add consumer on chainId: %s", block.chainid);
        console.log("verfCoordinator: %s", vrfCoordinator);
        console.log("raffleAddress: %s", raffleAddress);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(
            subscriptionId,
            raffleAddress
        );
        vm.stopBroadcast();
    }

    function run() public {
        address raffleAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffleAddress);
    }
}
