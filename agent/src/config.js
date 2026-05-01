"use strict";

require("dotenv").config();

function requireEnv(name) {
    const val = process.env[name];
    if (!val) throw new Error(`Missing required env var: ${name}`);
    return val;
}

module.exports = {
    rpcUrl: process.env.RPC_URL || "https://api.avax-test.network/ext/bc/C/rpc",
    contractAddress: requireEnv("CONTRACT_ADDRESS"),
    telegram: {
        botToken: requireEnv("TELEGRAM_BOT_TOKEN"),
        chatId: requireEnv("TELEGRAM_CHAT_ID"),
    },
    pollIntervalMs: parseInt(process.env.POLL_INTERVAL_MS || "30000", 10),
    alertCooldownMs: parseInt(process.env.ALERT_COOLDOWN_MS || "300000", 10),
};
