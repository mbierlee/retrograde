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

module retrograde.std.math;

version (Native) {
    public import retrograde.native.math;
} else version (WebAssembly) {
    public import retrograde.wasm.math;
}

bool approxEqual(T)(T lhs, T rhs, T deviation = 0.0001)
        if (is(T == float) || is(T == double) || is(T == real)) {
    if (lhs > 0) {
        return (lhs - deviation) < rhs && (lhs + deviation) > rhs;
    } else {
        return (lhs + deviation) > rhs && (lhs - deviation) < rhs;
    }
}

version (UnitTesting)  :  ///

void runMathTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Math tests --");

    test("ceil", {
        assert(ceil(1.0) == 1.0);
        assert(ceil(1.1) == 2.0);
        assert(ceil(1.5) == 2.0);
        assert(ceil(1.9) == 2.0);
        assert(ceil(2.0) == 2.0);
    });

    test("floor", {
        assert(floor(1.0) == 1.0);
        assert(floor(1.1) == 1.0);
        assert(floor(1.5) == 1.0);
        assert(floor(1.9) == 1.0);
        assert(floor(2.0) == 2.0);
    });

    test("pow", {
        assert(pow(10.0, 1.0) == 10.0);
        assert(pow(5.0, 5.0) == 3125.0);
        assert(pow(10.0, 0.0) == 1.0);
    });

    test("approxEqual", {
        assert(approxEqual(0.1, 0.1));
        assert(approxEqual(0.1, 0.10));
        assert(!approxEqual(0.2, 0.1));
        assert(!approxEqual(1, 0.1));

        assert(approxEqual(-0.1, -0.1));
        assert(approxEqual(-0.1, -0.10));
        assert(!approxEqual(-0.2, -0.1));
        assert(!approxEqual(-1, -0.1));
    });

}
