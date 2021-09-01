/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.functional;

/**
 * Map values of one array into another.
 */
OutType[N] map(InType, OutType, size_t N)(const InType[N] values,
        OutType function(InType) pure nothrow @nogc @safe f) {
    OutType[N] outValues;
    // outValues.length = values.length;
    for (size_t i; i < values.length; i++) {
        outValues[i] = f(values[i]);
    }

    return outValues;
}

/// ditto
OutType[] map(InType, OutType)(const InType[] values,
        OutType function(InType) pure nothrow @nogc @safe f) {
    OutType[] outValues;
    outValues.length = values.length;
    for (size_t i; i < values.length; i++) {
        outValues[i] = f(values[i]);
    }

    return outValues;
}

// Map tests
version (unittest) {
    @("Map array of same types")
    unittest {
        const uint[4] values = [1, 2, 3, 4];
        const uint[4] expected = [2, 4, 6, 8];
        const uint[4] actual = cast(uint[4]) values.map((uint x) => x * 2);
        assert(actual == expected);
    }

    @("Map array of different types")
    unittest {
        const uint[4] values = [1, 2, 3, 4];
        const double[4] expected = [1.1, 2.1, 3.1, 4.1];
        const double[4] actual = values.map((uint x) => x + 0.1);
        assert(actual == expected);
    }

    @("Map dynamic array")
    unittest {
        const uint[] values = [1, 2, 3, 4];
        const uint[] expected = [2, 3, 4, 5];
        const uint[] actual = values.map((uint x) => x + 1);
        assert(actual == expected);
    }
}
