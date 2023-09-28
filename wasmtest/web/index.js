import EngineRuntimeModule from "./lib/engine-runtime.js";

document.addEventListener("DOMContentLoaded", function () {
  const engineModule = new EngineRuntimeModule("/bin/wasmmemtest.wasm");
  engineModule.init().then(() => {
    engineModule.start();
  });
});
