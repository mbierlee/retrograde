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

module retrograde.native.math;

version (Native)  :  //

import core.stdc.math : ceil, ceilf, ceill, floor, floorf, floorl;

T ceil(T)(T value) {
    static if (is(T == float)) {
        return ceilf(value);
    } else static if (is(T == double)) {
        return ceil(value);
    } else static if (is(T == real)) {
        return ceill(value);
    } else {
        static assert(0, "Unsupported type");
    }
}

T floor(T)(T value) {
    static if (is(T == float)) {
        return floorf(value);
    } else static if (is(T == double)) {
        return floor(value);
    } else static if (is(T == real)) {
        return floorl(value);
    } else {
        static assert(0, "Unsupported type");
    }
}
