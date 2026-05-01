# AvaGuard

Programmatic circuit breakers and invariant monitoring for Avalanche L1s.

## Overview

AvaGuard gives DeFi protocols and RWA deployments on Avalanche a shared safety primitive: an on-chain circuit breaker that halts a protocol the moment a defined invariant is breached, paired with an off-chain Guardian Agent that fires real-time alerts and a CLI that generates Foundry fuzz/invariant test stubs from any ABI.

## Repository structure

```
avaguard-avax/
├── contracts/              Foundry project
│   ├── src/
│   │   ├── AvaGuardCircuitBreaker.sol
│   │   └── MockVault.sol
│   ├── test/
│   │   └── CircuitBreaker.t.sol   (30 tests: unit + fuzz + invariant)
│   └── script/
│       └── Deploy.s.sol
├── agent/                  Off-chain Guardian Agent (Node.js)
│   └── src/
│       ├── index.js
│       ├── config.js
│       ├── monitor.js
│       └── notifier.js
└── cli/                    avaguard-cli (Node.js)
    └── src/
        ├── cli.js
        └── generator.js
```

## Contracts

### AvaGuardCircuitBreaker

Tracks three protocol thresholds:

| Parameter | Description |
|---|---|
| `maxTVL` | Max total value locked (in wei) |
| `maxMintPerBlock` | Max tokens mintable per block |
| `maxPriceDeviationBps` | Max price deviation in basis points |

Any single breach pauses the protocol. Only the owner can unpause. Thresholds are updatable by the owner before unpausing.

```solidity
// integrate into your protocol
modifier protocolSafe() {
    if (breaker.paused()) revert ProtocolHalted();
    _;
}
```

### MockVault

A reference integration showing how a protocol hooks into the circuit breaker. On each deposit, it calls `breaker.checkAndPause(totalTVL, mintedThisBlock, 0)`. The next deposit after a pause reverts immediately via the `guardedByBreaker` modifier.

## Tests

```bash
cd contracts
forge test -vv
```

30 tests — unit, fuzz (1000 runs), invariant (200 runs × 15 depth).

## Guardian Agent

Monitors a deployed `AvaGuardCircuitBreaker` contract via both event subscription and polling fallback. Sends Telegram alerts when the breaker trips.

**Setup:**

```bash
cd agent
npm install
cp .env.example .env
# fill in CONTRACT_ADDRESS, TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID
npm start
```

**Tests:**

```bash
npm test
```

## CLI — avaguard-cli

Generates Foundry fuzz and invariant test stubs from a contract ABI.

**Usage:**

```bash
# from a Foundry artifact (Forge output format)
node cli/src/cli.js contracts/out/MyContract.sol/MyContract.json MyContract

# from a bare ABI file
node cli/src/cli.js abi.json MyContract
```

Outputs `<ContractName>.invariant.t.sol` in the current directory with stubbed `testFuzz_*` and `invariant_*` functions for every mutable function in the ABI.

**Tests:**

```bash
cd cli && npm test
```

## Fuji deployment

```bash
cd contracts
cp .env.example .env
# set PRIVATE_KEY, FUJI_RPC_URL, SNOWTRACE_API_KEY

forge script script/Deploy.s.sol \
  --rpc-url fuji \
  --broadcast \
  --verify
```

Environment variables accepted by the deploy script:

| Variable | Default |
|---|---|
| `MAX_TVL` | `1_000_000 ether` |
| `MAX_MINT_PER_BLOCK` | `100_000 ether` |
| `MAX_PRICE_DEVIATION_BPS` | `500` (5%) |
