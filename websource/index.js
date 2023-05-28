import { startEngine } from "./lib/retrograde/runtime.js";

let engineModule;

document.addEventListener("DOMContentLoaded", function () {
  engineModule = startEngine();
});
