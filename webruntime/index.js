import EngineRuntimeModule from "./src/engine-runtime.js";

document.addEventListener("DOMContentLoaded", function () {
  const engineModule = new EngineRuntimeModule();

  const canvas = document.querySelector("#renderArea");
  engineModule.glContext = canvas.getContext("webgl2");
  if (!engineModule.glContext) {
    console.error("Unable to initialize WebGL 2 context");
    return;
  }

  function onResize(entries) {
    for (const entry of entries) {
      let width;
      let height;
      let dpr = window.devicePixelRatio;
      
      if (entry.devicePixelContentBoxSize) {
        width = entry.devicePixelContentBoxSize[0].inlineSize;
        height = entry.devicePixelContentBoxSize[0].blockSize;
        dpr = 1;
      } else if (entry.contentBoxSize) {
        if (entry.contentBoxSize[0]) {
          width = entry.contentBoxSize[0].inlineSize;
          height = entry.contentBoxSize[0].blockSize;
        } else {
          width = entry.contentBoxSize.inlineSize;
          height = entry.contentBoxSize.blockSize;
        }
      } else {
        width = entry.contentRect.width;
        height = entry.contentRect.height;
      }

      engineModule.displayWidth = Math.round(width * dpr);
      engineModule.displayHeight = Math.round(height * dpr);
    }
  }

  const resizeObserver = new ResizeObserver(onResize);
  try {
    resizeObserver.observe(canvas, { box: "device-pixel-content-box" });
  } catch (ex) {
    resizeObserver.observe(canvas, { box: "content-box" });
  }

  engineModule.init().then(() => {
    engineModule.start();
    engineModule.initEngine();

    function runLoop(elapsedTimeMs) {
      engineModule.executeEngineLoopCycle(elapsedTimeMs);
      requestAnimationFrame(runLoop);
    }

    runLoop(0);
  });
});
