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

module retrograde.compiler.ldc;

version (LDC)  :  //

import retrograde.std.memory : memmove, memcpy;

/** 
 * Reimplementation of D Runtime array copy that might be used by LDC in debug mode.
 * Note that bounds checking is only available in debug builds.
 */
extern (C) void _d_array_slice_copy(void* dest, size_t destlen, void* src, size_t srclen, size_t elemsz) {
    debug {
        auto res = memmove(dest, src, destlen * elemsz);
        assert(res is dest, "Array slice copy failed.");
    } else {
        memcpy(dest, src, destlen * elemsz);
    }
}
