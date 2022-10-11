// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {Gate1} from "dss-gate/Gate1.sol";
import {ClaimFee} from "claim-fee-maker/ClaimFee.sol";

contract Deploy is Script {
    address constant public VOW = 0xA950524441892A31ebddF91d3cEEFa04Bf454466;
    address constant public PAUSE_PROXY = 0xBE8E3e3618f7474F8cB1d074A26afFef007E98FB;
    
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // deploy gate and claim fee maker
        Gate1 gate = new Gate1(VOW);
        ClaimFee cfm = new ClaimFee(address(gate));

        // approve claim fee maker on gate as a valid integration
        gate.kiss(address(cfm));

        // transfer ownership from deployer to maker governance
        cfm.rely(PAUSE_PROXY);
        cfm.deny(address(this));

        // transfer ownership from deployer to maker governance
        gate.rely(PAUSE_PROXY);
        gate.deny(address(this));

        console.log("Gate deployed: %s", string(vm.toString(address(gate))));
        console.log("Claim-Fee-Maker deployed: %s", string(vm.toString(address(cfm))));

        vm.stopBroadcast();
    }
}
