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

module retrograde.std.array;

import retrograde.std.math : approxEqual;

bool equals(T, size_t N)(const T[N] lhs, const T[N] rhs) {
    for (size_t i = 0; i < N; ++i) {
        if (lhs[i] != rhs[i]) {
            return false;
        }
    }

    return true;
}

bool approxEquals(T, size_t N)(const T[N] lhs, const T[N] rhs) {
    for (size_t i = 0; i < N; ++i) {
        if (!lhs[i].approxEqual(rhs[i])) {
            return false;
        }
    }

    return true;
}
