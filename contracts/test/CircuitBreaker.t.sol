// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {AvaGuardCircuitBreaker} from "../src/AvaGuardCircuitBreaker.sol";
import {MockVault} from "../src/MockVault.sol";

contract CircuitBreakerTest is Test {
    AvaGuardCircuitBreaker breaker;
    MockVault vault;

    address owner = address(this);
    address alice = makeAddr("alice");
    address bob = makeAddr("bob");

    uint256 constant MAX_TVL = 1_000_000 ether;
    uint256 constant MAX_MINT = 100_000 ether;
    uint256 constant MAX_DEVIATION_BPS = 500;

    function setUp() public {
        breaker = new AvaGuardCircuitBreaker(MAX_TVL, MAX_MINT, MAX_DEVIATION_BPS);
        vault = new MockVault(address(breaker));
    }

    // ─── constructor ──────────────────────────────────────────────────────────

    function test_constructorSetsOwner() public view {
        assertEq(breaker.owner(), owner);
    }

    function test_constructorSetsThresholds() public view {
        assertEq(breaker.maxTVL(), MAX_TVL);
        assertEq(breaker.maxMintPerBlock(), MAX_MINT);
        assertEq(breaker.maxPriceDeviationBps(), MAX_DEVIATION_BPS);
    }

    function test_constructorRevertsOnZeroMaxTVL() public {
        vm.expectRevert(AvaGuardCircuitBreaker.ZeroMaxTVL.selector);
        new AvaGuardCircuitBreaker(0, MAX_MINT, MAX_DEVIATION_BPS);
    }

    function test_initiallyNotPaused() public view {
        assertFalse(breaker.paused());
    }

    // ─── checkAndPause ────────────────────────────────────────────────────────

    function test_noBreachDoesNotPause() public {
        breaker.checkAndPause(MAX_TVL - 1, MAX_MINT - 1, MAX_DEVIATION_BPS - 1);
        assertFalse(breaker.paused());
    }

    function test_pausesOnTVLExceeded() public {
        vm.expectEmit(false, false, false, false);
        emit AvaGuardCircuitBreaker.Paused("TVL threshold exceeded");
        breaker.checkAndPause(MAX_TVL + 1, 0, 0);
        assertTrue(breaker.paused());
    }

    function test_pausesOnMintExceeded() public {
        breaker.checkAndPause(0, MAX_MINT + 1, 0);
        assertTrue(breaker.paused());
    }

    function test_pausesOnDeviationExceeded() public {
        breaker.checkAndPause(0, 0, MAX_DEVIATION_BPS + 1);
        assertTrue(breaker.paused());
    }

    function test_exactThresholdDoesNotPause() public {
        breaker.checkAndPause(MAX_TVL, MAX_MINT, MAX_DEVIATION_BPS);
        assertFalse(breaker.paused());
    }

    function test_pausedStateIdempotent() public {
        breaker.checkAndPause(MAX_TVL + 1, 0, 0);
        assertTrue(breaker.paused());
        // calling again while already paused should not revert
        breaker.checkAndPause(MAX_TVL + 1, 0, 0);
        assertTrue(breaker.paused());
    }

    // ─── unpause ──────────────────────────────────────────────────────────────

    function test_ownerCanUnpause() public {
        breaker.checkAndPause(MAX_TVL + 1, 0, 0);
        breaker.unpause();
        assertFalse(breaker.paused());
    }

    function test_nonOwnerCannotUnpause() public {
        breaker.checkAndPause(MAX_TVL + 1, 0, 0);
        vm.prank(alice);
        vm.expectRevert(AvaGuardCircuitBreaker.NotOwner.selector);
        breaker.unpause();
    }

    // ─── updateThresholds ─────────────────────────────────────────────────────

    function test_ownerUpdatesThresholds() public {
        breaker.updateThresholds(2_000_000 ether, 200_000 ether, 1000);
        assertEq(breaker.maxTVL(), 2_000_000 ether);
        assertEq(breaker.maxMintPerBlock(), 200_000 ether);
        assertEq(breaker.maxPriceDeviationBps(), 1000);
    }

    function test_nonOwnerCannotUpdateThresholds() public {
        vm.prank(alice);
        vm.expectRevert(AvaGuardCircuitBreaker.NotOwner.selector);
        breaker.updateThresholds(1, 1, 1);
    }

    function test_updateThresholdsRevertsOnZeroMaxTVL() public {
        vm.expectRevert(AvaGuardCircuitBreaker.ZeroMaxTVL.selector);
        breaker.updateThresholds(0, MAX_MINT, MAX_DEVIATION_BPS);
    }

    // ─── transferOwnership ────────────────────────────────────────────────────

    function test_transferOwnership() public {
        breaker.transferOwnership(alice);
        assertEq(breaker.owner(), alice);
    }

    function test_nonOwnerCannotTransferOwnership() public {
        vm.prank(alice);
        vm.expectRevert(AvaGuardCircuitBreaker.NotOwner.selector);
        breaker.transferOwnership(bob);
    }

    // ─── MockVault integration ────────────────────────────────────────────────

    function test_vaultDepositWorksWhenNotPaused() public {
        vault.deposit(1000 ether);
        assertEq(vault.totalDeposits(), 1000 ether);
    }

    function test_vaultDepositRevertsWhenPaused() public {
        breaker.checkAndPause(MAX_TVL + 1, 0, 0);
        vm.expectRevert(MockVault.ProtocolHalted.selector);
        vault.deposit(1 ether);
    }

    function test_vaultDepositTriggersBreaker() public {
        // deposit above TVL threshold — vault self-checks and breaker pauses
        vault.deposit(MAX_TVL + 1);
        assertTrue(breaker.paused());
    }

    function test_vaultWithdrawRevertsWhenPaused() public {
        vault.deposit(500 ether);
        breaker.checkAndPause(MAX_TVL + 1, 0, 0);
        vm.expectRevert(MockVault.ProtocolHalted.selector);
        vault.withdraw(100 ether);
    }

    function test_vaultResumeAfterUnpause() public {
        vault.deposit(MAX_TVL + 1);
        assertTrue(breaker.paused());

        // raise all thresholds and unpause
        breaker.updateThresholds(MAX_TVL * 10, MAX_MINT * 10, MAX_DEVIATION_BPS);
        breaker.unpause();

        // new block resets the per-block mint counter in MockVault
        vm.roll(block.number + 1);

        vault.deposit(1 ether);
        assertFalse(breaker.paused());
    }

    // ─── fuzz ─────────────────────────────────────────────────────────────────

    function testFuzz_alwaysPausesWhenTVLBreached(uint256 tvl) public {
        vm.assume(tvl > MAX_TVL);
        breaker.checkAndPause(tvl, 0, 0);
        assertTrue(breaker.paused());
    }

    function testFuzz_alwaysPausesWhenMintBreached(uint256 mint) public {
        vm.assume(mint > MAX_MINT);
        breaker.checkAndPause(0, mint, 0);
        assertTrue(breaker.paused());
    }

    function testFuzz_alwaysPausesWhenDeviationBreached(uint256 dev) public {
        vm.assume(dev > MAX_DEVIATION_BPS);
        breaker.checkAndPause(0, 0, dev);
        assertTrue(breaker.paused());
    }

    function testFuzz_neverPausesWhenAllUnderThreshold(
        uint256 tvl,
        uint256 mint,
        uint256 dev
    ) public {
        tvl = bound(tvl, 0, MAX_TVL);
        mint = bound(mint, 0, MAX_MINT);
        dev = bound(dev, 0, MAX_DEVIATION_BPS);
        breaker.checkAndPause(tvl, mint, dev);
        assertFalse(breaker.paused());
    }

    function testFuzz_onlyOwnerCanUnpause(address caller) public {
        vm.assume(caller != owner);
        breaker.checkAndPause(MAX_TVL + 1, 0, 0);
        vm.prank(caller);
        vm.expectRevert(AvaGuardCircuitBreaker.NotOwner.selector);
        breaker.unpause();
    }
}

// ─── invariant handler ────────────────────────────────────────────────────────

contract BreakerHandler is Test {
    AvaGuardCircuitBreaker public breaker;
    address public owner;

    bool public everPaused;

    constructor(AvaGuardCircuitBreaker _breaker) {
        breaker = _breaker;
        owner = _breaker.owner();
    }

    function triggerCheck(uint256 tvl, uint256 mint, uint256 dev) external {
        tvl = bound(tvl, 0, type(uint128).max);
        mint = bound(mint, 0, type(uint128).max);
        dev = bound(dev, 0, 10_000);
        breaker.checkAndPause(tvl, mint, dev);
        if (breaker.paused()) everPaused = true;
    }

    function doUnpause() external {
        vm.prank(owner);
        if (breaker.paused()) breaker.unpause();
    }

    function tryUnpauseAsStranger(address stranger) external {
        vm.assume(stranger != owner);
        if (breaker.paused()) {
            vm.prank(stranger);
            try breaker.unpause() {
                // should never succeed
                assert(false);
            } catch {}
        }
    }
}

contract CircuitBreakerInvariantTest is Test {
    AvaGuardCircuitBreaker breaker;
    BreakerHandler handler;

    function setUp() public {
        breaker = new AvaGuardCircuitBreaker(
            1_000_000 ether,
            100_000 ether,
            500
        );
        handler = new BreakerHandler(breaker);

        targetContract(address(handler));
    }

    function invariant_pauseOnlyByBreaches() public view {
        if (breaker.paused()) {
            assertTrue(handler.everPaused());
        }
    }

    function invariant_ownerNeverChangesUnexpectedly() public view {
        assertEq(breaker.owner(), address(this));
    }

    function invariant_thresholdsNeverZeroTVL() public view {
        assertGt(breaker.maxTVL(), 0);
    }
}
