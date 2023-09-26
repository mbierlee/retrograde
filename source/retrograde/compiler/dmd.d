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

module retrograde.compiler.dmd;

version (DigitalMars)  :  //

import retrograde.std.memory : memset;

/** 
 * Implementation of a mystically missing function used by the compiler. 
 *
 * Params:
 *  ptr: Pointer to the block of memory to fill.
 *  value: Value to be set.
 *  num: Number of bytes to be set to the value.
 * Returns: ptr as-is.
 */
export extern (C) void* _memsetFloat(void* ptr, float value, size_t num) {
    foreach (i; 0 .. num) {
        (cast(float*) ptr)[i] = value;
    }

    return ptr;
}

/** 
 * Implementation of a mystically missing function used by the compiler. 
 *
 * Params:
 *  ptr: Pointer to the block of memory to fill.
 *  value: Value to be set.
 *  num: Number of bytes to be set to the value.
 * Returns: ptr as-is.
 */
export extern (C) void* _memsetDouble(void* ptr, double value, size_t num) {
    foreach (i; 0 .. num) {
        (cast(double*) ptr)[i] = value;
    }

    return ptr;
}
