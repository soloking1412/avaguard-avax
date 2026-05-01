"use strict";

const { describe, it, before, after, mock } = require("node:test");
const assert = require("node:assert/strict");
const nock = require("nock");

const { TelegramNotifier } = require("../notifier");

const BOT_TOKEN = "testtoken123";
const CHAT_ID = "-100123456";
const API_BASE = "https://api.telegram.org";

describe("TelegramNotifier", () => {
    before(() => nock.disableNetConnect());
    after(() => nock.enableNetConnect());

    it("sends a message via Telegram API", async () => {
        const scope = nock(API_BASE)
            .post(`/bot${BOT_TOKEN}/sendMessage`, (body) => {
                return body.chat_id === CHAT_ID && typeof body.text === "string";
            })
            .reply(200, { ok: true });

        const notifier = new TelegramNotifier({ botToken: BOT_TOKEN, chatId: CHAT_ID });
        await notifier.send("test alert");

        assert.ok(scope.isDone(), "Telegram API was not called");
    });

    it("respects cooldown and skips second send", async () => {
        let callCount = 0;

        nock(API_BASE)
            .post(`/bot${BOT_TOKEN}/sendMessage`)
            .twice()
            .reply(200, () => {
                callCount++;
                return { ok: true };
            });

        const notifier = new TelegramNotifier({ botToken: BOT_TOKEN, chatId: CHAT_ID });
        notifier.setCooldown(60_000);

        await notifier.send("first");
        await notifier.send("second — should be suppressed");

        assert.equal(callCount, 1, "Expected exactly one API call due to cooldown");
        nock.cleanAll();
    });

    it("formats pause alert with all fields", () => {
        const notifier = new TelegramNotifier({ botToken: BOT_TOKEN, chatId: CHAT_ID });
        const msg = notifier.formatPauseAlert({
            reason: "TVL threshold exceeded",
            address: "0xabc",
            chain: "block #100",
        });

        assert.ok(msg.includes("PAUSED"));
        assert.ok(msg.includes("TVL threshold exceeded"));
        assert.ok(msg.includes("0xabc"));
    });

    it("formats heartbeat for active state", () => {
        const notifier = new TelegramNotifier({ botToken: BOT_TOKEN, chatId: CHAT_ID });
        const msg = notifier.formatHeartbeat({
            address: "0xdef",
            isPaused: false,
            blockNumber: 999,
        });

        assert.ok(msg.includes("ACTIVE"));
        assert.ok(msg.includes("999"));
    });

    it("formats heartbeat for paused state", () => {
        const notifier = new TelegramNotifier({ botToken: BOT_TOKEN, chatId: CHAT_ID });
        const msg = notifier.formatHeartbeat({
            address: "0xdef",
            isPaused: true,
            blockNumber: 1000,
        });

        assert.ok(msg.includes("PAUSED"));
    });
});
