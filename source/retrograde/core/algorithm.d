/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2022 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.algorithm;

ReturnType withHeadOrElse(ElementType, ReturnType)(ElementType[] xs, ReturnType delegate(
        ElementType) fn, ReturnType orElse) {
    return xs.length > 0 ? fn(xs[0]) : orElse;
}

ReturnType[] map(ElementType, ReturnType)(ElementType[] xs, ReturnType delegate(ElementType) fn) {
    ReturnType[] result;
    foreach (ElementType x; xs) {
        result ~= fn(x);
    }

    return result;
}

T[] flatten(T)(T[][] xs) {
    T[] result;
    foreach (T[] ys; xs) {
        foreach (T y; ys) {
            result ~= y;
        }
    }

    return result;
}

ReturnType[] flatMap(ElementType, ReturnType)(ElementType[] xs, ReturnType[]delegate(ElementType) fn) {
    return xs.map(fn).flatten;
}

void forEach(ElementType)(ElementType[] xs, void delegate(ElementType) fn) {
    foreach (ElementType x; xs) {
        fn(x);
    }
}

version (unittest) {
    // withHeadOrElse
    unittest {
        assert([1, 2, 3].withHeadOrElse((int n) => n + 1, 6) == 2);
        assert([].withHeadOrElse((int n) => n + 1, 6) == 6);
    }

    // map test
    unittest {
        import std.conv : to;

        assert([1, 2, 3].map((int n) => ('a' + n).to!char) == ['b', 'c', 'd']);
    }

    // flatten test
    unittest {
        assert([[1], [2, 3], [4, 5, 6]].flatten == [1, 2, 3, 4, 5, 6]);
    }

    // flatMap test
    unittest {
        assert([1, 2, 3, 4, 5, 6].flatMap((int n) => [n * 10]) == [
                10, 20, 30, 40, 50, 60
            ]);
    }

    // forEach test
    unittest {
        auto sum = 0;
        [1, 2, 3, 4, 5, 6].forEach((int n) { sum += n; });
        assert(sum == 21);
    }
}
