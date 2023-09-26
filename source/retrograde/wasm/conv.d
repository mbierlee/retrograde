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

import retrograde.std.string : String, s;

String toString(T)(T val)
        if ((is(T == int) || is(T == long) || is(T == size_t)) && !is(T == uint) && !is(T == ulong)) {
    return integralToString(val).s;
}

String toString(T)(T val) if (is(T == uint) || is(T == ulong)) {
    return unsignedIntegralToString(val).s;
}

String toString(T)(T val) if (is(T == float) || is(T == double)) {
    return scalarToString(val).s;
}

export extern (C) string integralToString(long val);
export extern (C) string unsignedIntegralToString(ulong val);
export extern (C) string scalarToString(double val);
