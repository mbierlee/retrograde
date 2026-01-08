/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.std.endian;

enum Endian {
    little,
    big,
    unknown
}

Endian determinePlatformEndianness() {
    union TestEndian {
        uint value;
        ubyte[4] bytes;
    }

    TestEndian test;
    test.value = 0x01020304;

    if (test.bytes[0] == 0x01 && test.bytes[1] == 0x02 && test.bytes[2] == 0x03 && test.bytes[3] == 0x04) {
        return Endian.big;
    } else if (test.bytes[0] == 0x04 && test.bytes[1] == 0x03 && test.bytes[2] == 0x02 && test.bytes[3] == 0x01) {
        return Endian.little;
    } else {
        assert(0, "Unable to determine endianness");
        return Endian.unknown;
    }
}

Endian getPlatformEndianness() {
    version (Windows) {
        return Endian.little;
    } else version (WebAssembly) {
        return Endian.little;
    } else {
        return determinePlatformEndianness();
    }
}

T toEndianness(T)(const ref ubyte[T.sizeof] bytes, Endian sourceEndianness, Endian targetEndianness) {
    if (sourceEndianness == targetEndianness) {
        return *cast(T*) bytes.ptr;
    } else {
        ubyte[T.sizeof] reversedBytes;
        foreach (i, _byte; bytes) {
            reversedBytes[T.sizeof - 1 - i] = _byte;
        }

        return *cast(T*) reversedBytes.ptr;
    }
}

T toPlatformEndian(T)(const ref ubyte[T.sizeof] bytes, Endian sourceEndianness) {
    return toEndianness!T(bytes, sourceEndianness, getPlatformEndianness());
}

version (UnitTesting)  :  ///

void runEndianTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Endian tests --");

    version (Windows) {
        test("Determine endianness on Windows", () {
            auto endian = determinePlatformEndianness();
            assert(endian == Endian.little, "Windows is expected to be little endian");
        });

        test("Get endianness on Windows", () {
            auto endian = getPlatformEndianness();
            assert(endian == Endian.little, "Windows is expected to be little endian");
        });
    }

    version (WebAssembly) {
        test("Determine endianness on WASM", () {
            auto endian = determinePlatformEndianness();
            assert(endian == Endian.little, "WASM is expected to be little endian");
        });

        test("Get endianness on WASM", () {
            auto endian = getPlatformEndianness();
            assert(endian == Endian.little, "WASM is expected to be little endian");
        });
    }

    test("Determine endianness on any platform", () {
        auto endian = determinePlatformEndianness();
        assert(endian == Endian.little || endian == Endian.big, "Platforms need to be either little or big endian");
    });

    test("Get endianness on any platform", () {
        auto endian = getPlatformEndianness();
        assert(endian == Endian.little || endian == Endian.big, "Platforms need to be either little or big endian");
    });

    test("toEndianess - Little to Big", () {
        ubyte[4] littleEndianBytes = [0x04, 0x03, 0x02, 0x01];
        uint result = toEndianness!uint(littleEndianBytes, Endian.little, Endian.big);
        assert(result == 0x04030201);
    });

    test("toEndianess - Big to Little", () {
        ubyte[4] bigEndianBytes = [0x04, 0x03, 0x02, 0x01];
        uint result = toEndianness!uint(bigEndianBytes, Endian.big, Endian.little);
        assert(result == 0x04030201);
    });

    test("toEndianess - Little to Little", () {
        ubyte[4] littleEndianBytes = [0x04, 0x03, 0x02, 0x01];
        uint result = toEndianness!uint(littleEndianBytes, Endian.little, Endian.little);
        assert(result == 0x01020304);
    });

    test("toEndianess - Big to Big", () {
        ubyte[4] bigEndianBytes = [0x04, 0x03, 0x02, 0x01];
        uint result = toEndianness!uint(bigEndianBytes, Endian.big, Endian.big);
        assert(result == 0x01020304);
    });

    test("toPlatformEndian - Little to Platform", () {
        ubyte[4] littleEndianBytes = [0x04, 0x03, 0x02, 0x01];
        uint result = toPlatformEndian!uint(littleEndianBytes, Endian.little);
        assert(result == 0x01020304);
    });

    test("toPlatformEndian - Big to Platform", () {
        ubyte[4] bigEndianBytes = [0x04, 0x03, 0x02, 0x01];
        uint result = toPlatformEndian!uint(bigEndianBytes, Endian.big);
        assert(result == 0x04030201);
    });
}
