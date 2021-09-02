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

//TODO: Maybes (Options in Scala) Perhaps use Dlang nullable?
//TODO: flatten
//TODO: reduce
//TODO: filter
//TODO: find

/**
 * Return the first element of an array.
 *
 * Params:
 *  xs = Array of values.
 *
 * Throws: RangeViolation when the array is empty.
 */
const(T) head(T, size_t N)(const T[N] xs) pure nothrow @nogc @safe {
    return xs[0];
}

/// ditto
const(T) head(T)(const T[] xs) pure nothrow @nogc @safe {
    return xs[0];
}

/**
 * Returns the array without the first element.
 *
 * It is tehcnically a slice from the second element to the end.
 *
 * Params:
 *  xs = Array of values.
 */
const(T[NOut]) tail(T, size_t N, size_t NOut = N - 1)(const T[N] xs) pure nothrow @nogc @safe {
    return xs[1 .. $];
}

/// ditto
const(T)[] tail(T)(const T[] xs) pure nothrow @nogc @safe {
    return xs[1 .. $];
}

/**
 * Map values of one array into another.
 *
 * Params:
 *  values = Array of values to be mapped.
 *  f = Function applied to each value of the array.
 */
const(OutType[N]) map(InType, OutType, size_t N)(const InType[N] values,
        OutType function(InType) pure nothrow @nogc @safe f) pure nothrow @nogc @safe {
    OutType[N] outValues;
    // outValues.length = values.length;
    for (size_t i; i < values.length; i++) {
        outValues[i] = f(values[i]);
    }

    return outValues;
}

/// ditto
const(OutType[]) map(InType, OutType)(const InType[] values,
        OutType function(InType) pure nothrow @nogc @safe f) pure nothrow @safe {
    OutType[] outValues;
    outValues.length = values.length;
    for (size_t i; i < values.length; i++) {
        outValues[i] = f(values[i]);
    }

    return outValues;
}

/**
 * Folds, or accumulates, all values of an array.
 *
 * The array is traversed from right to left.
 *
 * Params:
 *  values = Array of values to be folded.
 *  initial = Initial value used as first accumulated value.
 *  f = Combinator function applied to each value. Where signature is:
 *      T function (T accumulator, T value)
 *          accumulator = Accumulation of the previous iteration (or initial if this is the first.)
 *          value = Value of the array being folded.
 */
const(T) fold(T, size_t N)(const T[N] values, T initial, T function(T, T) pure nothrow @safe f) {
    static if (N == 0) {
        return initial;
    } else {
        return values.tail.fold(f(initial, values.head), f);
    }
}

/// ditto
const(T) fold(T)(const T[] values, T initial, T function(T, T) pure nothrow @safe f) {
    if (values.length == 0) {
        return initial;
    } else {
        return values.tail.fold(f(initial, values.head), f);
    }
}

/// ditto
alias foldLeft = fold;

/**
 * Folds, or accumulates, all values of an array.
 *
 * The array is traversed from right to left.
 *
 * Params:
 *  values = Array of values to be folded.
 *  initial = Initial value used as first accumulated value.
 *  f = Combinator function applied to each value. Where signature is:
 *      T function (T accumulator, T value)
 *          accumulator = Accumulation of the previous iteration (or initial if this is the first.)
 *          value = Value of the array being folded.
 */
const(T) foldRight(T, size_t N)(const T[N] values, T initial, T function(T, T) pure nothrow @safe f) {
    static if (N == 0) {
        return initial;
    } else {
        return values[0 .. $ - 1].foldRight(f(initial, values[$ - 1]), f);
    }
}

/// ditto
const(T) foldRight(T)(const T[] values, T initial, T function(T, T) pure nothrow @safe f) {
    if (values.length == 0) {
        return initial;
    } else {
        return values[0 .. $ - 1].foldRight(f(initial, values[$ - 1]), f);
    }
}

/**
 * Sums up the values of the array using the + operator.
 *
 * Params:
 *  values = Array of values to be summed.
 */
const(T) sum(T, size_t N)(const T[N] values) {
    return values.fold(0, (uint acc, uint x) => acc + x);
}

/// ditto
const(T) sum(T)(const T[] values) {
    return values.fold(0, (uint acc, uint x) => acc + x);
}

// Head tests
version (unittest) {
    @("Get head of array")
    unittest {
        const uint[4] values = [1, 2, 3, 4];
        assert(values.head == 1);
    }

    @("Get head of dynamic array")
    unittest {
        const uint[] values = [1, 2, 3, 4];
        assert(values.head == 1);
    }
}

// Tail tests
version (unittest) {
    @("Get tail of array")
    unittest {
        const uint[4] values = [1, 2, 3, 4];
        assert(values.tail == [2, 3, 4]);
    }

    @("Get tail of dynamic array")
    unittest {
        const uint[] values = [1, 2, 3, 4];
        assert(values.tail == [2, 3, 4]);
    }
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

// Fold tests
version (unittest) {
    @("Fold numbers")
    unittest {
        const uint[4] values = [1, 2, 3, 4];
        auto const total = values.fold(0, (uint acc, uint x) => acc + x);
        assert(total == 10);
    }

    @("Fold strings")
    unittest {
        const string[4] values = ["A", "B", "C", "D"];
        auto const total = values.fold("", (string acc, string x) => acc ~ x);
        assert(total == "ABCD");
    }

    @("Fold numbers in dynamic array")
    unittest {
        const uint[] values = [1, 2, 3, 4];
        auto const total = values.fold(0, (uint acc, uint x) => acc + x);
        assert(total == 10);
    }
}

// FoldLeft tests
version (unittest) {
    @("Fold numbers")
    unittest {
        const uint[4] values = [1, 2, 3, 4];
        auto const total = values.foldLeft(0, (uint acc, uint x) => acc + x);
        assert(total == 10);
    }

    @("Fold strings")
    unittest {
        const string[4] values = ["A", "B", "C", "D"];
        auto const total = values.foldLeft("", (string acc, string x) => acc ~ x);
        assert(total == "ABCD");
    }

    @("Fold numbers in dynamic array")
    unittest {
        const uint[] values = [1, 2, 3, 4];
        auto const total = values.foldLeft(0, (uint acc, uint x) => acc + x);
        assert(total == 10);
    }
}

// FoldRight tests
version (unittest) {
    @("Fold numbers")
    unittest {
        const uint[4] values = [1, 2, 3, 4];
        auto const total = values.foldRight(0, (uint acc, uint x) => acc + x);
        assert(total == 10);
    }

    @("Fold strings")
    unittest {
        const string[4] values = ["A", "B", "C", "D"];
        auto const total = values.foldRight("", (string acc, string x) => acc ~ x);
        assert(total == "DCBA");
    }

    @("Fold numbers in dynamic array")
    unittest {
        const uint[] values = [1, 2, 3, 4];
        auto const total = values.foldRight(0, (uint acc, uint x) => acc + x);
        assert(total == 10);
    }

}

// Sum tests
version (unittest) {
    @("Sum numbers")
    unittest {
        const uint[4] values = [1, 2, 3, 4];
        auto const total = values.sum();
        assert(total == 10);
    }

    @("Sum numbers in dynamic array")
    unittest {
        const uint[] values = [1, 2, 3, 4];
        auto const total = values.sum();
        assert(total == 10);
    }
}
