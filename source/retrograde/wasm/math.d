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
    import ldc.intrinsics : llvm_ceil, llvm_floor, llvm_pow, llvm_sqrt;

    import retrograde.std.math : PI;

    alias ceil = llvm_ceil;
    alias floor = llvm_floor;
    alias sqrt = llvm_sqrt;

    T pow(T)(T base, T exponent) {
        return cast(T) llvm_pow(cast(float) base, cast(float) exponent);
    }

    //TODO: Consider using browser's atan2. Benchmark to see if actually faster.
    T atan2(T)(T y, T x) {
        if (x > 0) {
            return atan(y / x);
        } else if (x < 0 && y >= 0) {
            return atan(y / x) + PI;
        } else if (x < 0 && y < 0) {
            return atan(y / x) - PI;
        } else if (x == 0 && y != 0) {
            return (y > 0) ? PI / 2 : -PI / 2;
        } else {
            return 0.0; // x and y are 0, undefined case, returning 0 for simplicity.
        }
    }

    //TODO: Consider using browser's atan. Benchmark to see if actually faster.
    T atan(T)(T x) {
        if (x > 1.0) {
            return (PI / 2) - atan(1.0 / x);
        } else if (x < -1.0) {
            return -(PI / 2) - atan(1.0 / x);
        }

        T result = 0.0;
        T powerOfX = x; // x^1
        T xSquared = x * x; // x^2

        // Calculate up to 10 terms
        for (int i = 1; i < 20; i += 2) {
            result += powerOfX / i - (powerOfX *= xSquared) / (i + 2); // Add and subtract alternating terms
        }

        return result;
    }
}
