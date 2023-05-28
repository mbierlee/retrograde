import EngineRuntimeModule from "./src/engine-runtime.js";

document.addEventListener("DOMContentLoaded", function () {
  const engineModule = new EngineRuntimeModule();
  engineModule.start();
});
