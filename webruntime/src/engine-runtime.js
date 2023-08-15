import WasmModule from "./wasm.js";

export default class EngineRuntimeModule extends WasmModule {
  glContext;

  displayWidth;
  displayHeight;
  viewportNeedsReset = false;

  shaderPrograms = [];
  buffers = [];
  vertextArrayObjects = [];

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
        console.log(String.fromCharCode(value));
      },
      writelnWChar: (value) => {
        console.log(String.fromCharCode(value));
      },
      writelnDChar: (value) => {
        console.log(String.fromCharCode(value));
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
        console.error(String.fromCharCode(value));
      },
      writeErrLnWChar: (value) => {
        console.error(String.fromCharCode(value));
      },
      writeErrLnDChar: (value) => {
        console.error(String.fromCharCode(value));
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

      resizeCanvasToDisplaySize: () => {
        const canvas = this.glContext.canvas;
        const needResize =
          canvas.width !== this.displayWidth ||
          canvas.height !== this.displayHeight;

        if (needResize) {
          canvas.width = this.displayWidth;
          canvas.height = this.displayHeight;
          this.glContext.viewport(0, 0, canvas.width, canvas.height);
        }
      },

      glCreateBuffer: () => {
        const buffer = this.glContext.createBuffer();
        this.buffers.push(buffer);
        return this.buffers.length;
      },

      glBindArrayBuffer: (buffer) => {
        const bufferObject = this.getGlObject(this.buffers, buffer, "Buffer");
        this.glContext.bindBuffer(this.glContext.ARRAY_BUFFER, bufferObject);
      },

      glArrayBufferData: (length, pointer) => {
        const bufferData = this.getFloat32Array(pointer, length);
        this.glContext.bufferData(
          this.glContext.ARRAY_BUFFER,
          bufferData,
          this.glContext.STATIC_DRAW
        );
      },

      glCreateVertexArray: () => {
        const vertextArrayObject = this.glContext.createVertexArray();
        this.vertextArrayObjects.push(vertextArrayObject);
        return this.vertextArrayObjects.length;
      },

      glBindVertexArray: (vertextArrayObjectName) => {
        const vertextArrayObject = this.getGlObject(
          this.vertextArrayObjects,
          vertextArrayObjectName,
          "Vertex Array Object"
        );

        this.glContext.bindVertexArray(vertextArrayObject);
      },

      glEnableVertexAttribArray: (index) => {
        this.glContext.enableVertexAttribArray(index);
      },

      glVertexAttribPointer: (
        index,
        size,
        type,
        normalized,
        stride,
        offset
      ) => {
        this.glContext.vertexAttribPointer(
          index,
          size,
          type,
          normalized,
          stride,
          offset
        );
      },

      glClearColor: (red, green, blue, alpha) => {
        this.glContext.clearColor(red, green, blue, alpha);
      },

      glClear: (mask) => {
        this.glContext.clear(mask);
      },

      glUseProgram: (program) => {
        const programObject = this.getGlObject(
          this.shaderPrograms,
          program,
          "Shader Program"
        );

        this.glContext.useProgram(programObject);
      },

      glDrawArrays: (mode, first, count) => {
        this.glContext.drawArrays(mode, first, count);
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

  getGlObject(list, name, type) {
    const index = name - 1;
    if (index > list.length - 1) {
      throw new Error(`${type} ${name} does not exist`);
    }

    return list[index];
  }
}
