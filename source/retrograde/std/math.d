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

///  --- Tests ---

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
}
