import RetrogradeRuntime from "./retrograde-runtime.js";

document.addEventListener("DOMContentLoaded", function () {
  const engineModule = new RetrogradeRuntime("./wasm/retrograde-app.wasm");
  engineModule.eventCapturer = window;
  engineModule.setupCanvas();
  engineModule.initWasmModule().then(() => {
    engineModule.startWasmModule();
    engineModule.initEngine();

    function runLoop(elapsedTimeMs) {
      engineModule.executeEngineLoopCycle(elapsedTimeMs);
      requestAnimationFrame(runLoop);
    }

    runLoop(0);
  });
});
