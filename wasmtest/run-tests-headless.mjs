// Runs the WASM test suite under Node, without a browser.
// Usage: node run-tests-headless.mjs (or `make run-tests-headless`)
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import RetrogradeRuntime from "./web/retrograde-runtime.js";

const here = path.dirname(fileURLToPath(import.meta.url));
const wasmPath = path.join(here, "web", "bin", "wasmtest.wasm");

const runtime = new RetrogradeRuntime(wasmPath);
const bytes = fs.readFileSync(wasmPath);
const { instance } = await WebAssembly.instantiate(bytes, {
  env: runtime.imports,
});

runtime.instance = instance;
runtime.memory = instance.exports.memory;

try {
  runtime.startWasmModule();
} catch (e) {
  console.error(e.stack || e);
  process.exit(1);
}
