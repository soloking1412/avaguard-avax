"use strict";

const config = require("./config");
const { TelegramNotifier } = require("./notifier");
const { BreakerMonitor } = require("./monitor");

async function main() {
    const notifier = new TelegramNotifier(config.telegram);
    notifier.setCooldown(config.alertCooldownMs);

    const monitor = new BreakerMonitor({
        rpcUrl: config.rpcUrl,
        contractAddress: config.contractAddress,
        notifier,
        pollIntervalMs: config.pollIntervalMs,
    });

    process.on("SIGINT", () => {
        monitor.stop();
        process.exit(0);
    });

    process.on("SIGTERM", () => {
        monitor.stop();
        process.exit(0);
    });

    await monitor.start();
}

main().catch((err) => {
    console.error("Fatal:", err.message);
    process.exit(1);
});
