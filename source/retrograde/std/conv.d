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

int toInt(inout ref String str) {
    int result = 0;
    String sanitizedStr = str.stripNonNumeric();
    foreach (size_t i, char c; sanitizedStr) {
        double exp = sanitizedStr.length - i - 1;
        int digit = c.toInt;
        result += cast(int)(digit * pow(10.0, exp));
    }

    return result;
}

version (UnitTesting)  :  ///

void runConvTests() {
    import retrograde.std.test : test, writeSection;

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
}
