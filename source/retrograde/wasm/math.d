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

module retrograde.wasm.math;

version (WebAssembly)  :  //

version (LDC) {
    // https://github.com/ldc-developers/druntime/blob/ldc/src/ldc/intrinsics.di
    import ldc.intrinsics : llvm_ceil, llvm_floor;

    alias ceil = llvm_ceil;
    alias floor = llvm_floor;
}
