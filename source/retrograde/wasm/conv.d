/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
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
    static if (is(T == float) || is(T == double)) {
        // Scalars are written in fixed notation, which spells out every digit
        // of the integer part: at its longest that is one digit more than the
        // maximum decimal exponent of T, with the sign, the point, the six
        // decimals and the terminator on top of it.
        enum maxDigits = T.max_10_exp + 10;
    } else {
        // A binary digit is worth less than a third of a decimal one, leaving
        // room to spare for the sign and the terminator.
        enum maxDigits = (bitsPerByte * T.sizeof - 1) / 3 + 9;
    }

    char[maxDigits] str = '\0';

    // The writer is only given the room before the last byte: that one is left
    // as the terminator that cStrToString goes by, which a string filling the
    // buffer to the brim would otherwise write over.
    enum maxLength = maxDigits - 1;

    static if (is(T == float) || is(T == double)) {
        scalarToString(str.ptr, maxLength, val);
    }

    static if ((is(T == int) || is(T == long)) && !is(T == uint) && !is(T == ulong)) {
        integralToString(str.ptr, maxLength, val);
    }

    static if (is(T == uint) || is(T == ulong)) {
        unsignedIntegralToString(str.ptr, maxLength, val);
    }

    return str.ptr.cStrToString();
}

/// The bits in a byte, which $(D core.stdc.limits.CHAR_BIT) says on native.
private enum bitsPerByte = 8;

extern (C) void integralToString(char* str, uint ptrLength, long val);
extern (C) void unsignedIntegralToString(char* str, uint ptrLength, ulong val);
extern (C) void scalarToString(char* str, uint ptrLength, double val);
