import WasmModule from "./wasm.js";

export default class EngineRuntimeModule extends WasmModule {
  glContext;

  displayWidth;
  displayHeight;
  viewportNeedsReset = false;

  shaderPrograms = [];
  buffers = [];
  vertextArrayObjects = [];

  constructor(modulePath) {
    super(modulePath, {
      // STD IO

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
      integralToString: (strPtr, ptrLength, val) => {
        this.writeString(val.toString(), strPtr, ptrLength);
      },
      unsignedIntegralToString: (strPtr, ptrLength, val) => {
        this.writeString(val.toString(), strPtr, ptrLength);
      },
      scalarToString: (strPtr, ptrLength, val) => {
        const numberString = parseFloat(val).toFixed(6).toString();
        this.writeString(numberString, strPtr, ptrLength);
      },

      // Maths

      powf: (base, exponent) => {
        return Math.pow(base, exponent);
      },

      // Sanity

      __assert: (assertionMsgPtr, srcFilePtr, srcLineNumber) => {
        const assertionMessage = this.getCString(assertionMsgPtr);
        const srcFile = this.getCString(srcFilePtr);
        console.error(
          `Assertion error: ${assertionMessage}\n    at ${srcFile}:${srcLineNumber}`
        );
      },

      // GL API

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
          this.setViewport(canvas.width, canvas.height);
        }
      },

      // WebGL2 / GLES3 API

      glCreateBuffer: () => {
        const buffer = this.glContext.createBuffer();
        this.buffers.push(buffer);
        return this.buffers.length;
      },

      glDeleteBuffer: (buffer) => {
        const bufferObject = this.getBufferObject(buffer);
        this.glContext.deleteBuffer(bufferObject);
      },

      glBindBuffer: (target, buffer) => {
        const bufferObject = this.getBufferObject(buffer);
        this.glContext.bindBuffer(target, bufferObject);
      },

      glBufferDataFloat: (target, length, pointer, usage) => {
        const bufferData = this.getFloat32Array(pointer, length);
        this.glContext.bufferData(target, bufferData, usage);
      },

      glBufferDataUInt: (target, length, pointer, usage) => {
        const bufferData = this.getUnsignedInt32Array(pointer, length);
        this.glContext.bufferData(target, bufferData, usage);
      },

      glCreateVertexArray: () => {
        const vertextArrayObject = this.glContext.createVertexArray();
        this.vertextArrayObjects.push(vertextArrayObject);
        return this.vertextArrayObjects.length;
      },

      glDeleteVertexArray: (vertextArrayObjectName) => {
        const vertextArrayObject = this.getVertexArrayObject(
          vertextArrayObjectName
        );

        this.glContext.deleteVertexArray(vertextArrayObject);
      },

      glBindVertexArray: (vertextArrayObjectName) => {
        const vertextArrayObject = this.getVertexArrayObject(
          vertextArrayObjectName
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
        const programObject = this.getProgramObject(program);
        this.glContext.useProgram(programObject);
      },

      glDrawArrays: (mode, first, count) => {
        this.glContext.drawArrays(mode, first, count);
      },

      glDrawElements: (mode, count, type) => {
        this.glContext.drawElements(mode, count, type, 0);
      },

      glDisable: (capability) => {
        this.glContext.disable(capability);
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
    if (name == 0) {
      return null;
    }

    const index = name - 1;
    if (index > list.length - 1) {
      throw new Error(`${type} ${name} does not exist`);
    }

    return list[index];
  }

  getProgramObject(name) {
    return this.getGlObject(this.shaderPrograms, name, "Shader Program");
  }

  getBufferObject(name) {
    return this.getGlObject(this.buffers, name, "Buffer");
  }

  getVertexArrayObject(name) {
    return this.getGlObject(
      this.vertextArrayObjects,
      name,
      "Vertex Array Object"
    );
  }

  setupCanvas() {
    const canvas = document.querySelector("#renderArea");
    this.glContext = canvas.getContext("webgl2");
    if (!this.glContext) {
      console.error("Unable to initialize WebGL 2 context");
      return;
    }

    const runtime = this;
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

        runtime.displayWidth = Math.round(width * dpr);
        runtime.displayHeight = Math.round(height * dpr);
      }
    }

    const resizeObserver = new ResizeObserver(onResize);
    try {
      resizeObserver.observe(canvas, { box: "device-pixel-content-box" });
    } catch (ex) {
      resizeObserver.observe(canvas, { box: "content-box" });
    }
  }

  setViewport(width, height) {
    this.instance.exports.setViewport(width, height);
  }
}
