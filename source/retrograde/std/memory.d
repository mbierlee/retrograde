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

module retrograde.std.memory;

import retrograde.std.test : test, writeSection;

version (WebAssembly) {
    public import retrograde.wasm.memory : malloc, free, calloc, realloc, memset, memcmp, memcpy;
} else {
    public import core.stdc.stdlib : malloc, free, calloc, realloc;
    public import core.stdc.string : memset, memcmp, memcpy;

    /**
     * Normally free_sized checks whether the given size is the size of
     * the allocated memory block. This implementation does not do that.
     * It behaves like free.
     * It is here because there's a version of it for WASM that does check
     * boundaries.
     */
    export extern (C) void free_sized(void* ptr, size_t size) {
        free(ptr);
    }
}

/** 
 * Free an array pointer referenced by a slice.
 */
export extern (C) void free(T)(T[] slice) {
    free(slice.ptr);
}

/**
 * Allocates memory of the given type.
 * The memory is not initialized.
 */
T* allocateRaw(T)() {
    return cast(T*) malloc(T.sizeof);
}

/**
 * Allocates memory of the given type.
 * The memory is initialized to the given value.
 */
T* makeRaw(T)(const T initial = T.init) {
    return makeRaw(initial);
}

/**
 * Allocates memory of the given type.
 * The memory is initialized to the given value.
 */
T* makeRaw(T)(const ref T initial) {
    T* ptr = allocateRaw!T;
    *ptr = initial;
    return ptr;
}

/**
 * Allocates an array of the given type.
 * The memory is initialized to given value.
 */
T[] makeRawArray(T)(size_t length, T initialValue = T.init) {
    auto ptr = cast(T*) calloc(length, T.sizeof);
    for (size_t i = 0; i < length; i++) {
        ptr[i] = initialValue;
    }

    return ptr[0 .. length];
}

version (unittest) {
    unittest {
        runStdMemoryTests();
    }
}

void runStdMemoryTests() {
    writeSection("-- High-level memory tests --");

    struct TestStruct {
        int a = 42;
        int b = 66;
    }

    test("Create an uninitialized raw pointer", {
        TestStruct* testStruct = allocateRaw!TestStruct();
        assert(testStruct.a != 42);
        assert(testStruct.b != 66);
        free(testStruct);
    });

    test("Create an initialized, default raw pointer", {
        TestStruct* testStruct = makeRaw!TestStruct();
        assert(testStruct.a == 42);
        assert(testStruct.b == 66);
        free(testStruct);
    });

    test("Create an initialized, used-defined raw pointer by reference", {
        auto initial = TestStruct(44, 33);
        TestStruct* testStruct = makeRaw(initial);
        assert(testStruct.a == 44);
        assert(testStruct.b == 33);
        free(testStruct);
    });

    test("Create an initialized, used-defined raw pointer by value", {
        TestStruct* testStruct = makeRaw(TestStruct(66, 77));
        assert(testStruct.a == 66);
        assert(testStruct.b == 77);
        free(testStruct);
    });

    test("Create an array of raw pointers", {
        auto slice = makeRawArray!int(10);
        for (size_t i = 0; i < 10; i++) {
            assert(slice[i] == 0);
        }

        free(slice);
    });

    test("Create an array of raw pointers initialized by custom value", {
        auto slice = makeRawArray!int(10, 42);
        for (size_t i = 0; i < 10; i++) {
            assert(slice[i] == 42);
        }

        free(slice);
    });
}
