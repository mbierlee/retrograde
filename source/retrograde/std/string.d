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

import retrograde.std.memory : free, calloc, memcpy, realloc, unique, UniquePtr;
import retrograde.std.test : test, writeSection;

/** 
 * A dynamic string that manages its own memory.
 */
struct StringT(T) if (is(T == char) || is(T == wchar) || is(T == dchar)) {
    private T* ptr;
    private size_t _length;

    /** 
     * Create a String from a D string
     */
    this(string str) {
        copyFrom(cast(void*) str.ptr, str.length);
    }

    this(ref return scope typeof(this) other) {
        copyFrom(cast(void*) other.ptr, other._length);
    }

    ~this() {
        freePtr();
    }

    void opAssign(ref typeof(this) other) {
        freePtr();
        copyFrom(cast(void*) other.ptr, other._length);
    }

    void opAssign(typeof(this) other) {
        this.opAssign(other);
    }

    void opAssign(string str) {
        freePtr();
        copyFrom(cast(void*) str.ptr, str.length);
    }

    void opOpAssign(string op : "~")(ref typeof(this) rhs) {
        auto prevLength = _length;
        _length += rhs.length;
        ptr = cast(T*) realloc(cast(void*) ptr, _length * T.sizeof);
        memcpy(cast(void*)(ptr + prevLength), cast(void*) rhs.ptr, rhs.length * T.sizeof);
    }

    void opOpAssign(string op : "~")(typeof(this) rhs) {
        this.opOpAssign!op(rhs);
    }

    void opOpAssign(string op : "~")(string rhs) {
        auto prevLength = _length;
        _length += rhs.length;
        ptr = cast(T*) realloc(cast(void*) ptr, _length * T.sizeof);
        memcpy(cast(void*)(ptr + prevLength), cast(void*) rhs.ptr, rhs.length * T.sizeof);
    }

    bool opCast(T : bool)() const {
        return ptr !is null && _length > 0;
    }

    typeof(this) opBinary(string op : "~")(ref typeof(this) rhs) {
        auto str = String(this);
        str._length += rhs.length;
        str.ptr = cast(T*) realloc(cast(void*) str.ptr, str._length * T.sizeof);
        memcpy(cast(void*)(str.ptr + _length), cast(void*) rhs.ptr, rhs.length * T.sizeof);
        return str;
    }

    typeof(this) opBinary(string op : "~")(typeof(this) rhs) {
        return this.opBinary!op(rhs);
    }

    T opIndex(size_t index) {
        return ptr[index];
    }

    T[] opIndex() {
        return ptr[0 .. _length];
    }

    size_t opDollar() {
        return _length;
    }

    T[] opSlice(size_t dim : 0)(size_t i, size_t j) {
        return ptr[i .. j];
    }

    T[] opIndex()(T[] slice) {
        return slice;
    }

    T opIndexAssign(T value, size_t i) {
        ptr[i] = value;
        return value;
    }

    T opIndexAssign(T value) {
        for (size_t i = 0; i < _length; i++) {
            ptr[i] = value;
        }

        return value;
    }

    T opIndexAssign(T value, T[] slice) {
        for (size_t i = 0; i < slice.length; i++) {
            slice[i] = value;
        }

        return value;
    }

    static if (is(T == char)) {
        /** 
         * Get the D string representation of this String.
         */
        string get() const {
            return cast(string) ptr[0 .. _length];
        }
    } else {
        /** 
         * Get a character array of this String
         */
        const(T)[] get() const {
            return ptr[0 .. _length];
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

    private void copyFrom(void* ptr, size_t length) {
        this.ptr = cast(T*) calloc(length, T.sizeof);
        _length = length;
        memcpy(cast(void*) this.ptr, ptr, length);
    }

    private void freePtr() {
        if (ptr !is null) {
            free(cast(void*) ptr);
        }

        ptr = null;
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

///  --- Tests ---

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

    test("Construct a String from another String", {
        auto str = String("Hello world");
        auto str2 = String(str);
        assert(str2.get == "Hello world");
        assert(str2.length == 11);
        assert(str2.ptr !is str.ptr);
    });

    test("Assigning a String to another String copies it", {
        auto str = String("Hello world");
        auto str2 = String("Goodbye world");
        str2 = str;
        assert(str2.get == "Hello world");
        assert(str2.length == 11);
        assert(str2.ptr !is str.ptr);
    });

    test("Assigning a D string to a String copies it", {
        auto str = String("Hello world");
        str = "Goodbye world";
        assert(str.get == "Goodbye world");
        assert(str.length == 13);
    });

    test("String can be used in a truthy test to check for emptyness", {
        auto str = String("Hello world");
        assert(str);
        str = String("");
        assert(!str);
    });

    test("Two strings can be concatenated", {
        auto str = String("Hello");
        auto str2 = String(" world");
        auto str3 = str ~ str2 ~ String("!");
        assert(str3.get == "Hello world!");
        assert(str3.length == 12);
    });

    test("Concatenate String to another String", {
        auto str = String("Hello");
        auto str2 = String(" world");
        str ~= str2;
        assert(str.get == "Hello world");
        assert(str.length == 11);
    });

    test("Concatenate D string to String", {
        auto str = String("Hello");
        str ~= " world";
        assert(str.get == "Hello world");
        assert(str.length == 11);
    });

    test("Using dollar on String", {
        auto str = String("Hello world");
        assert(str[$ - 1] == 'd');
    });

    test("Getting slice from String", {
        auto str = String("Hello world");
        assert(str[0 .. 5] == "Hello");
    });

    test("Change character of String via index", {
        auto str = String("Hello world");
        str[0] = 'h';
        assert(str.get == "hello world");
    });

    test("Change all characters of String via index", {
        auto str = String("Hello world");
        str[] = 'h';
        assert(str.get == "hhhhhhhhhhh");
    });

    test("Change all characters of String via slice", {
        auto str = String("Hello world");
        str[6 .. $] = 'h';
        assert(str.get == "Hello hhhhh");
    });

    test("Create String from a slice", {
        auto dStr = "Hello world";
        auto str = String(dStr[6 .. $]);
        assert(str.get == "world");
    });

}