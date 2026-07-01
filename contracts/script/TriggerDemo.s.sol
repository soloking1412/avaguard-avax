// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {AvaGuardCircuitBreaker} from "../src/AvaGuardCircuitBreaker.sol";
import {MockVault} from "../src/MockVault.sol";

/// @notice Proof-of-pause demo. Drives a breach through the real product surface
/// (MockVault.deposit) so the on-chain story is: a deposit that pushes TVL over the
/// cap auto-halts the vault. One non-reverting tx that flips the breaker to paused.
contract TriggerDemo is Script {
    // Defaults to the live Fuji deployment; override via env if needed.
    address constant DEFAULT_BREAKER = 0x6110d2E081219a50c13E2bbCF4aD84725dEF1A5a;
    address constant DEFAULT_VAULT = 0x6394B314E3879aA4e02B9174F8697B04189452fc;

    function run() external {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");

        address breakerAddr = vm.envOr("BREAKER_ADDRESS", DEFAULT_BREAKER);
        address vaultAddr = vm.envOr("VAULT_ADDRESS", DEFAULT_VAULT);

        AvaGuardCircuitBreaker breaker = AvaGuardCircuitBreaker(breakerAddr);
        MockVault vault = MockVault(vaultAddr);

        console.log("Breaker:             ", breakerAddr);
        console.log("Vault:               ", vaultAddr);
        console.log("Paused before:       ", breaker.paused());
        console.log("Vault TVL before:    ", vault.totalDeposits());

        require(!breaker.paused(), "already paused - nothing to demo");

        // Push cumulative deposits one wei past maxTVL to breach the TVL invariant.
        uint256 breachAmount = breaker.maxTVL() + 1 - vault.totalDeposits();
        console.log("Depositing (breach): ", breachAmount);

        vm.startBroadcast(deployerKey);
        vault.deposit(breachAmount);
        vm.stopBroadcast();

        console.log("Paused after:        ", breaker.paused());
        console.log("Vault TVL after:     ", vault.totalDeposits());
        console.log("Circuit breaker triggered via MockVault deposit");
    }
}
