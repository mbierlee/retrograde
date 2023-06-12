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

/// ditto
T* makeRaw(T)(const ref T initial) {
    T* ptr = allocateRaw!T;
    memcpy(ptr, &initial, T.sizeof);
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

/** 
 * A pointer to allocated memory that is freed when the pointer goes out of scope.
 *
 * The pointer has unique, exclusive ownership of the memory. The original raw pointer
 * should not be used after the unique pointer is created and definitely not be freed
 * manually.
 */
struct UniquePtr(T) {
    private T* ptr;

    this(T* ptr) {
        assert(ptr !is null);
        this.ptr = ptr;
    }

    ~this() {
        if (ptr !is null) {
            destroy(*ptr);
            free(ptr);
            ptr = null;
        }
    }

    @disable this(ref typeof(this));

    auto opDispatch(string s)() {
        return mixin("ptr." ~ s);
    }

    auto opDispatch(string s, Args...)(Args args) {
        return mixin("ptr." ~ s ~ "(args)");
    }

    /**
     * Move the raw pointer to another unique pointer.
     * The original pointer is not freed.
     * This instance will become useless and should not be used anymore.
     */
    UniquePtr!T move() {
        auto movedPtr = UniquePtr!T(ptr);
        ptr = null;
        return movedPtr;
    }
}

/**
 * Create a unique pointer from a raw pointer.
 */
UniquePtr!T unique(T)(T* ptr) {
    return UniquePtr!T(ptr);
}

/**
 * Create a unique pointer from a raw pointer.
 * The pointer is initialized to the given value.
 */
UniquePtr!T makeUnique(T)(const T initial = T.init) {
    return makeUnique(initial);
}

/// ditto
UniquePtr!T makeUnique(T)(const ref T initial) {
    return UniquePtr!T(makeRaw(initial));
}

version (unittest) {
    unittest {
        runStdMemoryTests();
    }
}

private bool testStructDestroyed = false;

private struct TestStruct {
    int a = 42;
    int b = 66;

    ~this() {
        testStructDestroyed = true;
    }

    void doubleValues() {
        a *= 2;
        b *= 2;
    }
}

private struct TestContainer {
    UniquePtr!TestStruct ptr;
}

void runStdMemoryTests() {
    writeSection("-- High-level memory tests --");

    test("Create an uninitialized raw pointer", {
        TestStruct* testStruct = allocateRaw!TestStruct;
        assert(testStruct.a != 42);
        assert(testStruct.b != 66);
        free(testStruct);
    });

    test("Create an initialized, default raw pointer", {
        TestStruct* testStruct = makeRaw!TestStruct;
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

    test("Create and use a unique pointer", {
        auto uniquePtr = UniquePtr!TestStruct(makeRaw!TestStruct);
        assert(uniquePtr.ptr.a == 42);
        assert(uniquePtr.ptr.b == 66);

        uniquePtr.doubleValues();
        assert(uniquePtr.a == 84);
        assert(uniquePtr.b == 132);
    });

    test("Create an initialized unique pointer", {
        auto uniquePtr = makeUnique!TestStruct;
        assert(uniquePtr.a == 42);
        assert(uniquePtr.b == 66);
    });
    test("A destroyed unique pointer will nullify the container pointer", {
        auto uniquePtr = makeRaw!TestStruct().unique;
        assert(uniquePtr.ptr !is null);
        uniquePtr.destroy();
        assert(uniquePtr.ptr is null);
    });

    test("A destroyed unique pointer will destroy the contained pointer", {
        auto rawPtr = makeRaw!TestStruct();
        testStructDestroyed = false;
        {
            auto uniquePtr = rawPtr.unique;
            assert(uniquePtr.ptr !is null);
            assert(!testStructDestroyed);
        }

        assert(testStructDestroyed);
    });

    test("A unique pointer is destroyed when containing objects are", {
        testStructDestroyed = false;
        {
            auto container = TestContainer(makeUnique!TestStruct);
        }

        assert(testStructDestroyed);
    });

    test("A unique pointer cannot be copied", {
        auto uniquePtr = makeUnique!TestStruct;
        assert(!__traits(compiles, mixin("auto uniquePtr2 = uniquePtr")));
    });

    test("A unique pointer's ownership can be moved", {
        auto rawPtr = makeRaw!TestStruct;
        auto uniquePtr = rawPtr.unique;
        auto uniquePtr2 = uniquePtr.move;
        assert(uniquePtr.ptr is null);
        assert(uniquePtr2.ptr is rawPtr);
    });
}
