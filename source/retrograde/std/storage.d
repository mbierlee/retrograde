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

module retrograde.std.storage;

import retrograde.std.string : String, s;
import retrograde.std.collections : Array;

struct File {
    String fileName;
    Array!ubyte data;
}

version (UnitTesting)  :  ///

void runFileTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- File tests --");

    test("Create file from pre-defined data", () {
        Array!ubyte data = ['a', 'b', 'c'];
        File file = File("testFile".s, data);
        assert(file.data == data);
    });
}
