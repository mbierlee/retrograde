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

module retrograde.std.stringid;

debug (ReadableStringId) {
    alias StringId = string;
} else {
    alias StringId = uint;
}

/**
 * Create a StringId from the given string.
 * With debug switch "ReadableStringId" stringids are just regular strings,
 * but in release mode they are actually integer hashes.
 */
pure StringId sid(string idString) {
    debug (ReadableStringId) {
        return idString;
    } else {
        StringId stringId = 7;
        foreach (char strChar; idString) {
            stringId = (stringId * 31) + cast(StringId) strChar;
        }

        return stringId;
    }
}

///  --- Tests ---

void runStringIdTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- StringId tests --");

    test("sid() should return the same value for the same string", {
        assert(sid("test") == sid("test"));
    });

    test("sid() should return a different value for a different string", {
        assert(sid("test") != sid("test2"));
    });
}
