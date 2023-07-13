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

import retrograde.std.string : String;

version (WebAssembly) {
    import retrograde.wasm.stdio;
} else version (Native) {
    import retrograde.native.stdio;
} else {
    static assert(false, "No stdio implementation available for target platform. Provide one of these versions: WebAssembly, Native");
}

/** 
 * Prints a value to the standard output stream.
 */
void writeln(T)(T value) {
    static if (is(T == string)) {
        writelnStr(value);
    } else static if (is(T == String)) {
        writelnStr(value.toString());
    } else static if (is(T == uint)) {
        writelnUint(value);
    } else static if (is(T == int)) {
        writelnInt(value);
    } else static if (is(T == ulong)) {
        writelnUlong(value);
    } else static if (is(T == long)) {
        writelnLong(value);
    } else static if (is(T == double)) {
        writelnDouble(value);
    } else static if (is(T == float)) {
        writelnFloat(value);
    } else static if (is(T == char)) {
        writelnChar(value);
    } else static if (is(T == immutable(char))) {
        writelnChar(value);
    } else static if (is(T == wchar)) {
        writelnWChar(value);
    } else static if (is(T == dchar)) {
        writelnDChar(value);
    } else static if (is(T == ubyte)) {
        writelnUbyte(value);
    } else static if (is(T == byte)) {
        writelnByte(value);
    } else static if (is(T == bool)) {
        writelnBool(value);
    } else {
        static assert(0, "Unsupported type: " ~ T.stringof);
    }
}

/** 
 * Prints a value to the standard error stream.
 */
void writeErrLn(T)(T value) {
    static if (is(T == string)) {
        writeErrLnStr(value);
    } else static if (is(T == String)) {
        writeErrLnStr(value.toString());
    } else static if (is(T == uint)) {
        writeErrLnUint(value);
    } else static if (is(T == int)) {
        writeErrLnInt(value);
    } else static if (is(T == ulong)) {
        writeErrLnUlong(value);
    } else static if (is(T == long)) {
        writeErrLnLong(value);
    } else static if (is(T == double)) {
        writeErrLnDouble(value);
    } else static if (is(T == float)) {
        writeErrLnFloat(value);
    } else static if (is(T == char)) {
        writeErrLnChar(value);
    } else static if (is(T == immutable(char))) {
        writeErrLnChar(value);
    } else static if (is(T == wchar)) {
        writeErrLnWChar(value);
    } else static if (is(T == dchar)) {
        writeErrLnDChar(value);
    } else static if (is(T == ubyte)) {
        writeErrLnUbyte(value);
    } else static if (is(T == byte)) {
        writeErrLnByte(value);
    } else static if (is(T == bool)) {
        writeErrLnBool(value);
    } else {
        static assert(0, "Unsupported type: " ~ T.stringof);
    }
}
