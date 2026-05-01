// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AvaGuardCircuitBreaker} from "./AvaGuardCircuitBreaker.sol";

contract MockVault {
    AvaGuardCircuitBreaker public immutable breaker;

    uint256 public totalDeposits;
    uint256 public mintedThisBlock;
    uint256 private _lastMintBlock;

    mapping(address => uint256) public balances;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);

    error ProtocolHalted();
    error InsufficientBalance();

    modifier guardedByBreaker() {
        if (breaker.paused()) revert ProtocolHalted();
        _;
    }

    constructor(address _breaker) {
        breaker = AvaGuardCircuitBreaker(_breaker);
    }

    function deposit(uint256 amount) external guardedByBreaker {
        _trackMint(amount);
        balances[msg.sender] += amount;
        totalDeposits += amount;

        breaker.checkAndPause(totalDeposits, mintedThisBlock, 0);

        emit Deposit(msg.sender, amount);
    }

    function withdraw(uint256 amount) external guardedByBreaker {
        if (balances[msg.sender] < amount) revert InsufficientBalance();
        balances[msg.sender] -= amount;
        totalDeposits -= amount;
        emit Withdraw(msg.sender, amount);
    }

    function _trackMint(uint256 amount) internal {
        if (block.number != _lastMintBlock) {
            mintedThisBlock = 0;
            _lastMintBlock = block.number;
        }
        mintedThisBlock += amount;
    }
}
