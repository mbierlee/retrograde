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

module retrograde.native.conv;

version (Native)  :  //

import core.stdc.limits : CHAR_BIT;
import core.stdc.stdio : sprintf;

import retrograde.std.string : String, cStrToString = toString;

String toString(T)(T val)
        if (is(T == int) || is(T == long) || is(T == size_t) || is(T == uint)
        || is(T == ulong) || is(T == float) || is(T == double)) {

    static if (is(T == float) || is(T == double)) {
        // %f spells out every digit of the integer part: at its longest that is
        // one digit more than the maximum decimal exponent of T, with the sign,
        // the point, the six decimals and the terminator on top of it. sprintf
        // writes past a buffer that cannot hold all of that.
        enum maxDigits = T.max_10_exp + 10;
    } else {
        // A binary digit is worth less than a third of a decimal one, leaving
        // room to spare for the sign and the terminator.
        enum maxDigits = (CHAR_BIT * T.sizeof - 1) / 3 + 9;
    }

    static if (is(T == int)) {
        enum format = "%d";
    } else static if (is(T == uint)) {
        enum format = "%u";
    } else static if (is(T == ulong)) {
        enum format = "%llu";
    } else static if (is(T == long)) {
        enum format = "%lld";
    } else static if (is(T == size_t)) {
        static if (size_t.sizeof == 8) {
            enum format = "%llu";
        } else {
            enum format = "%u";
        }
    } else static if (is(T == float) || is(T == double)) {
        enum format = "%f";
    }

    char[maxDigits] str = '\0';
    sprintf(str.ptr, format, val);
    return str.ptr.cStrToString();
}
