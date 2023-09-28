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

module retrograde.wasm.conv;

version (WebAssembly)  :  //

import retrograde.std.string : String, s, cStrToString = toString;

String toString(T)(T val)
        if (is(T == int) || is(T == long) || is(T == size_t) || is(T == float) || is(T == double)
        || is(T == uint) || is(T == ulong)) {
    enum maxDigits = (char.sizeof * T.sizeof - 1) / 3 + 9;
    char[maxDigits] str = '\0';

    static if (is(T == float) || is(T == double)) {
        scalarToString(str.ptr, maxDigits, val);
    }

    static if ((is(T == int) || is(T == long)) && !is(T == uint) && !is(T == ulong)) {
        integralToString(str.ptr, maxDigits, val);
    }

    static if (is(T == uint) || is(T == ulong)) {
        unsignedIntegralToString(str.ptr, maxDigits, val);
    }

    return str.ptr.cStrToString().s;
}

export extern (C) void integralToString(char* str, uint ptrLength, long val);
export extern (C) void unsignedIntegralToString(char* str, uint ptrLength, ulong val);
export extern (C) void scalarToString(char* str, uint ptrLength, double val);
