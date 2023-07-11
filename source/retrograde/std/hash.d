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

module retrograde.std.hash;

/** 
 * Calculate the hash of any arbitrary value.
 */
ulong hashOf(T)(ref T value) nothrow @trusted {
    auto ptr = cast(ubyte*)&value;
    ulong hash = 0;

    foreach (i; 0 .. T.sizeof) {
        hash = hash * 33 + ptr[i];
    }

    return hash;
}

/// ditto
ulong hashOf(T)(T value) nothrow @trusted {
    return hashOf(value);
}

/** 
 * Calculate the hash of a string.
 */
ulong hashOf(string value) nothrow @trusted {
    ulong hash = 0;

    foreach (i; 0 .. value.length) {
        hash = hash * 33 + value[i];
    }

    return hash;
}

void runHashTests() {
    import retrograde.std.test : test, writeSection;

    struct TestStruct {
        int a;
        int b;
        int c;
    }

    writeSection("-- Hash tests --");

    test("Calculate hash of an int", () {
        int value = 123;
        ulong hash = hashOf(value);
        assert(hash == 4_420_251);
    });

    test("Calculate hash of a string", () {
        string value = "Hello world, I am a hash!";
        ulong hash = hashOf(value);
        assert(hash == 4_408_556_017_716_444_805);
    });

    test("Calculate hash of a struct", () {
        TestStruct value;
        value.a = 1;
        value.b = 2;
        value.c = 3;
        ulong hash = hashOf(value);
        assert(hash == 50_542_191_750_720_582);
    });
}
