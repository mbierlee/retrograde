import WasmModule from "./wasm.js";

export default class EngineRuntimeModule extends WasmModule {
  glContext;
  shaderPrograms = [];

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
      writelnUlong: (value) => {
        console.log(value);
      },
      writelnLong: (value) => {
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
      writelnWChar: (value) => {
        console.log(value);
      },
      writelnDChar: (value) => {
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
      writeErrLnStr: (msgLength, msgPtr) => {
        console.error(this.getString(msgPtr, msgLength));
      },
      writeErrLnUint: (value) => {
        console.error(value);
      },
      writeErrLnInt: (value) => {
        console.error(value);
      },
      writeErrLnULong: (value) => {
        console.error(value);
      },
      writeErrLnLong: (value) => {
        console.error(value);
      },
      writeErrLnDouble: (value) => {
        console.error(value);
      },
      writeErrLnFloat: (value) => {
        console.error(value);
      },
      writeErrLnChar: (value) => {
        console.error(value);
      },
      writeErrLnWChar: (value) => {
        console.error(value);
      },
      writeErrLnDChar: (value) => {
        console.error(value);
      },
      writeErrLnUbyte: (value) => {
        console.error(value);
      },
      writeErrLnByte: (value) => {
        console.error(value);
      },
      writeErrLnBool: (value) => {
        console.error(value == 1 ? "true" : "false");
      },
      __assert: (assertionMsgPtr, srcFilePtr, srcLineNumber) => {
        const assertionMessage = this.getCString(assertionMsgPtr);
        const srcFile = this.getCString(srcFilePtr);
        console.error(
          `Assertion error: ${assertionMessage}\n    at ${srcFile}:${srcLineNumber}`
        );
      },
      compileShaderProgram: (
        nameLength,
        namePtr,
        vertexShaderLength,
        vertexShaderPtr,
        fragmentShaderLength,
        fragmentShaderPtr
      ) => {
        const name = this.getString(namePtr, nameLength);

        if (!this.glContext) {
          console.error(
            `failed to compile shader program ${name} GL context is not initialized`
          );
        }

        const vertexShaderSource = this.getString(
          vertexShaderPtr,
          vertexShaderLength
        );
        const fragmentShaderSource = this.getString(
          fragmentShaderPtr,
          fragmentShaderLength
        );

        const vertexShader = this.createShader(
          this.glContext,
          this.glContext.VERTEX_SHADER,
          vertexShaderSource
        );

        const fragmentShader = this.createShader(
          this.glContext,
          this.glContext.FRAGMENT_SHADER,
          fragmentShaderSource
        );

        const program = this.createShaderProgram(
          this.glContext,
          vertexShader,
          fragmentShader
        );

        this.shaderPrograms.push(program);
        return this.shaderPrograms.length;
      },
      setViewportFullViewSize: () => {
        const canvas = document.querySelector("#renderArea");
        canvas.width = canvas.clientWidth;
        canvas.height = canvas.clientHeight;
      },
    });
  }

  initEngine() {
    this.instance.exports.initEngine();
  }

  executeEngineLoopCycle(elapsedTimeMs) {
    this.instance.exports.executeEngineLoopCycle(elapsedTimeMs);
  }

  createShader(ctx, type, source) {
    const shader = ctx.createShader(type);
    ctx.shaderSource(shader, source);
    ctx.compileShader(shader);
    if (ctx.getShaderParameter(shader, ctx.COMPILE_STATUS)) {
      return shader;
    }

    console.error(ctx.getShaderInfoLog(shader));
    ctx.deleteShader(shader);
  }

  createShaderProgram(ctx, vertexShader, fragmentShader) {
    const program = ctx.createProgram();
    ctx.attachShader(program, vertexShader);
    ctx.attachShader(program, fragmentShader);
    ctx.linkProgram(program);
    if (ctx.getProgramParameter(program, ctx.LINK_STATUS)) {
      return program;
    }

    console.error(ctx.getProgramInfoLog(program));
    ctx.deleteProgram(program);
  }
}
