// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddSubscriber} from "./Interactions.s.sol";

contract DeployRaffle is Script {
    address public raffle;

    function run() public {
        deployContract();
    }

    function deployContract() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetWorkConfig memory networkConfig = helperConfig
            .getConfig();

        if (networkConfig.subscriptionId == 0) {
            // Create subscription
            CreateSubscription createSub = new CreateSubscription();
            (
                networkConfig.subscriptionId,
                networkConfig.vrfCoordinator
            ) = createSub.createSubscription(
                networkConfig.vrfCoordinator,
                networkConfig.account
            );

            // Fund it
            FundSubscription fundSub = new FundSubscription();
            fundSub.fundSubscription(
                networkConfig.vrfCoordinator,
                networkConfig.subscriptionId,
                networkConfig.linkToken,
                networkConfig.account
            );
        }

        // We need to deply the Raffle contract to the network
        // We also need to work with real network
        vm.startBroadcast(networkConfig.account);
        Raffle raffleContract = new Raffle(
            networkConfig.entranceFee,
            networkConfig.interval,
            networkConfig.vrfCoordinator,
            networkConfig.gasLane,
            networkConfig.subscriptionId,
            networkConfig.gasLimit
        );
        vm.stopBroadcast();

        // Add consumer to the VRF Coordinator
        AddSubscriber addSubscriber = new AddSubscriber();
        addSubscriber.addConsumer(
            networkConfig.vrfCoordinator,
            address(raffleContract),
            networkConfig.subscriptionId,
            networkConfig.account
        );

        return (raffleContract, helperConfig);
    }
}
