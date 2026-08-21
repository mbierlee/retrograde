export default class RetrogradeRuntime {
  wasmModulePath;
  memory;
  instance;
  imports;

  eventCapturer;
  glContext;

  displayWidth;
  displayHeight;
  viewportNeedsReset = false;

  shaderPrograms = [];
  buffers = [];
  vertextArrayObjects = [];
  textures = [];

  uniformLocations = [];
  uniformLocationDict = {};

  heldModifierKeys = new Set();

  // The mouse movement settings of source/retrograde/engine/input.d, which is
  // what sets them: their defaults are the ones the engine documents. Neither
  // type is followed until the game asks for it, so that a game that binds
  // nothing to the mouse is not made to carry the movements it never reads.
  mouseMovementEnabled = {
    [MouseMovementType.absolute]: false,
    [MouseMovementType.relative]: false,
  };

  mouseAxisSplit = false;
  rawMouseMotion = false;

  // The mouse mode that was asked for, which is not the one the mouse is in
  // while the browser has not handed over the pointer lock a disabled mouse
  // needs. reportedMouseMode is the mode the engine was last told about, kept
  // so that a mode it already knows about is not reported over and over.
  mouseMode = MouseMode.normal;
  reportedMouseMode = MouseMode.normal;
  pointerLockWired = false;

  constructor(wasmModulePath) {
    this.wasmModulePath = wasmModulePath;
    this.memory = null;
    this.instance = null;

    this.imports = {
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
        console.log(asUnsignedLong(value));
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
        console.log(String.fromCodePoint(value));
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
        console.error(asUnsignedLong(value));
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
        console.error(String.fromCodePoint(value));
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
        this.writeString(asUnsignedLong(val).toString(), strPtr, ptrLength);
      },
      scalarToString: (strPtr, ptrLength, val) => {
        const numberString = parseFloat(val).toFixed(6).toString();
        this.writeString(numberString, strPtr, ptrLength);
      },

      // Maths

      powf: (base, exponent) => {
        return Math.pow(base, exponent);
      },
      cosf: (value) => {
        return Math.cos(value);
      },
      sinf: (value) => {
        return Math.sin(value);
      },
      cos: (value) => {
        return Math.cos(value);
      },
      sin: (value) => {
        return Math.sin(value);
      },
      tan: (value) => {
        return Math.tan(value);
      },

      // Sanity

      __assert: (assertionMsgPtr, srcFilePtr, srcLineNumber) => {
        const assertionMessage = this.getCString(assertionMsgPtr);
        const srcFile = this.getCString(srcFilePtr);
        console.error(
          `Assertion error: ${assertionMessage}\n    at ${srcFile}:${srcLineNumber}`,
        );
      },

      // Input

      setupKeyboardCallback: () => {
        const dispatchKeyEvent = (e, action) => {
          this.trackModifierKey(e.code, action);
          this.instance.exports.onKey(
            this.mapScanCode(e.code),
            this.mapKeyCode(e),
            action,
            this.mapKeyModifiers(e),
          );
          e.preventDefault();
        };

        this.eventCapturer.addEventListener("keydown", (e) => {
          // Held keys produce a stream of keydown events after the initial
          // press, which the browser marks as repeats.
          dispatchKeyEvent(
            e,
            e.repeat ? InputEventAction.repeat : InputEventAction.press,
          );
        });

        this.eventCapturer.addEventListener("keyup", (e) => {
          dispatchKeyEvent(e, InputEventAction.release);
        });
      },

      setupTextInputCallback: () => {
        this.eventCapturer.addEventListener("keydown", (e) => {
          const codePoint = this.textInputCodePointOf(e);
          if (codePoint === undefined) {
            return;
          }

          this.instance.exports.onTextInput(codePoint);

          // Typing is what the key is doing here rather than whatever the
          // browser has it do, such as scrolling the page on a space.
          e.preventDefault();
        });
      },

      setupMouseCallback: () => {
        const dispatchMouseButtonEvent = (e, action) => {
          this.instance.exports.onMouseButton(
            this.mapMouseButton(e.button),
            action,
            this.mapKeyModifiers(e),
          );
          e.preventDefault();
        };

        this.eventCapturer.addEventListener("mousedown", (e) => {
          dispatchMouseButtonEvent(e, InputEventAction.press);
        });

        this.eventCapturer.addEventListener("mouseup", (e) => {
          dispatchMouseButtonEvent(e, InputEventAction.release);
        });

        this.eventCapturer.addEventListener("mousemove", (e) => {
          this.dispatchMouseMovement(e);
        });

        // The wheel is a game control here rather than the way to scroll the
        // page, which browsers assume it is: a wheel listener is passive unless
        // it says otherwise, leaving preventDefault with nothing to hold back.
        this.eventCapturer.addEventListener(
          "wheel",
          (e) => {
            this.dispatchMouseScroll(e);
            e.preventDefault();
          },
          { passive: false },
        );

        // The right button is a game button here rather than the way to open
        // the context menu, which would otherwise take over the page as soon
        // as it is pressed.
        this.eventCapturer.addEventListener("contextmenu", (e) => {
          e.preventDefault();
        });
      },

      setMouseMovementTypeEnabled: (movementType, enabled) => {
        this.mouseMovementEnabled[movementType] = enabled !== 0;
      },

      isMouseMovementTypeEnabled: (movementType) => {
        return this.mouseMovementEnabled[movementType] ? 1 : 0;
      },

      setMouseAxisSplitEnabled: (enabled) => {
        this.mouseAxisSplit = enabled !== 0;
      },

      isMouseAxisSplitEnabled: () => {
        return this.mouseAxisSplit ? 1 : 0;
      },

      setRawMouseMotionEnabled: (enabled) => {
        this.rawMouseMotion = enabled !== 0;
      },

      isRawMouseMotionEnabled: () => {
        return this.rawMouseMotion ? 1 : 0;
      },

      setMouseCursorMode: (mouseMode) => {
        this.applyMouseMode(mouseMode);
      },

      getMouseCursorMode: () => {
        return this.effectiveMouseMode();
      },

      // GL API

      compileShaderProgram: (
        nameLength,
        namePtr,
        vertexShaderLength,
        vertexShaderPtr,
        fragmentShaderLength,
        fragmentShaderPtr,
      ) => {
        const name = this.getString(namePtr, nameLength);

        if (!this.glContext) {
          console.error(
            `failed to compile shader program ${name} GL context is not initialized`,
          );
        }

        const vertexShaderSource = this.getString(
          vertexShaderPtr,
          vertexShaderLength,
        );
        const fragmentShaderSource = this.getString(
          fragmentShaderPtr,
          fragmentShaderLength,
        );

        const vertexShader = this.createShader(
          this.glContext,
          this.glContext.VERTEX_SHADER,
          vertexShaderSource,
        );

        const fragmentShader = this.createShader(
          this.glContext,
          this.glContext.FRAGMENT_SHADER,
          fragmentShaderSource,
        );

        const program = this.createShaderProgram(
          this.glContext,
          vertexShader,
          fragmentShader,
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
          vertextArrayObjectName,
        );

        this.glContext.deleteVertexArray(vertextArrayObject);
      },

      glBindVertexArray: (vertextArrayObjectName) => {
        const vertextArrayObject = this.getVertexArrayObject(
          vertextArrayObjectName,
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
        offset,
      ) => {
        this.glContext.vertexAttribPointer(
          index,
          size,
          type,
          normalized,
          stride,
          offset,
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

      glEnable: (capability) => {
        this.glContext.enable(capability);
      },

      glDisable: (capability) => {
        this.glContext.disable(capability);
      },

      glCullFace: (mode) => {
        this.glContext.cullFace(mode);
      },

      glGetUniformLocation: (program, nameLength, namePtr) => {
        const name = this.getString(namePtr, nameLength);
        const dictKey = `${program}|${name}`;
        if (this.uniformLocationDict.hasOwnProperty(dictKey)) {
          return this.uniformLocationDict[dictKey];
        }

        const programObject = this.getProgramObject(program);
        const location = this.glContext.getUniformLocation(programObject, name);
        this.uniformLocations.push(location);
        return this.uniformLocations.length;
      },

      glGetAttribLocation: (program, nameLength, namePtr) => {
        const name = this.getString(namePtr, nameLength);
        const programObject = this.getProgramObject(program);
        return this.glContext.getAttribLocation(programObject, name);
      },

      glUniformMatrix4fv: (
        location,
        count,
        transpose,
        valueLength,
        valuePtr,
      ) => {
        const valueData = this.getFloat32Array(valuePtr, valueLength);
        const locationObject = this.getUniformLocationObject(location);
        this.glContext.uniformMatrix4fv(locationObject, transpose, valueData);
      },

      glUniform4fv: (location, count, valueLength, valuePtr) => {
        const valueData = this.getFloat32Array(valuePtr, valueLength);
        const locationObject = this.getUniformLocationObject(location);
        this.glContext.uniform4fv(locationObject, valueData);
      },

      glDepthFunc: (func) => {
        this.glContext.depthFunc(func);
      },

      glStencilFunc: (func, refVal, mask) => {
        this.glContext.stencilFunc(func, refVal, mask);
      },

      glBlendFunc: (sfactor, dfactor) => {
        this.glContext.blendFunc(sfactor, dfactor);
      },

      glCreateTexture: () => {
        const texture = this.glContext.createTexture();
        this.textures.push(texture);
        return this.textures.length;
      },

      glDeleteTexture: (texture) => {
        const textureObject = this.getTextureObject(texture);
        this.glContext.deleteTexture(textureObject);
      },

      glBindTexture: (target, texture) => {
        const textureObject = this.getTextureObject(texture);
        this.glContext.bindTexture(target, textureObject);
      },

      glActiveTexture: (texture) => {
        this.glContext.activeTexture(texture);
      },

      glTexImage2D: (
        target,
        level,
        internalformat,
        width,
        height,
        border,
        format,
        type,
        pixelsLength,
        pixelsPtr,
      ) => {
        const pixels = this.getUint8Array(pixelsPtr, pixelsLength);
        this.glContext.texImage2D(
          target,
          level,
          internalformat,
          width,
          height,
          border,
          format,
          type,
          pixels,
        );
      },

      glTexParameteri: (target, pname, param) => {
        this.glContext.texParameteri(target, pname, param);
      },

      glGenerateMipmap: (target) => {
        this.glContext.generateMipmap(target);
      },

      glPixelStorei: (pname, param) => {
        this.glContext.pixelStorei(pname, param);
      },

      glUniform1i: (location, value) => {
        const locationObject = this.getUniformLocationObject(location);
        this.glContext.uniform1i(locationObject, value);
      },

      // Asset Loading

      startAssetFetch: (urlPtr, urlLen, handle) => {
        const url = this.getString(urlPtr, urlLen);
        fetch(url)
          .then((response) => {
            if (!response.ok) {
              throw new Error(
                `HTTP ${response.status}: ${response.statusText}`,
              );
            }

            return response.arrayBuffer();
          })
          .then((arrayBuffer) => {
            const data = new Uint8Array(arrayBuffer);
            const wasmPtr = this.instance.exports.malloc(data.length);
            const wasmBuf = new Uint8Array(
              this.memory.buffer,
              wasmPtr,
              data.length,
            );

            wasmBuf.set(data);
            this.instance.exports.onAssetFetchComplete(
              handle,
              wasmPtr,
              data.length,
            );

            this.instance.exports.free(wasmPtr);
          })
          .catch((err) => {
            const msg = err.message || "Unknown fetch error";
            const encoded = new TextEncoder().encode(msg);
            const errPtr = this.instance.exports.malloc(encoded.length);
            const errBuf = new Uint8Array(
              this.memory.buffer,
              errPtr,
              encoded.length,
            );

            errBuf.set(encoded);
            this.instance.exports.onAssetFetchError(
              handle,
              errPtr,
              encoded.length,
            );

            this.instance.exports.free(errPtr);
          });
      },
    };
  }

  async initWasmModule() {
    let importObject = {
      env: this.imports,
    };

    // const res = await WebAssembly.instantiateStreaming(
    //   fetch(this.wasmModulePath),
    //   importObject
    // );

    const res = await fetch(this.wasmModulePath)
      .then((response) => response.arrayBuffer())
      .then((bytes) => WebAssembly.instantiate(bytes, importObject));

    this.instance = res.instance;
    this.memory = res.instance.exports.memory;
  }

  startWasmModule() {
    this.instance.exports._start();
  }

  initEngine() {
    this.instance.exports.initEngine();
  }

  executeEngineLoopCycle(elapsedTimeMs) {
    this.instance.exports.executeEngineLoopCycle(elapsedTimeMs);
  }

  getString(pointer, length) {
    const buffer = new Uint8Array(this.memory.buffer, pointer, length);
    return new TextDecoder("utf-8").decode(buffer);
  }

  getCString(pointer) {
    const buffer = new Uint8Array(this.memory.buffer, pointer);
    let length = 0;
    while (buffer[length] != 0) {
      length++;
    }

    return this.getString(pointer, length);
  }

  getFloat32Array(pointer, length) {
    const floatSize = 4;
    const array = new Float32Array(length);
    const dataview = new DataView(
      this.memory.buffer,
      pointer,
      length * floatSize,
    );

    for (let i = 0; i < length; i++) {
      const val = dataview.getFloat32(i * floatSize, true);
      array[i] = val;
    }

    return array;
  }

  getUint8Array(pointer, length) {
    return new Uint8Array(this.memory.buffer, pointer, length).slice();
  }

  getUnsignedInt32Array(pointer, length) {
    const uintSize = 4;
    const array = new Uint32Array(length);
    const dataview = new DataView(
      this.memory.buffer,
      pointer,
      length * uintSize,
    );

    for (let i = 0; i < length; i++) {
      const val = dataview.getUint32(i * uintSize, true);
      array[i] = val;
    }

    return array;
  }

  writeString(string, pointer, maxLength) {
    const encodedString = new TextEncoder("utf-8").encode(string);
    if (encodedString.length > maxLength) {
      throw new Error(
        `String too large for storage destination: '${string}' (allocated size: ${maxLength}, encoded string size: ${encodedString.length})`,
      );
    }

    const dataview = new DataView(this.memory.buffer, pointer, maxLength);
    encodedString.forEach((chr, i) => {
      dataview.setUint8(i, chr);
    });
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
      "Vertex Array Object",
    );
  }

  getUniformLocationObject(name) {
    return this.getGlObject(this.uniformLocations, name, "Uniform Location");
  }

  getTextureObject(name) {
    return this.getGlObject(this.textures, name, "Texture");
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

  /**
   * Maps a KeyboardEvent.code value to its KeyboardScanCode value.
   * Unmapped keys become KeyboardScanCode.unknown.
   */
  mapScanCode(jsCode) {
    const scanCode = scanCodeMap[jsCode];
    return scanCode === undefined ? KeyboardScanCode.unknown : scanCode;
  }

  /**
   * Maps a MouseEvent.button value to its MouseButton value.
   * Unmapped buttons become MouseButton.unknown.
   */
  mapMouseButton(jsButton) {
    const button = mouseButtonMap[jsButton];
    return button === undefined ? MouseButton.unknown : button;
  }

  /**
   * Reports a mouse movement to the engine, as the position of the mouse over
   * the render area, as the distance it moved since the previous movement, or
   * as both.
   */
  dispatchMouseMovement(e) {
    if (this.mouseMovementEnabled[MouseMovementType.absolute]) {
      this.dispatchMouseMovementEvent(
        this.absoluteMousePosition(e),
        MouseMovementType.absolute,
      );
    }

    if (this.mouseMovementEnabled[MouseMovementType.relative]) {
      this.dispatchMouseMovementEvent(
        this.relativeMouseMovement(e),
        MouseMovementType.relative,
      );
    }
  }

  /**
   * Reports a single movement, as one event carrying both axes or as one event
   * per axis when the axes are split.
   *
   * An axis is reported whether or not the mouse moved along it: leaving out
   * the axis that stayed put would leave the events bound to it stuck at the
   * magnitude of the last movement that did touch it.
   */
  dispatchMouseMovementEvent(position, movementType) {
    const onMouseMovement = this.instance.exports.onMouseMovement;
    if (this.mouseAxisSplit) {
      onMouseMovement(position.x, 0, Axis.x, movementType);
      onMouseMovement(0, position.y, Axis.y, movementType);
    } else {
      onMouseMovement(position.x, position.y, Axis.all, movementType);
    }
  }

  /**
   * Returns the position of the mouse over the render area, in pixels from its
   * top left corner when raw mouse motion is on, and as a part of its size,
   * from 0.0 to 1.0, when it is off.
   */
  absoluteMousePosition(e) {
    const renderArea = this.renderAreaRect();
    const x = e.clientX - renderArea.left;
    const y = e.clientY - renderArea.top;
    if (this.rawMouseMotion) {
      return { x, y };
    }

    return {
      x: clamp(this.partOf(x, renderArea.width), 0, 1),
      y: clamp(this.partOf(y, renderArea.height), 0, 1),
    };
  }

  /**
   * Returns the distance the mouse moved since the previous movement, in pixels
   * when raw mouse motion is on, and as a part of the size of the render area,
   * from -1.0 to 1.0, when it is off.
   */
  relativeMouseMovement(e) {
    if (this.rawMouseMotion) {
      return { x: e.movementX, y: e.movementY };
    }

    const renderArea = this.renderAreaRect();
    return {
      x: clamp(this.partOf(e.movementX, renderArea.width), -1, 1),
      y: clamp(this.partOf(e.movementY, renderArea.height), -1, 1),
    };
  }

  /**
   * Reports a scroll of the mousewheel to the engine, in notches along both of
   * its axes.
   *
   * The vertical offset is turned around on the way out: the browser reports a
   * scroll down as the positive one, where the engine has the wheel Y-up as
   * every other platform reports it. Doing it here leaves the browser as the
   * only platform that has to, rather than every other one. The horizontal
   * offset needs none of that, as scrolling right is positive everywhere.
   */
  dispatchMouseScroll(e) {
    this.instance.exports.onMouseScroll(
      scrollNotches(e.deltaX, e.deltaMode),
      -scrollNotches(e.deltaY, e.deltaMode),
    );
  }

  /**
   * Puts the mouse in the given mode, as far as the browser lets it be put
   * there right away, and reports the mode it ended up in.
   *
   * Hiding the mouse is a matter of the cursor of the render area and takes
   * effect at once. Disabling it takes the pointer lock, which the browser only
   * gives while the page has recently been interacted with: the request is made
   * here in case it is granted, and made again on every click on the render
   * area for as long as the mouse is meant to be disabled. Until it is granted
   * the cursor stays the normal one, as the user has to be able to see it to
   * click with it.
   *
   * The mode is remembered whether or not there is a render area to apply it
   * to yet, so that a mouse asked to be disabled before the canvas was set up
   * still takes the lock on the first click on it.
   */
  applyMouseMode(mouseMode) {
    this.mouseMode = mouseMode;

    const renderArea = this.renderAreaElement();
    if (renderArea) {
      this.wirePointerLock(renderArea);
      renderArea.style.cursor = mouseMode === MouseMode.hidden ? "none" : "";

      if (mouseMode === MouseMode.disabled) {
        this.requestPointerLock(renderArea);
      } else if (this.isPointerLocked()) {
        // Losing the lock is reported by the browser rather than here: it is
        // the pointerlockchange event that says the mouse is out of it.
        document.exitPointerLock();
      }
    }

    this.reportMouseMode();
  }

  /**
   * Returns the mode the mouse is really in: the one it was asked to be in,
   * except for a disabled mouse that has not been given the pointer lock, which
   * is still the normal one.
   */
  effectiveMouseMode() {
    if (this.isPointerLocked()) {
      return MouseMode.disabled;
    }

    return this.mouseMode === MouseMode.hidden
      ? MouseMode.hidden
      : MouseMode.normal;
  }

  /**
   * Reports the mode the mouse is now in to the engine, unless it is the mode
   * the engine was already told about.
   */
  reportMouseMode() {
    const mouseMode = this.effectiveMouseMode();
    if (mouseMode === this.reportedMouseMode) {
      return;
    }

    this.reportedMouseMode = mouseMode;
    this.instance.exports.onMouseMode(mouseMode);
  }

  /**
   * Returns whether the pointer is locked to the render area.
   */
  isPointerLocked() {
    const renderArea = this.renderAreaElement();
    return (
      renderArea !== undefined && document.pointerLockElement === renderArea
    );
  }

  /**
   * Asks the browser for the pointer lock.
   *
   * A request made without the user having interacted with the page just before
   * it is turned down, which is nothing to report: the click listener of
   * wirePointerLock asks again as soon as the user clicks the render area.
   */
  requestPointerLock(renderArea) {
    if (this.isPointerLocked()) {
      return;
    }

    try {
      const request = renderArea.requestPointerLock();
      if (request && typeof request.catch === "function") {
        request.catch(() => {});
      }
    } catch (ex) {
      // Turned down for now.
    }
  }

  /**
   * Starts following the pointer lock, once.
   *
   * The lock is taken on a click on the render area, which is the browser's
   * condition for handing it over, and is followed for as long as the page
   * lives: the user can hand it back with escape at any time, after which the
   * next click takes it again while the mouse is still meant to be disabled.
   */
  wirePointerLock(renderArea) {
    if (this.pointerLockWired) {
      return;
    }

    this.pointerLockWired = true;

    renderArea.addEventListener("mousedown", () => {
      if (this.mouseMode === MouseMode.disabled) {
        this.requestPointerLock(renderArea);
      }
    });

    document.addEventListener("pointerlockchange", () => {
      this.reportMouseMode();
    });
  }

  /**
   * Returns the element mouse positions are reported over and the pointer is
   * locked to: the canvas being rendered to, or nothing while there is none.
   */
  renderAreaElement() {
    return this.glContext ? this.glContext.canvas : undefined;
  }

  /**
   * Returns the area mouse positions are reported over: the canvas being
   * rendered to, or the viewport while there is none.
   */
  renderAreaRect() {
    const canvas = this.renderAreaElement();
    if (canvas) {
      return canvas.getBoundingClientRect();
    }

    return {
      left: 0,
      top: 0,
      width: window.innerWidth,
      height: window.innerHeight,
    };
  }

  /**
   * Returns how much of the given size the given value is, or zero for an area
   * that has no size to be a part of.
   */
  partOf(value, size) {
    return size > 0 ? value / size : 0;
  }

  /**
   * Maps a keyboard event to its KeyboardKeyCode value: the Unicode code point
   * of the character the key produced, or the scan code of the key marked with
   * scanCodeMask when it produced no character.
   *
   * Keys that produce no character have a key value that is a name rather than
   * a character, such as "Enter". Which key such a name belongs to is what the
   * event's code already says, so the scan code doubles as the key code for
   * them, the way SDL2 derives a key code from a scan code.
   */
  mapKeyCode(e) {
    const codePoint = this.singleCodePointOf(e.key);
    if (codePoint !== undefined) {
      return codePoint;
    }

    const scanCode = this.mapScanCode(e.code);
    return scanCode === KeyboardScanCode.unknown
      ? keyCodeUnknown
      : scanCodeMask | scanCode;
  }

  /**
   * Returns the code point of the character a key event typed, or undefined
   * when it typed no text at all.
   *
   * The browser has already worked the character out of the layout, the
   * modifiers and any dead key that came before it, so the key value is taken
   * as it comes. What is left to do here is to tell the keys that produce text
   * apart from the ones that do something else:
   *
   * - Keys that produce no character have a key value that is a name, such as
   *   "Enter" or "ArrowLeft", which is not a single character and so drops out.
   * - The control characters that a key value can still hold, such as the tab
   *   key's "\t", edit text rather than being text.
   * - A key pressed with ctrl or meta held is part of a shortcut and is a
   *   command rather than text. AltGr is the exception: Windows reports it as
   *   ctrl+alt, and a key behind it does produce a character.
   *
   * Text composed through an input method editor is not reported: the browser
   * keeps that to the composition events of an editable element, which a canvas
   * is not. Dead keys are unaffected, as the browser hands over the character
   * they composed on the key that completes it.
   */
  textInputCodePointOf(e) {
    if ((e.ctrlKey || e.metaKey) && !e.getModifierState("AltGraph")) {
      return undefined;
    }

    if (e.isComposing || e.key === "Process") {
      return undefined;
    }

    const codePoint = this.singleCodePointOf(e.key);
    if (codePoint === undefined || isControlCodePoint(codePoint)) {
      return undefined;
    }

    return codePoint;
  }

  /**
   * Returns the code point of a key value that is a single character, or
   * undefined when it holds a name or nothing at all.
   */
  singleCodePointOf(jsKey) {
    const codePoint = jsKey.codePointAt(0);
    if (codePoint === undefined) {
      return undefined;
    }

    // Code points outside the BMP are two UTF-16 code units long, so the key
    // value is only a single character when it is as long as its first code
    // point.
    return String.fromCodePoint(codePoint).length === jsKey.length
      ? codePoint
      : undefined;
  }

  /**
   * Records whether a left or right modifier key is currently held, so that
   * the events of other keys can tell which side of a modifier is active.
   * Keys that are not a sided modifier are ignored.
   */
  trackModifierKey(jsKeyCode, action) {
    if (modifierKeyCodes[jsKeyCode] === undefined) {
      return;
    }

    if (action === InputEventAction.release) {
      this.heldModifierKeys.delete(jsKeyCode);
    } else {
      this.heldModifierKeys.add(jsKeyCode);
    }
  }

  /**
   * Collects the modifiers active during a keyboard or mouse event into a
   * KeyboardKeyModifier bit mask.
   *
   * Events only report that a modifier is active, not which side of the
   * keyboard it is held on, so the left and right specific flags come from the
   * modifier keys tracked by trackModifierKey instead. Only sided flags are
   * set: the side-independent ones are masks over both sides, so setting one
   * would claim that both keys are held.
   */
  mapKeyModifiers(e) {
    let modifiers = KeyboardKeyModifier.none;

    for (const jsKeyCode of this.heldModifierKeys) {
      const modifierKey = modifierKeyCodes[jsKeyCode];
      if (modifierKey.states.some((state) => e.getModifierState(state))) {
        modifiers |= modifierKey.flag;
      } else {
        // The key was released while the page was not receiving events, so its
        // keyup never arrived and it is only known to be up now.
        this.heldModifierKeys.delete(jsKeyCode);
      }
    }

    // A modifier can be active without its own key event having been seen,
    // such as when it was already held before the page got focus. Which side
    // it is on is unknown then; report the left one, so that bindings on the
    // side-independent modifier still match.
    for (const fallback of unsidedModifierFallbacks) {
      if (
        e.getModifierState(fallback.state) &&
        (modifiers & fallback.eitherSide) === 0
      ) {
        modifiers |= fallback.assumedSide;
      }
    }

    if (e.getModifierState("AltGraph")) {
      modifiers |= KeyboardKeyModifier.mode;
    }

    if (e.getModifierState("CapsLock")) {
      modifiers |= KeyboardKeyModifier.capslock;
    }

    if (e.getModifierState("NumLock")) {
      modifiers |= KeyboardKeyModifier.numlock;
    }

    return modifiers;
  }
}

/**
 * Mirror of KeyboardScanCode in source/retrograde/engine/input.d, in
 * declaration order. The D enum assigns no explicit values, so a name's index
 * here is its numeric value. Keep this list in sync with the enum; inserting a
 * name in the middle shifts every value after it.
 */
// prettier-ignore
const scanCodeNames = [
  "unknown", "a", "acBack", "acBookmarks", "acForward", "acHome", "acRefresh",
  "acSearch", "acStop", "again", "alterase", "apostrophe", "app1", "app2",
  "application", "audioMute", "audioNext", "audioPlay", "audioPrev",
  "audioStop", "b", "backslash", "backspace", "brightnessDown", "brightnessUp",
  "c", "calculator", "cancel", "capslock", "clear", "clearAgain", "comma",
  "computer", "copy", "crsel", "currencySubunit", "currencyUnit", "cut", "d",
  "decimalSeparator", "deleteKey", "displaySwitch", "down", "e", "eight",
  "eject", "end", "equals", "escape", "execute", "exsel", "f", "f1", "f10",
  "f11", "f12", "f13", "f14", "f15", "f16", "f17", "f18", "f19", "f2", "f20",
  "f21", "f22", "f23", "f24", "f25", "f3", "f4", "f5", "f6", "f7", "f8", "f9",
  "find", "five", "four", "g", "grave", "h", "help", "home", "i", "insert",
  "international1", "international2", "international3", "international4",
  "international5", "international6", "international7", "international8",
  "international9", "j", "k", "kbdIllumDown", "kbdIllumToggle", "kbdIllumUp",
  "keypad00", "keypad000", "keypadComma", "keypadDivide", "keypadEight",
  "keypadEnter", "keypadEquals", "keypadEqualsas400", "keypadFive",
  "keypadFour", "keypadMinus", "keypadMultiply", "keypadNine", "keypadOne",
  "keypadPeriod", "keypadPlus", "keypadSeven", "keypadSix", "keypadThree",
  "keypadTwo", "keypadZero", "kpA", "kpAmpersand", "kpAt", "kpB",
  "kpBackspace", "kpBinary", "kpC", "kpClear", "kpClearentry", "kpColon",
  "kpD", "kpDblampersand", "kpDblverticalbar", "kpDecimal", "kpE", "kpExclam",
  "kpF", "kpGreater", "kpHash", "kpHexadecimal", "kpLeftbrace", "kpLeftparen",
  "kpLess", "kpMemadd", "kpMemclear", "kpMemdivide", "kpMemmultiply",
  "kpMemrecall", "kpMemstore", "kpMemsubtract", "kpOctal", "kpPercent",
  "kpPlusminus", "kpPower", "kpRightbrace", "kpRightparen", "kpSpace", "kpTab",
  "kpVerticalbar", "kpXor", "l", "leftAlt", "lang1", "lang2", "lang3", "lang4",
  "lang5", "lang6", "lang7", "lang8", "lang9", "leftCtrl", "left",
  "leftBracket", "leftGui", "leftShift", "m", "mail", "mediaSelect", "menu",
  "minus", "mode", "mute", "n", "nine", "nonusBackslash", "nonusHash",
  "numlockClear", "o", "one", "oper", "outKey", "p", "pageDown", "pageUp",
  "paste", "pause", "period", "power", "printscreen", "prior", "q", "r",
  "rightAlt", "rightCtrl", "enter", "enter2", "rightGui", "right",
  "rightBracket", "rightShift", "s", "scrolllock", "select", "semicolon",
  "separator", "seven", "six", "slash", "sleep", "space", "stop", "sysreq",
  "t", "tab", "thousandsSeparator", "three", "two", "u", "undo", "up", "v",
  "volumedown", "volumeup", "w", "www", "x", "y", "z", "zero",
];

const KeyboardScanCode = Object.fromEntries(
  scanCodeNames.map((name, value) => [name, value]),
);

/**
 * Bit that marks a KeyboardKeyCode as carrying a scan code instead of a
 * Unicode code point. Mirrors scanCodeMask in
 * source/retrograde/engine/input.d.
 */
const scanCodeMask = 1 << 30;

/**
 * Mirror of KeyboardKeyCode.unknown in source/retrograde/engine/input.d. The
 * other key codes are computed rather than mirrored: a key that produces a
 * character has that character's code point as its key code, and every other
 * key has its scan code marked with scanCodeMask.
 */
const keyCodeUnknown = 0;

/**
 * Mirror of InputEventAction in source/retrograde/engine/input.d. As with
 * KeyboardScanCode, the D enum assigns no explicit values, so these are the
 * members' positions.
 */
const InputEventAction = {
  unknown: 0,
  press: 1,
  release: 2,
  repeat: 3,
};

/**
 * Mirror of KeyboardKeyModifier in source/retrograde/engine/input.d. Unlike the
 * other input enums this one assigns explicit bit flags, so the values are
 * copied as-is rather than derived from their position.
 */
const KeyboardKeyModifier = {
  none: 0,
  leftShift: 1 << 1,
  rightShift: 1 << 2,
  leftCtrl: 1 << 3,
  rightCtrl: 1 << 4,
  leftAlt: 1 << 5,
  rightAlt: 1 << 6,
  leftGui: 1 << 7,
  rightGui: 1 << 8,
  numlock: 1 << 9,
  capslock: 1 << 10,
  mode: 1 << 11,
  // The side-independent modifiers are masks over both of their sides rather
  // than flags of their own, so only the sided flags are ever reported.
  shift: (1 << 1) | (1 << 2),
  ctrl: (1 << 3) | (1 << 4),
  alt: (1 << 5) | (1 << 6),
  gui: (1 << 7) | (1 << 8),
};

/**
 * Mirror of MouseButton in source/retrograde/engine/input.d. The buttons are
 * numbered from one there, leaving zero for the unknown button, so their values
 * are copied rather than derived from their position.
 */
const MouseButton = {
  unknown: 0,
  one: 1,
  two: 2,
  three: 3,
  four: 4,
  five: 5,
  six: 6,
  seven: 7,
  eight: 8,
  left: 1,
  right: 2,
  middle: 3,
};

/**
 * Mirror of MouseMovementType in source/retrograde/engine/input.d. The D enum
 * assigns no explicit values, so these are the members' positions.
 */
const MouseMovementType = {
  absolute: 0,
  relative: 1,
};

/**
 * Mirror of MouseMode in source/retrograde/engine/input.d, likewise valued by
 * position. The disabled mouse is the one locked to the render area, which is
 * the pointer lock here.
 */
const MouseMode = {
  normal: 0,
  hidden: 1,
  disabled: 2,
};

/**
 * Mirror of Axis in source/retrograde/engine/input.d, likewise valued by
 * position. A mouse only ever moves along x and y; all is a movement that
 * carries both of them at once.
 */
const Axis = {
  all: 0,
  x: 1,
  y: 2,
  z: 3,
};

/**
 * The units a WheelEvent reports its deltas in, as WheelEvent.DOM_DELTA_* has
 * them. They are spelled out here rather than read off the global, so that the
 * runtime keeps loading where there is no WheelEvent to read them from.
 */
const WheelDeltaMode = {
  pixel: 0,
  line: 1,
  page: 2,
};

/**
 * How much of each unit a browser scrolls per notch of the wheel: the ones
 * Chromium-based browsers scroll in pixels, and the ones Firefox scrolls in
 * lines. A page is a notch of its own.
 */
const pixelsPerScrollNotch = 100;
const linesPerScrollNotch = 3;

/**
 * Returns the given wheel delta in notches, whichever units the browser reported
 * it in.
 *
 * Browsers disagree on both the unit and the amount of it a notch of the wheel
 * is worth, so the raw delta of a single notch differs between them. Bringing
 * them to a common notch leaves a binding scrolling the same amount everywhere,
 * and leaves the fractions of a notch that a trackpad or a free-spinning wheel
 * reports intact.
 */
function scrollNotches(delta, deltaMode) {
  switch (deltaMode) {
    case WheelDeltaMode.line:
      return delta / linesPerScrollNotch;
    case WheelDeltaMode.page:
      return delta;
    default:
      return delta / pixelsPerScrollNotch;
  }
}

/**
 * Returns whether the given code point is a control character rather than one
 * that can be typed as text.
 *
 * These are the C0 controls and the delete character; the C1 controls above
 * them are left alone, as a key value never holds one.
 */
function isControlCodePoint(codePoint) {
  return codePoint < 0x20 || codePoint === 0x7f;
}

/**
 * Returns the given value brought within the given bounds.
 */
function clamp(value, min, max) {
  return Math.min(Math.max(value, min), max);
}

/**
 * Returns the unsigned value a 64 bit number out of D stands for.
 *
 * A wasm i64 arrives here as a signed BigInt, so a D ulong past long.max comes
 * in as the negative number it shares its bits with and has to be read back out
 * of them.
 */
function asUnsignedLong(value) {
  return BigInt.asUintN(64, BigInt(value));
}

/**
 * Maps MouseEvent.button values to MouseButton values.
 *
 * Mouse events number the buttons left, middle, right, whereas MouseButton
 * numbers them left, right, middle the way SDL2 does. The two buttons past
 * those are the side buttons a browser navigates back and forward with; the
 * buttons past those are not reported at all.
 */
const mouseButtonMap = {
  0: MouseButton.left,
  1: MouseButton.middle,
  2: MouseButton.right,
  3: MouseButton.four,
  4: MouseButton.five,
};

/**
 * The modifier keys that come in a left and a right variant, keyed by their
 * KeyboardEvent.code value.
 *
 * Keyboard events report which side was pressed in the code of the modifier's
 * own key event, but not in the events of the keys pressed after it, so which
 * side is held has to be tracked over time. The states are the modifier names
 * that KeyboardEvent.getModifierState reports the key as, used to notice that
 * a key was released while the page was not receiving events.
 */
const modifierKeyCodes = {
  ShiftLeft: { flag: KeyboardKeyModifier.leftShift, states: ["Shift"] },
  ShiftRight: { flag: KeyboardKeyModifier.rightShift, states: ["Shift"] },
  ControlLeft: { flag: KeyboardKeyModifier.leftCtrl, states: ["Control"] },
  ControlRight: { flag: KeyboardKeyModifier.rightCtrl, states: ["Control"] },
  AltLeft: { flag: KeyboardKeyModifier.leftAlt, states: ["Alt"] },
  // The right alt key doubles as AltGr on layouts that have one, in which case
  // it is reported as AltGraph instead of as Alt.
  AltRight: { flag: KeyboardKeyModifier.rightAlt, states: ["Alt", "AltGraph"] },
  MetaLeft: { flag: KeyboardKeyModifier.leftGui, states: ["Meta"] },
  MetaRight: { flag: KeyboardKeyModifier.rightGui, states: ["Meta"] },
};

/**
 * The side to assume for a modifier that KeyboardEvent.getModifierState
 * reports as active while neither of its keys is known to be held.
 *
 * That happens when the key went down before the page started receiving
 * events, leaving nothing to tell the sides apart. The left side is the guess,
 * as it is the one keyboards with only a single such key carry.
 */
const unsidedModifierFallbacks = [
  {
    state: "Shift",
    eitherSide: KeyboardKeyModifier.shift,
    assumedSide: KeyboardKeyModifier.leftShift,
  },
  {
    state: "Control",
    eitherSide: KeyboardKeyModifier.ctrl,
    assumedSide: KeyboardKeyModifier.leftCtrl,
  },
  {
    state: "Alt",
    eitherSide: KeyboardKeyModifier.alt,
    assumedSide: KeyboardKeyModifier.leftAlt,
  },
  {
    state: "Meta",
    eitherSide: KeyboardKeyModifier.gui,
    assumedSide: KeyboardKeyModifier.leftGui,
  },
];

/**
 * Maps KeyboardEvent.code values to KeyboardScanCode values.
 *
 * Code values identify the physical key, independent of keyboard layout and
 * modifier state, which is what KeyboardScanCode describes as well: it names
 * the key by its position on a US layout, tells left and right modifiers
 * apart and has separate entries for the keypad.
 */
const scanCodeMap = {
  // Letters
  KeyA: KeyboardScanCode.a,
  KeyB: KeyboardScanCode.b,
  KeyC: KeyboardScanCode.c,
  KeyD: KeyboardScanCode.d,
  KeyE: KeyboardScanCode.e,
  KeyF: KeyboardScanCode.f,
  KeyG: KeyboardScanCode.g,
  KeyH: KeyboardScanCode.h,
  KeyI: KeyboardScanCode.i,
  KeyJ: KeyboardScanCode.j,
  KeyK: KeyboardScanCode.k,
  KeyL: KeyboardScanCode.l,
  KeyM: KeyboardScanCode.m,
  KeyN: KeyboardScanCode.n,
  KeyO: KeyboardScanCode.o,
  KeyP: KeyboardScanCode.p,
  KeyQ: KeyboardScanCode.q,
  KeyR: KeyboardScanCode.r,
  KeyS: KeyboardScanCode.s,
  KeyT: KeyboardScanCode.t,
  KeyU: KeyboardScanCode.u,
  KeyV: KeyboardScanCode.v,
  KeyW: KeyboardScanCode.w,
  KeyX: KeyboardScanCode.x,
  KeyY: KeyboardScanCode.y,
  KeyZ: KeyboardScanCode.z,

  // Digit row
  Digit0: KeyboardScanCode.zero,
  Digit1: KeyboardScanCode.one,
  Digit2: KeyboardScanCode.two,
  Digit3: KeyboardScanCode.three,
  Digit4: KeyboardScanCode.four,
  Digit5: KeyboardScanCode.five,
  Digit6: KeyboardScanCode.six,
  Digit7: KeyboardScanCode.seven,
  Digit8: KeyboardScanCode.eight,
  Digit9: KeyboardScanCode.nine,

  // Punctuation
  Backquote: KeyboardScanCode.grave,
  Minus: KeyboardScanCode.minus,
  Equal: KeyboardScanCode.equals,
  BracketLeft: KeyboardScanCode.leftBracket,
  BracketRight: KeyboardScanCode.rightBracket,
  Backslash: KeyboardScanCode.backslash,
  Semicolon: KeyboardScanCode.semicolon,
  Quote: KeyboardScanCode.apostrophe,
  Comma: KeyboardScanCode.comma,
  Period: KeyboardScanCode.period,
  Slash: KeyboardScanCode.slash,
  IntlBackslash: KeyboardScanCode.nonusBackslash,

  // Whitespace and editing
  Space: KeyboardScanCode.space,
  Enter: KeyboardScanCode.enter,
  Tab: KeyboardScanCode.tab,
  Backspace: KeyboardScanCode.backspace,
  Delete: KeyboardScanCode.deleteKey,
  Insert: KeyboardScanCode.insert,
  Escape: KeyboardScanCode.escape,

  // Navigation
  ArrowUp: KeyboardScanCode.up,
  ArrowDown: KeyboardScanCode.down,
  ArrowLeft: KeyboardScanCode.left,
  ArrowRight: KeyboardScanCode.right,
  Home: KeyboardScanCode.home,
  End: KeyboardScanCode.end,
  PageUp: KeyboardScanCode.pageUp,
  PageDown: KeyboardScanCode.pageDown,

  // Modifiers and locks
  ShiftLeft: KeyboardScanCode.leftShift,
  ShiftRight: KeyboardScanCode.rightShift,
  ControlLeft: KeyboardScanCode.leftCtrl,
  ControlRight: KeyboardScanCode.rightCtrl,
  AltLeft: KeyboardScanCode.leftAlt,
  AltRight: KeyboardScanCode.rightAlt,
  MetaLeft: KeyboardScanCode.leftGui,
  MetaRight: KeyboardScanCode.rightGui,
  ContextMenu: KeyboardScanCode.application,
  CapsLock: KeyboardScanCode.capslock,
  NumLock: KeyboardScanCode.numlockClear,
  ScrollLock: KeyboardScanCode.scrolllock,

  // Function keys
  F1: KeyboardScanCode.f1,
  F2: KeyboardScanCode.f2,
  F3: KeyboardScanCode.f3,
  F4: KeyboardScanCode.f4,
  F5: KeyboardScanCode.f5,
  F6: KeyboardScanCode.f6,
  F7: KeyboardScanCode.f7,
  F8: KeyboardScanCode.f8,
  F9: KeyboardScanCode.f9,
  F10: KeyboardScanCode.f10,
  F11: KeyboardScanCode.f11,
  F12: KeyboardScanCode.f12,
  F13: KeyboardScanCode.f13,
  F14: KeyboardScanCode.f14,
  F15: KeyboardScanCode.f15,
  F16: KeyboardScanCode.f16,
  F17: KeyboardScanCode.f17,
  F18: KeyboardScanCode.f18,
  F19: KeyboardScanCode.f19,
  F20: KeyboardScanCode.f20,
  F21: KeyboardScanCode.f21,
  F22: KeyboardScanCode.f22,
  F23: KeyboardScanCode.f23,
  F24: KeyboardScanCode.f24,
  F25: KeyboardScanCode.f25,

  // Keypad
  Numpad0: KeyboardScanCode.keypadZero,
  Numpad1: KeyboardScanCode.keypadOne,
  Numpad2: KeyboardScanCode.keypadTwo,
  Numpad3: KeyboardScanCode.keypadThree,
  Numpad4: KeyboardScanCode.keypadFour,
  Numpad5: KeyboardScanCode.keypadFive,
  Numpad6: KeyboardScanCode.keypadSix,
  Numpad7: KeyboardScanCode.keypadSeven,
  Numpad8: KeyboardScanCode.keypadEight,
  Numpad9: KeyboardScanCode.keypadNine,
  NumpadAdd: KeyboardScanCode.keypadPlus,
  NumpadSubtract: KeyboardScanCode.keypadMinus,
  NumpadMultiply: KeyboardScanCode.keypadMultiply,
  NumpadStar: KeyboardScanCode.keypadMultiply,
  NumpadDivide: KeyboardScanCode.keypadDivide,
  NumpadDecimal: KeyboardScanCode.keypadPeriod,
  NumpadComma: KeyboardScanCode.keypadComma,
  NumpadEnter: KeyboardScanCode.keypadEnter,
  NumpadEqual: KeyboardScanCode.keypadEquals,
  NumpadHash: KeyboardScanCode.kpHash,
  NumpadBackspace: KeyboardScanCode.kpBackspace,
  NumpadClear: KeyboardScanCode.kpClear,
  NumpadClearEntry: KeyboardScanCode.kpClearentry,
  NumpadParenLeft: KeyboardScanCode.kpLeftparen,
  NumpadParenRight: KeyboardScanCode.kpRightparen,
  NumpadMemoryAdd: KeyboardScanCode.kpMemadd,
  NumpadMemorySubtract: KeyboardScanCode.kpMemsubtract,
  NumpadMemoryClear: KeyboardScanCode.kpMemclear,
  NumpadMemoryRecall: KeyboardScanCode.kpMemrecall,
  NumpadMemoryStore: KeyboardScanCode.kpMemstore,

  // System
  PrintScreen: KeyboardScanCode.printscreen,
  Pause: KeyboardScanCode.pause,
  Power: KeyboardScanCode.power,
  Sleep: KeyboardScanCode.sleep,
  Eject: KeyboardScanCode.eject,
  Help: KeyboardScanCode.help,

  // Editing commands
  Again: KeyboardScanCode.again,
  Undo: KeyboardScanCode.undo,
  Cut: KeyboardScanCode.cut,
  Copy: KeyboardScanCode.copy,
  Paste: KeyboardScanCode.paste,
  Find: KeyboardScanCode.find,
  Select: KeyboardScanCode.select,
  Open: KeyboardScanCode.execute,

  // Media
  MediaPlayPause: KeyboardScanCode.audioPlay,
  MediaStop: KeyboardScanCode.audioStop,
  MediaTrackNext: KeyboardScanCode.audioNext,
  MediaTrackPrevious: KeyboardScanCode.audioPrev,
  MediaSelect: KeyboardScanCode.mediaSelect,
  AudioVolumeMute: KeyboardScanCode.audioMute,
  AudioVolumeUp: KeyboardScanCode.volumeup,
  AudioVolumeDown: KeyboardScanCode.volumedown,

  // Launch and browser
  LaunchApp1: KeyboardScanCode.app1,
  LaunchApp2: KeyboardScanCode.app2,
  LaunchMail: KeyboardScanCode.mail,
  BrowserBack: KeyboardScanCode.acBack,
  BrowserForward: KeyboardScanCode.acForward,
  BrowserHome: KeyboardScanCode.acHome,
  BrowserRefresh: KeyboardScanCode.acRefresh,
  BrowserSearch: KeyboardScanCode.acSearch,
  BrowserStop: KeyboardScanCode.acStop,
  BrowserFavorites: KeyboardScanCode.acBookmarks,

  // Japanese and Korean input keys
  IntlRo: KeyboardScanCode.international1,
  KanaMode: KeyboardScanCode.international2,
  IntlYen: KeyboardScanCode.international3,
  Convert: KeyboardScanCode.international4,
  NonConvert: KeyboardScanCode.international5,
  Lang1: KeyboardScanCode.lang1,
  Lang2: KeyboardScanCode.lang2,
  Lang3: KeyboardScanCode.lang3,
  Lang4: KeyboardScanCode.lang4,
  Lang5: KeyboardScanCode.lang5,
};
