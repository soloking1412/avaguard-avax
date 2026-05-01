"use strict";

const { ethers } = require("ethers");

const ABI = [
    "event Paused(string reason)",
    "event Unpaused()",
    "event InvariantChecked(bool passed, uint256 tvl, uint256 mint, uint256 deviationBps)",
    "function paused() view returns (bool)",
    "function maxTVL() view returns (uint256)",
    "function maxMintPerBlock() view returns (uint256)",
    "function maxPriceDeviationBps() view returns (uint256)",
];

class BreakerMonitor {
    constructor({ rpcUrl, contractAddress, notifier, pollIntervalMs }) {
        this.provider = new ethers.JsonRpcProvider(rpcUrl);
        this.contract = new ethers.Contract(contractAddress, ABI, this.provider);
        this.contractAddress = contractAddress;
        this.notifier = notifier;
        this.pollIntervalMs = pollIntervalMs;
        this.pollTimer = null;
        this.wasAlreadyPaused = false;
    }

    async start() {
        console.log(`AvaGuard monitor started`);
        console.log(`Contract: ${this.contractAddress}`);
        console.log(`Poll interval: ${this.pollIntervalMs}ms`);

        this._attachEventListeners();
        await this._poll();
        this.pollTimer = setInterval(() => this._poll(), this.pollIntervalMs);
    }

    stop() {
        clearInterval(this.pollTimer);
        this.provider.removeAllListeners();
        console.log("AvaGuard monitor stopped");
    }

    _attachEventListeners() {
        this.contract.on("Paused", async (reason, event) => {
            console.log(`[event] Paused — reason: ${reason}`);
            const block = await event.getBlock();
            await this.notifier.send(
                this.notifier.formatPauseAlert({
                    reason,
                    address: this.contractAddress,
                    chain: `block #${block.number}`,
                })
            );
        });

        this.contract.on("Unpaused", () => {
            console.log(`[event] Unpaused`);
            this.wasAlreadyPaused = false;
        });

        this.contract.on("InvariantChecked", (passed, tvl, mint, deviationBps) => {
            if (!passed) {
                console.log(
                    `[event] InvariantChecked — FAILED tvl=${tvl} mint=${mint} deviation=${deviationBps}bps`
                );
            }
        });
    }

    async _poll() {
        try {
            const [isPaused, blockNumber] = await Promise.all([
                this.contract.paused(),
                this.provider.getBlockNumber(),
            ]);

            if (isPaused && !this.wasAlreadyPaused) {
                this.wasAlreadyPaused = true;
                console.log(`[poll] Circuit breaker is PAUSED at block ${blockNumber}`);
                await this.notifier.send(
                    this.notifier.formatHeartbeat({
                        address: this.contractAddress,
                        isPaused: true,
                        blockNumber,
                    })
                );
            } else if (!isPaused) {
                this.wasAlreadyPaused = false;
                console.log(`[poll] block=${blockNumber} status=ACTIVE`);
            }
        } catch (err) {
            console.error(`[poll] Error: ${err.message}`);
        }
    }
}

module.exports = { BreakerMonitor };
