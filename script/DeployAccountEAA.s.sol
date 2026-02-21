// SPDX-License-Identifier: MIT

pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {AccountEAA} from "../src/AA-ETHEREUN/Account.sol";
import {HelperConfig} from "./HelperConfig.sol";

contract DeployAccountEAA is Script {
    function run() public {
        depolyEAA();
    }

    function depolyEAA() public returns (HelperConfig, AccountEAA) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory networkConfig = helperConfig.getConfig();

        vm.startBroadcast(networkConfig.accountAddress);
        AccountEAA accountEAA = new AccountEAA(networkConfig.entryPoint);
        accountEAA.transferOwnership(networkConfig.accountAddress);
        vm.stopBroadcast();
        return (helperConfig, accountEAA);
    }
}
