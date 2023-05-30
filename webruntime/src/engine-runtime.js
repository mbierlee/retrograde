import WasmModule from "./wasm.js";

export default class EngineRuntimeModule extends WasmModule {
  constructor() {
    super("./wasm/retrograde-app.wasm", {
      writelnStr: (msgLength, msgPtr) => {
        console.log(this.getString(msgPtr, msgLength));
      },
      writelnUint: (value) => {
        console.log(value);
      },
      writelnInt: (value) => {
        console.log(value);
      },
      writelnDouble: (value) => {
        console.log(value);
      },
      writelnFloat: (value) => {
        console.log(value);
      },
      writelnChar: (value) => {
        console.log(value);
      },
      writelnUbyte: (value) => {
        console.log(value);
      },
      writelnByte: (value) => {
        console.log(value);
      },
      writelnBool: (value) => {
        console.log(value == 1 ? "true" : "false");
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

  initEngine() {
    this.instance.exports.initEngine();
  }

  executeEngineLoopCycle(elapsedTimeMs) {
    this.instance.exports.executeEngineLoopCycle(elapsedTimeMs);
  }
}
