// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    struct NetworkConfig {
        address owner;
        address protocolAddress;
        uint256 deployerKey;
    }

    uint256 anvilKey = 0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a;

    NetworkConfig public activeNetworkConfig;

    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaConfig();
        } else if (block.chainid == 1) {
            activeNetworkConfig = getETHMainnetConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilConfig();
        }
    }

    function getSepoliaConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory sepoliaConfig = NetworkConfig({
            owner: 0xC7a2e256FF1b3a09eab71f0fD54c0326982De4e9,
            protocolAddress: 0xD480261b126bc513e50432aB2a91c10Ead4C68c8,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });

        return sepoliaConfig;
    }

    function getETHMainnetConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory mainnetConfig = NetworkConfig({
            owner: 0xC7a2e256FF1b3a09eab71f0fD54c0326982De4e9,
            protocolAddress: 0xD480261b126bc513e50432aB2a91c10Ead4C68c8,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });

        return mainnetConfig;
    }

    function getOrCreateAnvilConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory anvilConfig = NetworkConfig({
            owner: 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266,
            protocolAddress: 0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65,
            deployerKey: anvilKey
        });

        return anvilConfig;
    }
}
