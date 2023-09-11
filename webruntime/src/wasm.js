export default class WasmModule {
  url;
  imports;
  memory;
  instance;

  constructor(url, imports) {
    this.url = url;
    this.imports = imports;
    this.memory = null;
    this.instance = null;
  }

  init() {
    let importObject = {
      env: this.imports,
    };

    return WebAssembly.instantiateStreaming(fetch(this.url), importObject).then(
      (res) => {
        this.instance = res.instance;
        this.memory = res.instance.exports.memory;
      }
    );
  }

  start() {
    this.instance.exports._start();
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
      length * floatSize
    );

    for (let i = 0; i < length; i++) {
      const val = dataview.getFloat32(i * floatSize, true);
      array[i] = val;
    }

    return array;
  }

  getUnsignedInt32Array(pointer, length) {
    const uintSize = 4;
    const array = new Uint32Array(length);
    const dataview = new DataView(
      this.memory.buffer,
      pointer,
      length * uintSize
    );

    for (let i = 0; i < length; i++) {
      const val = dataview.getUint32(i * uintSize, true);
      array[i] = val;
    }

    return array;
  }
}
