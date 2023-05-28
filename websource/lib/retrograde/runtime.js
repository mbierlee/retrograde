import WasmModule from "../wasm.js";
import stdio from "./std/stdio.js";

export default class EngineRuntimeModule extends WasmModule {
  constructor() {
    super("/wasm/retrograde.wasm", {
      writeln: (msgLength, msgPtr) => {
        const message = this.getString(msgPtr, msgLength);
        stdio.writeln(message);
      },
    });
  }
}

export function startEngine() {
  const engineModule = new EngineRuntimeModule();
  engineModule.start();
  return engineModule;
}
