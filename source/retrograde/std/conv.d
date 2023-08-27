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

module retrograde.std.conv;

import retrograde.std.string : String, stripNonNumeric, s;
import retrograde.std.math : pow;

int toInt(char c) {
    auto result = (cast(int) c) - (cast(int) '0');
    assert(result >= 0 && result <= 9);
    return result;
}

int toInt(string str) {
    auto convStr = str.s;
    return convStr.toInt;
}

T toIntegralNumber(T)(inout ref String str) if (is(T == int) || is(T == long)) {
    T result = 0;
    String sanitizedStr = str.stripNonNumeric();
    foreach (size_t i, char c; sanitizedStr) {
        double exp = sanitizedStr.length - i - 1;
        int digit = c.toInt;
        result += cast(int)(digit * pow(10.0, exp));
    }

    return result;
}

alias toInt = toIntegralNumber!int;
alias toLong = toIntegralNumber!long;

float toFloat(string str, char decimalChar = '.') {
    auto convStr = str.s;
    return convStr.toFloat(decimalChar);
}

T toRealNumber(T)(inout ref String str, char decimalChar = '.')
        if (is(T == float) || is(T == double) || is(T == real)) {
    String wholePart;
    String decimalPart;
    bool foundDecimal = false;
    foreach (char c; str) {
        if (c == decimalChar) {
            foundDecimal = true;
            continue;
        }

        if (foundDecimal) {
            decimalPart ~= c;
        } else {
            wholePart ~= c;
        }
    }

    decimalPart = decimalPart.stripNonNumeric;
    T result =
        cast(T) wholePart.toInt
        + (cast(T) decimalPart.toInt / pow(10, decimalPart.length));

    return result;
}

alias toFloat = toRealNumber!float;
alias toDouble = toRealNumber!double;
alias toReal = toRealNumber!real;

version (UnitTesting)  :  ///

void runConvTests() {
    import retrograde.std.test : test, writeSection;
    import retrograde.std.math : approxEqual;

    writeSection("-- Conv tests --");

    test("Convert char to int", {
        assert('1'.toInt == 1);
        assert('2'.toInt == 2);
        assert('3'.toInt == 3);
        assert('4'.toInt == 4);
        assert('5'.toInt == 5);
        assert('6'.toInt == 6);
        assert('7'.toInt == 7);
        assert('8'.toInt == 8);
        assert('9'.toInt == 9);
        assert('0'.toInt == 0);
    });

    test("Convert string to int", {
        assert("1".toInt == 1);
        assert("2".toInt == 2);
        assert("3".toInt == 3);
        assert("4".toInt == 4);
        assert("5".toInt == 5);
        assert("6".toInt == 6);
        assert("7".toInt == 7);
        assert("8".toInt == 8);
        assert("9".toInt == 9);
        assert("0".toInt == 0);

        assert("100".toInt == 100);
        assert("12345".toInt == 12_345);
        assert("2,147,483,647".toInt == 2_147_483_647);
        assert("4ignored5".toInt == 45);
        assert("2.78".toInt == 278);
    });

    test("Convert string to float", {
        assert("1.0".toFloat.approxEqual(1.0));
        assert("1.0.0".toFloat.approxEqual(1.0));
        assert("0.1".toFloat.approxEqual(0.1));
        assert("123.4".toFloat.approxEqual(123.4));
        assert("123.4.5bla6".toFloat.approxEqual(123.456));

        assert("1,0".toFloat(',').approxEqual(1.0));
        assert("1,0.0".toFloat(',').approxEqual(1.0));
        assert("0,1".toFloat(',').approxEqual(0.1));
        assert("123,4".toFloat(',').approxEqual(123.4));
        assert("123,4.5bla6".toFloat(',').approxEqual(123.456));
    });
}
