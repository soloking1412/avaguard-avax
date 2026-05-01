"use strict";

const axios = require("axios");

class TelegramNotifier {
    constructor({ botToken, chatId }) {
        this.botToken = botToken;
        this.chatId = chatId;
        this.lastAlertAt = 0;
        this.cooldownMs = 0;
    }

    setCooldown(ms) {
        this.cooldownMs = ms;
    }

    async send(message) {
        const now = Date.now();
        if (now - this.lastAlertAt < this.cooldownMs) {
            return;
        }

        await axios.post(
            `https://api.telegram.org/bot${this.botToken}/sendMessage`,
            {
                chat_id: this.chatId,
                text: message,
                parse_mode: "HTML",
            }
        );

        this.lastAlertAt = now;
    }

    formatPauseAlert({ reason, address, chain }) {
        return [
            `<b>🚨 AvaGuard Alert</b>`,
            ``,
            `<b>Status:</b> PAUSED`,
            `<b>Reason:</b> ${reason}`,
            `<b>Contract:</b> <code>${address}</code>`,
            `<b>Chain:</b> ${chain}`,
            `<b>Time:</b> ${new Date().toISOString()}`,
            ``,
            `Manual review required before unpausing.`,
        ].join("\n");
    }

    formatHeartbeat({ address, isPaused, blockNumber }) {
        const status = isPaused ? "PAUSED" : "ACTIVE";
        return [
            `<b>AvaGuard Heartbeat</b>`,
            `<b>Status:</b> ${status}`,
            `<b>Contract:</b> <code>${address}</code>`,
            `<b>Block:</b> ${blockNumber}`,
            `<b>Time:</b> ${new Date().toISOString()}`,
        ].join("\n");
    }
}

module.exports = { TelegramNotifier };
