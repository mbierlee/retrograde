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
            this.mapKeyChar(e.key),
            this.mapKeyCode(e.code),
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
   * Maps a KeyboardEvent.code value to its KeyboardKeyCode value.
   * Unmapped keys become KeyboardKeyCode.unknown.
   */
  mapKeyCode(jsKeyCode) {
    const keyCode = keyCodeMap[jsKeyCode];
    return keyCode === undefined ? KeyboardKeyCode.unknown : keyCode;
  }

  /**
   * Maps a KeyboardEvent.key value to the Unicode code point of the character
   * it produced. Keys that do not produce a character have a key value that is
   * a name rather than a character, such as "Enter", and become 0.
   */
  mapKeyChar(jsKey) {
    const codePoint = jsKey.codePointAt(0);
    if (codePoint === undefined) {
      return 0;
    }

    // Code points outside the BMP are two UTF-16 code units long, so the key
    // value is only a single character when it is as long as its first code
    // point.
    return String.fromCodePoint(codePoint).length === jsKey.length
      ? codePoint
      : 0;
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
   * Collects the modifiers active during a keyboard event into a
   * KeyboardKeyModifier bit mask.
   *
   * Keyboard events only report that a modifier is active, not which side of
   * the keyboard it is held on, so the left and right specific flags come from
   * the modifier keys tracked by trackModifierKey instead.
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

    if (e.getModifierState("Shift")) {
      modifiers |= KeyboardKeyModifier.shift;
    }

    if (e.getModifierState("Control")) {
      modifiers |= KeyboardKeyModifier.ctrl;
    }

    if (e.getModifierState("Alt")) {
      modifiers |= KeyboardKeyModifier.alt;
    }

    if (e.getModifierState("Meta")) {
      modifiers |= KeyboardKeyModifier.gui;
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
 * Mirror of KeyboardKeyCode in source/retrograde/engine/input.d, in declaration
 * order. The D enum assigns no explicit values, so a name's index here is its
 * numeric value. Keep this list in sync with the enum; inserting a name in the
 * middle shifts every value after it.
 */
// prettier-ignore
const keyCodeNames = [
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

const KeyboardKeyCode = Object.fromEntries(
  keyCodeNames.map((name, value) => [name, value]),
);

/**
 * Mirror of InputEventAction in source/retrograde/engine/input.d. As with
 * KeyboardKeyCode, the D enum assigns no explicit values, so these are the
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
  ctrl: 1 << 12,
  shift: 1 << 13,
  alt: 1 << 14,
  gui: 1 << 15,
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
 * Maps KeyboardEvent.code values to KeyboardKeyCode values.
 *
 * Code values identify the physical key, independent of keyboard layout and
 * modifier state, which is what KeyboardKeyCode describes as well: it names
 * the key by its position on a US layout, tells left and right modifiers
 * apart and has separate entries for the keypad.
 */
const keyCodeMap = {
  // Letters
  KeyA: KeyboardKeyCode.a,
  KeyB: KeyboardKeyCode.b,
  KeyC: KeyboardKeyCode.c,
  KeyD: KeyboardKeyCode.d,
  KeyE: KeyboardKeyCode.e,
  KeyF: KeyboardKeyCode.f,
  KeyG: KeyboardKeyCode.g,
  KeyH: KeyboardKeyCode.h,
  KeyI: KeyboardKeyCode.i,
  KeyJ: KeyboardKeyCode.j,
  KeyK: KeyboardKeyCode.k,
  KeyL: KeyboardKeyCode.l,
  KeyM: KeyboardKeyCode.m,
  KeyN: KeyboardKeyCode.n,
  KeyO: KeyboardKeyCode.o,
  KeyP: KeyboardKeyCode.p,
  KeyQ: KeyboardKeyCode.q,
  KeyR: KeyboardKeyCode.r,
  KeyS: KeyboardKeyCode.s,
  KeyT: KeyboardKeyCode.t,
  KeyU: KeyboardKeyCode.u,
  KeyV: KeyboardKeyCode.v,
  KeyW: KeyboardKeyCode.w,
  KeyX: KeyboardKeyCode.x,
  KeyY: KeyboardKeyCode.y,
  KeyZ: KeyboardKeyCode.z,

  // Digit row
  Digit0: KeyboardKeyCode.zero,
  Digit1: KeyboardKeyCode.one,
  Digit2: KeyboardKeyCode.two,
  Digit3: KeyboardKeyCode.three,
  Digit4: KeyboardKeyCode.four,
  Digit5: KeyboardKeyCode.five,
  Digit6: KeyboardKeyCode.six,
  Digit7: KeyboardKeyCode.seven,
  Digit8: KeyboardKeyCode.eight,
  Digit9: KeyboardKeyCode.nine,

  // Punctuation
  Backquote: KeyboardKeyCode.grave,
  Minus: KeyboardKeyCode.minus,
  Equal: KeyboardKeyCode.equals,
  BracketLeft: KeyboardKeyCode.leftBracket,
  BracketRight: KeyboardKeyCode.rightBracket,
  Backslash: KeyboardKeyCode.backslash,
  Semicolon: KeyboardKeyCode.semicolon,
  Quote: KeyboardKeyCode.apostrophe,
  Comma: KeyboardKeyCode.comma,
  Period: KeyboardKeyCode.period,
  Slash: KeyboardKeyCode.slash,
  IntlBackslash: KeyboardKeyCode.nonusBackslash,

  // Whitespace and editing
  Space: KeyboardKeyCode.space,
  Enter: KeyboardKeyCode.enter,
  Tab: KeyboardKeyCode.tab,
  Backspace: KeyboardKeyCode.backspace,
  Delete: KeyboardKeyCode.deleteKey,
  Insert: KeyboardKeyCode.insert,
  Escape: KeyboardKeyCode.escape,

  // Navigation
  ArrowUp: KeyboardKeyCode.up,
  ArrowDown: KeyboardKeyCode.down,
  ArrowLeft: KeyboardKeyCode.left,
  ArrowRight: KeyboardKeyCode.right,
  Home: KeyboardKeyCode.home,
  End: KeyboardKeyCode.end,
  PageUp: KeyboardKeyCode.pageUp,
  PageDown: KeyboardKeyCode.pageDown,

  // Modifiers and locks
  ShiftLeft: KeyboardKeyCode.leftShift,
  ShiftRight: KeyboardKeyCode.rightShift,
  ControlLeft: KeyboardKeyCode.leftCtrl,
  ControlRight: KeyboardKeyCode.rightCtrl,
  AltLeft: KeyboardKeyCode.leftAlt,
  AltRight: KeyboardKeyCode.rightAlt,
  MetaLeft: KeyboardKeyCode.leftGui,
  MetaRight: KeyboardKeyCode.rightGui,
  ContextMenu: KeyboardKeyCode.application,
  CapsLock: KeyboardKeyCode.capslock,
  NumLock: KeyboardKeyCode.numlockClear,
  ScrollLock: KeyboardKeyCode.scrolllock,

  // Function keys
  F1: KeyboardKeyCode.f1,
  F2: KeyboardKeyCode.f2,
  F3: KeyboardKeyCode.f3,
  F4: KeyboardKeyCode.f4,
  F5: KeyboardKeyCode.f5,
  F6: KeyboardKeyCode.f6,
  F7: KeyboardKeyCode.f7,
  F8: KeyboardKeyCode.f8,
  F9: KeyboardKeyCode.f9,
  F10: KeyboardKeyCode.f10,
  F11: KeyboardKeyCode.f11,
  F12: KeyboardKeyCode.f12,
  F13: KeyboardKeyCode.f13,
  F14: KeyboardKeyCode.f14,
  F15: KeyboardKeyCode.f15,
  F16: KeyboardKeyCode.f16,
  F17: KeyboardKeyCode.f17,
  F18: KeyboardKeyCode.f18,
  F19: KeyboardKeyCode.f19,
  F20: KeyboardKeyCode.f20,
  F21: KeyboardKeyCode.f21,
  F22: KeyboardKeyCode.f22,
  F23: KeyboardKeyCode.f23,
  F24: KeyboardKeyCode.f24,
  F25: KeyboardKeyCode.f25,

  // Keypad
  Numpad0: KeyboardKeyCode.keypadZero,
  Numpad1: KeyboardKeyCode.keypadOne,
  Numpad2: KeyboardKeyCode.keypadTwo,
  Numpad3: KeyboardKeyCode.keypadThree,
  Numpad4: KeyboardKeyCode.keypadFour,
  Numpad5: KeyboardKeyCode.keypadFive,
  Numpad6: KeyboardKeyCode.keypadSix,
  Numpad7: KeyboardKeyCode.keypadSeven,
  Numpad8: KeyboardKeyCode.keypadEight,
  Numpad9: KeyboardKeyCode.keypadNine,
  NumpadAdd: KeyboardKeyCode.keypadPlus,
  NumpadSubtract: KeyboardKeyCode.keypadMinus,
  NumpadMultiply: KeyboardKeyCode.keypadMultiply,
  NumpadStar: KeyboardKeyCode.keypadMultiply,
  NumpadDivide: KeyboardKeyCode.keypadDivide,
  NumpadDecimal: KeyboardKeyCode.keypadPeriod,
  NumpadComma: KeyboardKeyCode.keypadComma,
  NumpadEnter: KeyboardKeyCode.keypadEnter,
  NumpadEqual: KeyboardKeyCode.keypadEquals,
  NumpadHash: KeyboardKeyCode.kpHash,
  NumpadBackspace: KeyboardKeyCode.kpBackspace,
  NumpadClear: KeyboardKeyCode.kpClear,
  NumpadClearEntry: KeyboardKeyCode.kpClearentry,
  NumpadParenLeft: KeyboardKeyCode.kpLeftparen,
  NumpadParenRight: KeyboardKeyCode.kpRightparen,
  NumpadMemoryAdd: KeyboardKeyCode.kpMemadd,
  NumpadMemorySubtract: KeyboardKeyCode.kpMemsubtract,
  NumpadMemoryClear: KeyboardKeyCode.kpMemclear,
  NumpadMemoryRecall: KeyboardKeyCode.kpMemrecall,
  NumpadMemoryStore: KeyboardKeyCode.kpMemstore,

  // System
  PrintScreen: KeyboardKeyCode.printscreen,
  Pause: KeyboardKeyCode.pause,
  Power: KeyboardKeyCode.power,
  Sleep: KeyboardKeyCode.sleep,
  Eject: KeyboardKeyCode.eject,
  Help: KeyboardKeyCode.help,

  // Editing commands
  Again: KeyboardKeyCode.again,
  Undo: KeyboardKeyCode.undo,
  Cut: KeyboardKeyCode.cut,
  Copy: KeyboardKeyCode.copy,
  Paste: KeyboardKeyCode.paste,
  Find: KeyboardKeyCode.find,
  Select: KeyboardKeyCode.select,
  Open: KeyboardKeyCode.execute,

  // Media
  MediaPlayPause: KeyboardKeyCode.audioPlay,
  MediaStop: KeyboardKeyCode.audioStop,
  MediaTrackNext: KeyboardKeyCode.audioNext,
  MediaTrackPrevious: KeyboardKeyCode.audioPrev,
  MediaSelect: KeyboardKeyCode.mediaSelect,
  AudioVolumeMute: KeyboardKeyCode.audioMute,
  AudioVolumeUp: KeyboardKeyCode.volumeup,
  AudioVolumeDown: KeyboardKeyCode.volumedown,

  // Launch and browser
  LaunchApp1: KeyboardKeyCode.app1,
  LaunchApp2: KeyboardKeyCode.app2,
  LaunchMail: KeyboardKeyCode.mail,
  BrowserBack: KeyboardKeyCode.acBack,
  BrowserForward: KeyboardKeyCode.acForward,
  BrowserHome: KeyboardKeyCode.acHome,
  BrowserRefresh: KeyboardKeyCode.acRefresh,
  BrowserSearch: KeyboardKeyCode.acSearch,
  BrowserStop: KeyboardKeyCode.acStop,
  BrowserFavorites: KeyboardKeyCode.acBookmarks,

  // Japanese and Korean input keys
  IntlRo: KeyboardKeyCode.international1,
  KanaMode: KeyboardKeyCode.international2,
  IntlYen: KeyboardKeyCode.international3,
  Convert: KeyboardKeyCode.international4,
  NonConvert: KeyboardKeyCode.international5,
  Lang1: KeyboardKeyCode.lang1,
  Lang2: KeyboardKeyCode.lang2,
  Lang3: KeyboardKeyCode.lang3,
  Lang4: KeyboardKeyCode.lang4,
  Lang5: KeyboardKeyCode.lang5,
};
