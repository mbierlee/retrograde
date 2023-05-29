import EngineRuntimeModule from "./src/engine-runtime.js";

document.addEventListener("DOMContentLoaded", function () {
  const engineModule = new EngineRuntimeModule();
  engineModule.init().then(() => {
    engineModule.start();

    function runLoop(elapsedTimeMs) {
      engineModule.executeEngineLoopCycle(elapsedTimeMs);
      requestAnimationFrame(runLoop);
    }

    runLoop(0);
  });
});
