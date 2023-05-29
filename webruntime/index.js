import EngineRuntimeModule from "./src/engine-runtime.js";

document.addEventListener("DOMContentLoaded", function () {
  const engineModule = new EngineRuntimeModule();
  engineModule.init().then(() => {
    engineModule.start();

    function runLoop(timestampMs) {
      engineModule.update(timestampMs);
      requestAnimationFrame(runLoop);
    }

    runLoop(0);
  });
});
