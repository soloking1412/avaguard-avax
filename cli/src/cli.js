#!/usr/bin/env node
"use strict";

const fs = require("fs");
const path = require("path");
const { generate, parseAbi } = require("./generator");

const [, , abiPath, contractNameArg] = process.argv;

if (!abiPath || abiPath === "--help" || abiPath === "-h") {
    console.log(`
avaguard — Foundry invariant test generator

Usage:
  avaguard <path-to-abi.json> [ContractName]

Arguments:
  path-to-abi.json  Path to a JSON file containing the contract ABI array
  ContractName      (optional) Override the contract name used in output files
                    Defaults to the filename without extension

Output:
  <ContractName>.invariant.t.sol   written to the current directory

Example:
  avaguard out/ERC20.sol/ERC20.json MyToken
`);
    process.exit(0);
}

if (!fs.existsSync(abiPath)) {
    console.error(`Error: file not found: ${abiPath}`);
    process.exit(1);
}

let raw;
try {
    raw = fs.readFileSync(abiPath, "utf8");
} catch (err) {
    console.error(`Error reading file: ${err.message}`);
    process.exit(1);
}

let parsed;
try {
    parsed = JSON.parse(raw);
} catch {
    console.error("Error: file is not valid JSON");
    process.exit(1);
}

// Support both bare ABI arrays and Foundry artifact format { abi: [...] }
const abi = Array.isArray(parsed) ? parsed : parsed.abi;
if (!Array.isArray(abi)) {
    console.error("Error: could not find an ABI array in the provided file");
    process.exit(1);
}

const contractName =
    contractNameArg || path.basename(abiPath).replace(/\.(json|sol)$/i, "");

let source;
try {
    source = generate(contractName, abi);
} catch (err) {
    console.error(`Error generating tests: ${err.message}`);
    process.exit(1);
}

const outFile = `${contractName}.invariant.t.sol`;
fs.writeFileSync(outFile, source, "utf8");

console.log(`Generated: ${outFile}`);
console.log(`  Fuzz tests and invariant stubs for ${abi.filter((x) => x.type === "function" && x.stateMutability !== "view" && x.stateMutability !== "pure").length} mutable functions`);
