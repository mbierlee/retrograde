/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.std.stdio;

version (WebAssembly) {
    public import retrograde.wasm.stdio;
} else {
    public import retrograde.native.stdio;
}

void writeln(T)(T value) {
    static if (is(T == string)) {
        writelnStr(value);
    } else static if (is(T == uint)) {
        writelnUint(value);
    } else static if (is(T == int)) {
        writelnInt(value);
    } else static if (is(T == double)) {
        writelnDouble(value);
    } else static if (is(T == float)) {
        writelnFloat(value);
    } else static if (is(T == char)) {
        writelnChar(value);
    } else static if (is(T == ubyte)) {
        writelnUbyte(value);
    } else static if (is(T == byte)) {
        writelnByte(value);
    } else static if (is(T == bool)) {
        writelnBool(value);
    } else {
        static assert(0, "Unsupported type");
    }
}
