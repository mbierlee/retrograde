import RetrogradeRuntime from "./retrograde-runtime.js";

document.addEventListener("DOMContentLoaded", function () {
  const engineModule = new RetrogradeRuntime("/bin/wasmtest.wasm");
  engineModule.initWasmModule().then(() => {
    engineModule.startWasmModule();
  });
});
