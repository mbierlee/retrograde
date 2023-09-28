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

module retrograde.native.conv;

version (Native)  :  //

import core.stdc.limits : CHAR_BIT;
import core.stdc.stdio : sprintf;

import retrograde.std.string : String, cStrToString = toString;

String toString(T)(T val)
        if (is(T == int) || is(T == long) || is(T == size_t) || is(T == uint)
        || is(T == ulong) || is(T == float) || is(T == double)) {

    enum maxDigits = (CHAR_BIT * T.sizeof - 1) / 3 + 9;

    static if (is(T == int)) {
        enum format = "%d";
    } else static if (is(T == uint)) {
        enum format = "%u";
    } else static if (is(T == ulong)) {
        enum format = "%lu";
    } else static if (is(T == long) || is(T == size_t)) {
        enum format = "%ld";
    } else static if (is(T == float) || is(T == double)) {
        enum format = "%f";
    }

    //TODO: Figure out how to deal with deprecation warning

    char[maxDigits] str = '\0';
    sprintf(str.ptr, format, val);
    return str.ptr.cStrToString();
}
