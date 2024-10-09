// SDPX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "../test/mock/LinkToken.sol";

abstract contract CodeConstants {
    /* VRF constants */
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1e9;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 4e15;

    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 1115111;
    uint256 public constant AVALANCE_FUJI_CHAIN_ID = 43113;
    uint256 public constant POLYGON_POS_CHAIN_ID = 80002;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    address public FOUNDRY_DEFAULT_SENDER =
        0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266;
}

contract HelperConfig is CodeConstants, Script {
    error HelperConfig__InvalidChainId();

    struct NetWorkConfig {
        uint256 entranceFee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint256 subscriptionId;
        uint32 gasLimit;
        address linkToken; // in order to fund the subscription we need LINK token
        address account;
    }

    mapping(uint256 => NetWorkConfig) public networkConfigs;
    NetWorkConfig public localNetworkConfig;

    constructor() {
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[AVALANCE_FUJI_CHAIN_ID] = getAvalanceFujiConfig();
        networkConfigs[POLYGON_POS_CHAIN_ID] = getPolygonPosConfig();
    }

    function getConfigByChainId(
        uint256 chainId
    ) public returns (NetWorkConfig memory) {
        if (networkConfigs[chainId].vrfCoordinator != address(0)) {
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID) {
            return getOrCreateAnvilLocalConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function getConfig() public returns (NetWorkConfig memory) {
        console.log("Get config on chainId: %s", block.chainid);
        return getConfigByChainId(block.chainid);
    }

    function getSepoliaEthConfig() public pure returns (NetWorkConfig memory) {
        return
            NetWorkConfig({
                entranceFee: 0.01 ether,
                interval: 30, // seconds
                vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
                gasLane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
                subscriptionId: 88987328748523388394639669072862664941811824187085005211253198295133107035208,
                gasLimit: 500000,
                linkToken: 0x779877A7B0D9E8603169DdbD7836e478b4624789, // address of LINK token on Sepolia
                account: 0xf44b702B46dB9f9Dec3a3737f1DD7557b3863aCb
            });
    }

    function getAvalanceFujiConfig()
        public
        pure
        returns (NetWorkConfig memory)
    {
        return
            NetWorkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x5C210eF41CD1a72de73bF76eC39637bB0d3d7BEE,
                gasLane: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887,
                subscriptionId: 21290324057673194822495758027982486886065581550508236694193367585549254506588,
                gasLimit: 500000,
                linkToken: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846, // address of LINK token on Avalanche
                account: 0xf44b702B46dB9f9Dec3a3737f1DD7557b3863aCb
            });
    }

    function getPolygonPosConfig() public pure returns (NetWorkConfig memory) {
        return
            NetWorkConfig({
                entranceFee: 0.01 ether,
                interval: 30,
                vrfCoordinator: 0x343300b5d84D444B2ADc9116FEF1bED02BE49Cf2,
                gasLane: 0x816bedba8a50b294e5cbd47842baf240c2385f2eaf719edbd4f250a137a8c899,
                subscriptionId: 95180852039180843568324459593203024629571916102033432559261139015192429520082,
                gasLimit: 500000,
                linkToken: 0x0Fd9e8d3aF1aaee056EB9e802c3A762a667b1904, // address of LINK token on Polygon
                account: 0xf44b702B46dB9f9Dec3a3737f1DD7557b3863aCb
            });
    }

    function getOrCreateAnvilLocalConfig()
        public
        returns (NetWorkConfig memory)
    {
        // check if AnvilLocalConfig exists

        if (localNetworkConfig.vrfCoordinator != address(0)) {
            return localNetworkConfig;
        }

        vm.startBroadcast();
        // we need to deploy this mock contract to Anvile first
        // (uint96 _baseFee, uint96 _gasPrice, int256 _weiPerUnitLink

        VRFCoordinatorV2_5Mock vrfCoordinator = new VRFCoordinatorV2_5Mock(
            MOCK_BASE_FEE,
            MOCK_GAS_PRICE,
            MOCK_WEI_PER_UNIT_LINK
        );

        LinkToken linkToken = new LinkToken();

        vm.stopBroadcast();
        // For the locl network we need to deploy an dummt LINK contract
        localNetworkConfig = NetWorkConfig({
            entranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinator),
            gasLane: 0xc799bd1e3bd4d1a41cd4968997a4e03dfd2a3c7c04b695881138580163f42887,
            subscriptionId: 0, // will fix later
            gasLimit: 500000,
            linkToken: address(linkToken),
            account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
        });

        return localNetworkConfig;
    }
}
