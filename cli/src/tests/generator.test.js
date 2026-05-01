"use strict";

const { describe, it } = require("node:test");
const assert = require("node:assert/strict");
const { generate, parseAbi, mutatableFunctions } = require("../generator");

const SAMPLE_ABI = [
    {
        type: "function",
        name: "deposit",
        stateMutability: "nonpayable",
        inputs: [{ name: "amount", type: "uint256" }],
        outputs: [],
    },
    {
        type: "function",
        name: "withdraw",
        stateMutability: "nonpayable",
        inputs: [{ name: "amount", type: "uint256" }],
        outputs: [],
    },
    {
        type: "function",
        name: "totalSupply",
        stateMutability: "view",
        inputs: [],
        outputs: [{ name: "", type: "uint256" }],
    },
    {
        type: "function",
        name: "pause",
        stateMutability: "nonpayable",
        inputs: [],
        outputs: [],
    },
    {
        type: "event",
        name: "Deposit",
        inputs: [{ name: "amount", type: "uint256", indexed: false }],
    },
];

describe("parseAbi", () => {
    it("accepts a JSON string", () => {
        const result = parseAbi(JSON.stringify(SAMPLE_ABI));
        assert.equal(result.length, SAMPLE_ABI.length);
    });

    it("accepts a plain array", () => {
        const result = parseAbi(SAMPLE_ABI);
        assert.equal(result.length, SAMPLE_ABI.length);
    });

    it("throws on non-array JSON", () => {
        assert.throws(() => parseAbi('{"abi":[]}'), /ABI must be a JSON array/);
    });
});

describe("mutatableFunctions", () => {
    it("excludes view and pure functions", () => {
        const fns = mutatableFunctions(SAMPLE_ABI);
        assert.ok(fns.every((f) => f.stateMutability !== "view"));
        assert.ok(fns.every((f) => f.stateMutability !== "pure"));
    });

    it("excludes events", () => {
        const fns = mutatableFunctions(SAMPLE_ABI);
        assert.ok(fns.every((f) => f.type === "function"));
    });

    it("returns correct count", () => {
        const fns = mutatableFunctions(SAMPLE_ABI);
        assert.equal(fns.length, 3); // deposit, withdraw, pause
    });
});

describe("generate", () => {
    it("outputs valid Solidity pragma", () => {
        const out = generate("MyVault", SAMPLE_ABI);
        assert.ok(out.includes("pragma solidity ^0.8.20;"));
    });

    it("creates interface with all functions", () => {
        const out = generate("MyVault", SAMPLE_ABI);
        assert.ok(out.includes("interface IMyVault"));
        assert.ok(out.includes("function deposit("));
        assert.ok(out.includes("function withdraw("));
        assert.ok(out.includes("function totalSupply("));
    });

    it("creates fuzz test contract", () => {
        const out = generate("MyVault", SAMPLE_ABI);
        assert.ok(out.includes("contract MyVaultFuzzTest"));
        assert.ok(out.includes("testFuzz_deposit"));
        assert.ok(out.includes("testFuzz_withdraw"));
        assert.ok(out.includes("testFuzz_pause"));
    });

    it("creates invariant test contract", () => {
        const out = generate("MyVault", SAMPLE_ABI);
        assert.ok(out.includes("contract MyVaultInvariantTest"));
        assert.ok(out.includes("invariant_deposit_neverBreaksState"));
    });

    it("adds bound() for uint256 fuzz params", () => {
        const out = generate("MyVault", SAMPLE_ABI);
        assert.ok(out.includes("bound(amount,"));
    });

    it("does not add bound() for parameterless functions", () => {
        const out = generate("MyVault", SAMPLE_ABI);
        assert.ok(out.includes("testFuzz_pause()"));
    });

    it("skips view functions from fuzz tests", () => {
        const out = generate("MyVault", SAMPLE_ABI);
        assert.ok(!out.includes("testFuzz_totalSupply"));
    });

    it("handles empty ABI gracefully", () => {
        const out = generate("Empty", []);
        assert.ok(out.includes("contract EmptyFuzzTest"));
    });

    it("uses provided contract name", () => {
        const out = generate("SpecialName", SAMPLE_ABI);
        assert.ok(out.includes("ISpecialName"));
        assert.ok(out.includes("contract SpecialNameFuzzTest"));
    });
});
