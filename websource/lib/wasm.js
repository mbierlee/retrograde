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

  async start() {
    if (this.instance == null) {
      await this.init();
    }

    this.instance.exports._start();
  }

  getString(pointer, length) {
    const buffer = new Uint8Array(this.memory.buffer, pointer, length);
    return new TextDecoder("utf-8").decode(buffer);
  }
}
