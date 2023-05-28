import WasmModule from "./wasm.js";

export default class EngineRuntimeModule extends WasmModule {
  constructor() {
    super("./wasm/retrograde-app.wasm", {
      writeln: (msgLength, msgPtr) => {
        console.log(this.getString(msgPtr, msgLength));
      },
      __assert: (assertionMsgPtr, srcFilePtr, srcLineNumber) => {
        const assertionMessage = this.getCString(assertionMsgPtr);
        const srcFile = this.getCString(srcFilePtr);
        console.error(
          `Assertion error: ${assertionMessage}\n    at ${srcFile}:${srcLineNumber}`
        );
      },
    });
  }
}
