let memory;

function getString(pointer, length) {
  const buffer = new Uint8Array(memory.buffer, pointer, length);
  return new TextDecoder("utf-8").decode(buffer);
}

function getCString(pointer) {
  const buffer = new Uint8Array(memory.buffer, pointer);
  let length = 0;
  while (buffer[length] != 0) {
    length++;
  }

  return getString(pointer, length);
}

function writeString(string, pointer, maxLength) {
  const encodedString = new TextEncoder("utf-8").encode(string);
  if (encodedString.length > maxLength) {
    throw new Error(
      `String too large for storage destination: '${string}' (allocated size: ${maxLength})`
    );
  }

  const dataview = new DataView(memory.buffer, pointer, maxLength);
  encodedString.forEach((chr, i) => {
    dataview.setUint8(i, chr);
  });
}

//TODO: Get rid of this duplication by reusing the engine's Runtime somehow.

WebAssembly.instantiateStreaming(fetch("bin/wasmmemtest.wasm"), {
  env: {
    writelnStr: (msgLength, msgPtr) => {
      console.log(getString(msgPtr, msgLength));
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
      console.error(getString(msgPtr, msgLength));
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
    powf: (base, exponent) => {
      return Math.pow(base, exponent);
    },
    __assert: (assertionMsgPtr, srcFilePtr, srcLineNumber) => {
      const assertionMessage = getCString(assertionMsgPtr);
      const srcFile = getCString(srcFilePtr);
      console.error(
        `Assertion error: ${assertionMessage}\n    at ${srcFile}:${srcLineNumber}`
      );
    },
  },
}).then((res) => {
  memory = res.instance.exports.memory;
  res.instance.exports._start();
});
