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

module retrograde.std.string;

import retrograde.std.memory : free, calloc, memcpy, unique, UniquePtr;
import retrograde.std.test : test, writeSection;

/** 
 * A UTF-8 encoded, dynamic string.
 */
struct StringT(T) if (is(T == char) || is(T == wchar) || is(T == dchar)) {
    private T* ptr;
    private size_t _length;

    /** 
     * Create a String from a D string
     */
    this(string str) {
        ptr = cast(T*) calloc(str.length, T.sizeof);
        _length = str.length;
        memcpy(cast(void*) ptr, cast(void*) str.ptr, str.length);
    }

    ~this() {
        if (ptr !is null) {
            free(cast(void*) ptr);
        }
    }

    static if (is(T == char)) {
        /** 
         * Get the D string representation of this String.
         */
        string get() const {
            return cast(string) ptr[0 .. length];
        }
    } else {
        /** 
         * Get a character array of this String
         */
        const(T)[] get() const {
            return ptr[0 .. length];
        }
    }

    size_t length() const {
        return _length;
    }

    /** 
     * Get a C string representation of this String.
     */
    UniquePtr!T cString() const {
        T* cStrPtr = cast(T*) calloc(_length + 1, T.sizeof);
        cStrPtr[0 .. _length] = ptr[0 .. _length];
        cStrPtr[_length] = '\0';
        return cStrPtr.unique;
    }
}

alias String = StringT!char;
alias WString = StringT!wchar;
alias DString = StringT!dchar;

/** 
 * Compare two C strings.
 * Strings are compared until a null character is found.
 * If none is found this method may cause a segfault or overlap into other memory.
 * Use String for safer string handling.
 */
export extern (C) int strcmp(const void* ptr1, const void* ptr2) {
    auto str1 = cast(const(char)*) ptr1;
    auto str2 = cast(const(char)*) ptr2;

    while (*str1 != '\0' && *str2 != '\0') {
        if (*str1 != *str2) {
            return *str1 - *str2;
        }

        str1++;
        str2++;
    }

    return *str1 - *str2;
}

version (unittest) {
    unittest {
        runStringTests();
    }
}

void runStringTests() {
    import retrograde.std.memory : memcmp;

    writeSection("-- String tests --");

    test("strcmp compares two C strings", {
        auto str1 = "Hello world\0";
        auto str2 = "Hello world\0";
        assert(strcmp(cast(void*) str1.ptr, cast(void*) str2.ptr) == 0);
    });

    test("Create and use String from static string", {
        auto str = String("Hello world");
        assert(str.get == "Hello world");
        assert(str.length == 11);
    });

    test("Get a C string from a String", {
        auto str = String("Hello world");
        auto cStr = str.cString();
        assert(strcmp(cast(void*) cStr.ptr, cast(void*) "Hello world\0".ptr) == 0);
    });

}
