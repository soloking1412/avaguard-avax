# AvaGuard

[![CI](https://github.com/soloking1412/avaguard-avax/actions/workflows/ci.yml/badge.svg)](https://github.com/soloking1412/avaguard-avax/actions/workflows/ci.yml)

Programmatic circuit breakers and invariant monitoring for Avalanche L1s.

**Live on Avalanche Fuji** — verified contracts and a real on-chain [proof-of-pause transaction](https://testnet.snowtrace.io/tx/0x10b2f85eae3666608d83eda70724d6c0068b65c9114cc1cd0fb6988b74b5edbd). See [Live deployment](#live-deployment).

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

## Architecture

```
         Protocol contract
                |  checkAndPause(tvl, mint, deviationBps)
                v
   +------------------------+  events   +---------------------------+
   | AvaGuardCircuitBreaker |<----------|  Guardian Agent (Node.js) |
   |   paused / thresholds  |           |  event sub + poll fallback |
   +-----------+------------+           +-------------+-------------+
               | paused == true                       | alert
               v                                      v
        Protocol halts                        Telegram / webhook

   Developer --> avaguard-cli --> reads ABI --> <Contract>.invariant.t.sol stubs
```

The on-chain breaker is the source of truth: any protocol gates its state-changing
paths on `breaker.paused()`. The Guardian Agent watches the same contract off-chain and
alerts a human the instant it trips. The CLI generates Foundry fuzz/invariant stubs so
teams can encode their own invariants quickly.

## Live deployment

Deployed and **verified** on **Avalanche Fuji** (chain ID `43113`).

| Contract | Address | Explorer |
|---|---|---|
| `AvaGuardCircuitBreaker` | `0x6110d2E081219a50c13E2bbCF4aD84725dEF1A5a` | [Snowtrace ✅](https://testnet.snowtrace.io/address/0x6110d2E081219a50c13E2bbCF4aD84725dEF1A5a) |
| `MockVault` | `0x6394B314E3879aA4e02B9174F8697B04189452fc` | [Snowtrace ✅](https://testnet.snowtrace.io/address/0x6394B314E3879aA4e02B9174F8697B04189452fc) |

Owner `0xEb7Db5a60c45b86DFac4d22b540DbC088943f387` · thresholds `maxTVL = 1,000,000 ether`, `maxMintPerBlock = 100,000 ether`, `maxPriceDeviationBps = 500`.

### Proof of pause

A single `MockVault.deposit()` that pushes cumulative TVL one wei past `maxTVL` trips the
breaker on-chain — the vault halts itself, and the **next deposit reverts with `ProtocolHalted()`**.

**Trigger transaction:** [`0x10b2f85e…b74b5edbd`](https://testnet.snowtrace.io/tx/0x10b2f85eae3666608d83eda70724d6c0068b65c9114cc1cd0fb6988b74b5edbd)

- In that transaction `paused()` flipped `false → true` and the breaker emitted `Paused("TVL threshold exceeded")`.
- Confirm the live state yourself:

```bash
cast call 0x6110d2E081219a50c13E2bbCF4aD84725dEF1A5a "paused()(bool)" \
  --rpc-url https://api.avax-test.network/ext/bc/C/rpc
# -> true
```

Reproduce it against your own deployment with the bundled script:

```bash
cd contracts
forge script script/TriggerDemo.s.sol:TriggerDemo --rpc-url fuji --broadcast
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

## Deploy your own

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
