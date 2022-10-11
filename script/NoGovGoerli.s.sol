// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "forge-std/console2.sol";
import {Gate1} from "dss-gate/Gate1.sol";
import {ClaimFee} from "claim-fee-maker/ClaimFee.sol";
import {VatAbstract} from "dss-interfaces/dss/VatAbstract.sol";
import {GemAbstract} from "dss-interfaces/ERC/GemAbstract.sol";
import {GemJoinAbstract} from "dss-interfaces/dss/GemJoinAbstract.sol";

contract Deploy is Script {
    uint256 private deployerPrivateKey;

    address constant public VOW = 0x23f78612769b9013b3145E43896Fa1578cAa2c2a;
    address constant public PAUSE_PROXY = 0x5DCdbD3cCF9B09EAAD03bc5f50fA2B3d3ACA0121;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        // deploy gate and claim fee maker
        Gate1 gate = new Gate1(VOW);
        
        ClaimFee cfm = new ClaimFee(address(gate));

        // approve claim fee maker on gate as a valid integration
        gate.kiss(address(cfm));

        vm.setEnv("VOW", string(vm.toString(VOW)));
        vm.setEnv("PAUSE_PROXY", string(vm.toString(PAUSE_PROXY)));
        vm.setEnv("GATE", string(vm.toString(address(gate))));
        vm.setEnv("CFM", string(vm.toString(address(cfm))));
        console.log("Gate deployed: %s", vm.envString("GATE"));
        console.log("Claim-Fee-Maker deployed: %s", vm.envString("CFM"));

        // note: ownership of gate and cfm is retained by the deployer address
        // add additional owner if required
        // gate.rely(ADDITIONAL_OWNER);
        // cfm.rely(ADDITIONAL_OWNER);

        vm.stopBroadcast();
    }
}

contract LoadGateWithDaiFromCDP is Script {
    uint256 private deployerPrivateKey;

    VatAbstract public vat = VatAbstract(0xB966002DDAa2Baf48369f5015329750019736031);
    GemAbstract public weth = GemAbstract(0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6);
    GemJoinAbstract public ethjoin = GemJoinAbstract(0x2372031bB0fC735722AA4009AeBf66E8BEAF4BA1);
    address public deployer;
    address public gate;
    address public cfm;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
        cfm = vm.envAddress("CFM"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        // transfer Goerli ETH to 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6 and receive Goerli WETH in return
        // ex: seth send 0xB4FBF271143F4FBf7B91A5ded31805e42b2208d6 --value $(seth --to-wei 25 ether)
        weth.approve(address(ethjoin), type(uint).max);

        uint256 eth_amt = 25 ether; // enough ether to exceed dai dust limit

        ethjoin.join(deployer, eth_amt); // to join WETH
        (,uint256 cur_rate, uint256 cur_spot,,) = vat.ilks(bytes32("ETH-A"));
        // Art,rate,spot,line,dust

        // amount 18 * spot 27 / rate 27 = art 18
        uint256 max_dai = (eth_amt * cur_spot) / cur_rate;

        vat.frob(bytes32("ETH-A"), deployer, deployer, deployer, int(eth_amt), int(max_dai));
        
        uint256 daibal_deployer = vat.dai(deployer);
        vat.move(deployer, gate, daibal_deployer);
        
        uint256 daibal_gate = vat.dai(gate);
        console.log("Dai Balance of Gate: %s", vm.toString(daibal_gate));

        vm.stopBroadcast();
    }
}

contract LoadGateWithDaiFromBalance is Script {
    uint256 private deployerPrivateKey;

    VatAbstract public vat = VatAbstract(0xB966002DDAa2Baf48369f5015329750019736031);
    address public deployer;
    address public gate;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 daibal_deployer = vat.dai(deployer);
        vat.move(deployer, gate, daibal_deployer); // move dai from deployer to gate
        
        console.log("Dai Balance of Gate: %s", vm.toString(vat.dai(gate)));
        console.log("Dai Balance of Deployer: %s", vm.toString(vat.dai(deployer)));

        vm.stopBroadcast();
    }
}

contract WithdrawDaiFromGate is Script {
    uint256 private deployerPrivateKey;

    VatAbstract public vat = VatAbstract(0xB966002DDAa2Baf48369f5015329750019736031);
    address public deployer;
    address public gate;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 daibal_gate = vat.dai(gate); // dai balance of gate
        Gate1(gate).withdrawDai(deployer, daibal_gate); // withdraw dai from gate to deployer

        console.log("Dai Balance of Gate: %s", vm.toString(vat.dai(gate)));
        console.log("Dai Balance of Deployer: %s", vm.toString(vat.dai(deployer)));

        vm.stopBroadcast();
    }
}

contract SetApprovedTotal is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public gate;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);
        uint256 RAD = 10**45;
        uint256 approved_total = 999*RAD; // NOTE: set approved total
        
        console.log("Old Approved Total: %s", vm.toString(Gate1(gate).approvedTotal()));
        
        Gate1(gate).file(bytes32("approvedtotal"), approved_total);
        console.log("New Approved Total: %s", vm.toString(Gate1(gate).approvedTotal()));

        vm.stopBroadcast();
    }
}

contract SetWithdrawAfter is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public gate;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        uint256 withdraw_after = 1665495510; // NOTE: set withdraw after timestamp
        
        console.log("Old Withdraw After Timestamp: %s", vm.toString(Gate1(gate).withdrawAfter()));
        
        Gate1(gate).file(bytes32("withdrawafter"), withdraw_after);
        console.log("New Withdraw After Timestamp: %s", vm.toString(Gate1(gate).withdrawAfter()));

        vm.stopBroadcast();
    }
}

contract GateRelyAddr is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public gate;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address addr = address(0xdead); // NOTE: set address
        
        console.log("Old Status: %s", vm.toString(Gate1(gate).wards(addr)));
        
        Gate1(gate).rely(addr);
        console.log("New Status: %s", vm.toString(Gate1(gate).wards(addr)));

        vm.stopBroadcast();
    }
}

contract GateDenyAddr is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public gate;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address addr = address(0xdead); // NOTE: set address
        
        console.log("Old Status: %s", vm.toString(Gate1(gate).wards(addr)));
        
        Gate1(gate).deny(addr);
        console.log("New Status: %s", vm.toString(Gate1(gate).wards(addr)));

        vm.stopBroadcast();
    }
}

contract KissAddr is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public gate;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address addr = address(0xdead); // NOTE: set address
        
        console.log("Old Status: %s", vm.toString(Gate1(gate).bud(addr)));
        
        Gate1(gate).kiss(addr);
        console.log("New Status: %s", vm.toString(Gate1(gate).bud(addr)));

        vm.stopBroadcast();
    }
}

contract DissAddr is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public gate;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        gate = vm.envAddress("GATE"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address addr = address(0xdead); // NOTE: set address
        
        console.log("Old Status: %s", vm.toString(Gate1(gate).bud(addr)));
        
        Gate1(gate).diss(addr);
        console.log("New Status: %s", vm.toString(Gate1(gate).bud(addr)));

        vm.stopBroadcast();
    }
}

contract CFMRelyAddr is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public cfm;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        cfm = vm.envAddress("CFM"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address addr = address(0xdead); // NOTE: set address
        
        console.log("Old Status: %s", vm.toString(ClaimFee(cfm).wards(addr)));
        
        ClaimFee(cfm).rely(addr);
        console.log("New Status: %s", vm.toString(ClaimFee(cfm).wards(addr)));

        vm.stopBroadcast();
    }
}

contract CFMDenyAddr is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public cfm;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        cfm = vm.envAddress("CFM"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        address addr = address(0xdead); // NOTE: set address
        
        console.log("Old Status: %s", vm.toString(ClaimFee(cfm).wards(addr)));
        
        ClaimFee(cfm).deny(addr);
        console.log("New Status: %s", vm.toString(ClaimFee(cfm).wards(addr)));

        vm.stopBroadcast();
    }
}

contract InitializeIlk is Script {
    uint256 private deployerPrivateKey;

    address public deployer;
    address public cfm;

    function setUp() public {
        deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.envAddress("ETH_FROM");
        cfm = vm.envAddress("CFM"); // NOTE: set correct address in .env file
    }

    function run() public {
        vm.startBroadcast(deployerPrivateKey);

        string memory ilk = "ETH-A";
        bytes32 init_ilk = bytes32(bytes(ilk));

        ClaimFee(cfm).initializeIlk(init_ilk);
        console.log("%s Initialized: %s", ilk, vm.toString(ClaimFee(cfm).initializedIlks(init_ilk)));

        vm.stopBroadcast();
    }
}