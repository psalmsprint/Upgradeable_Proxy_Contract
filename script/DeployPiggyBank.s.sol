// SPDX-License-Identifier: MIT

pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {PiggyBank} from "../src/PiggyBank.sol";
import {Proxy} from "../src/PiggyBankProxy.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployPiggyBank is Script {
    function run() external returns (Proxy, HelperConfig) {
        HelperConfig helper = new HelperConfig();
        (address owner, address protocolAddress, uint256 deployerKey) = helper.activeNetworkConfig();

        vm.startBroadcast(deployerKey);
        PiggyBank piggy = new PiggyBank();
        Proxy proxy = new Proxy(owner, address(piggy));
        bytes memory data = abi.encodeWithSignature("initialize(address,address)", owner, protocolAddress);
        (bool success,) = address(proxy).call(data);
        if (!success) revert("initialize failed");
        vm.stopBroadcast();

        return (proxy, helper);
    }
}
