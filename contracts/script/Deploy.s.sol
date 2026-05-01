// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AvaGuardCircuitBreaker} from "../src/AvaGuardCircuitBreaker.sol";
import {MockVault} from "../src/MockVault.sol";

contract DeployAvaGuard is Script {
    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        uint256 maxTVL = vm.envOr("MAX_TVL", uint256(1_000_000 ether));
        uint256 maxMint = vm.envOr("MAX_MINT_PER_BLOCK", uint256(100_000 ether));
        uint256 maxDeviationBps = vm.envOr("MAX_PRICE_DEVIATION_BPS", uint256(500));

        vm.startBroadcast(deployerKey);

        AvaGuardCircuitBreaker breaker = new AvaGuardCircuitBreaker(
            maxTVL,
            maxMint,
            maxDeviationBps
        );

        MockVault vault = new MockVault(address(breaker));

        vm.stopBroadcast();

        console.log("Deployer:              ", deployer);
        console.log("AvaGuardCircuitBreaker:", address(breaker));
        console.log("MockVault:             ", address(vault));
        console.log("Max TVL:               ", maxTVL);
        console.log("Max Mint/Block:        ", maxMint);
        console.log("Max Deviation (bps):   ", maxDeviationBps);
    }
}
