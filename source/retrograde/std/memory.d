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
        }

        ptr = null;
    }

    @disable this(ref typeof(this));
    @disable void opAssign(ref typeof(this));

    auto opDispatch(string s)() {
        assert(ptr !is null, "Unique pointer is null and may not be used.");
        return mixin("ptr." ~ s);
    }

    auto opDispatch(string s, Args...)(Args args) {
        assert(ptr !is null, "Unique pointer is null and may not be used.");
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
 * Create a unique pointer initialized to the given value.
 */
UniquePtr!T makeUnique(T)(const T initial = T.init) {
    return makeUnique(initial);
}

/// ditto
UniquePtr!T makeUnique(T)(const ref T initial) {
    return UniquePtr!T(makeRaw(initial));
}

/**
 * Create a shared pointer from a raw pointer.
 * A shared pointer can be copied and shared between multiple owners.
 * The memory is freed when the last owner destroys the shared pointer.
 */
struct SharedPtr(T) {
    private T* ptr;
    private size_t* refCount;

    this(T* ptr) {
        assert(ptr !is null);
        this.ptr = ptr;
        refCount = makeRaw!size_t;
        *refCount = 1;
    }

    ~this() {
        assert(ptr is null || refCount !is null, "Reference count is null but pointer is not null.");
        releaseShare();
        ptr = null;
        refCount = null;
    }

    this(ref return scope typeof(this) other) {
        assert(other.ptr !is null, "Other shared pointer is null and may not be used.");
        assert(other.refCount !is null, "Other shared pointer reference count is null but pointer is not null.");
        ptr = other.ptr;
        refCount = other.refCount;
        (*refCount)++;
    }

    void opAssign(ref return scope typeof(this) other) {
        assert(other.ptr !is null, "Other shared pointer is null and may not be used.");
        assert(other.refCount !is null, "Other shared pointer reference count is null but pointer is not null.");
        releaseShare();
        ptr = other.ptr;
        refCount = other.refCount;
        (*refCount)++;
    }

    auto opDispatch(string s)() {
        assert(ptr !is null, "Shared pointer is null and may not be used.");
        return mixin("ptr." ~ s);
    }

    auto opDispatch(string s, Args...)(Args args) {
        assert(ptr !is null, "Shared pointer is null and may not be used.");
        return mixin("ptr." ~ s ~ "(args)");
    }

    private void releaseShare() {
        if (ptr !is null && refCount !is null) {
            (*refCount)--;
            if (*refCount <= 0) {
                destroy(*ptr);
                free(ptr);
                free(refCount);
            }
        }
    }
}

/**
 * Create a shared pointer from a raw pointer.
 */
SharedPtr!T share(T)(T* ptr) {
    return SharedPtr!T(ptr);
}

/**
 * Create a shared pointer initialized to the given value.
 */
SharedPtr!T makeShared(T)(const T initial = T.init) {
    return makeShared(initial);
}

/// ditto
SharedPtr!T makeShared(T)(const ref T initial) {
    return SharedPtr!T(makeRaw(initial));
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
        testStructDestroyed = false;

        {
            auto uniquePtr = makeRaw!TestStruct().unique;
            testStructDestroyed = false;
            assert(uniquePtr.ptr !is null);
        }

        assert(testStructDestroyed);
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
            TestContainer(makeUnique!TestStruct);
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

    test("Create and use a shared pointer", {
        auto sharedPtr = SharedPtr!TestStruct(makeRaw!TestStruct);
        assert(sharedPtr.ptr.a == 42);
        assert(sharedPtr.ptr.b == 66);
        assert(*(sharedPtr.refCount) == 1);

        sharedPtr.doubleValues();
        assert(sharedPtr.a == 84);
        assert(sharedPtr.b == 132);
    });

    test("Contained object is destroyed and freed when shared pointer goes out of scope and ref is 0", {
        testStructDestroyed = false; // This is just to make dfmt not add a huge amount of spaces

        {
            auto sharedPtr = makeShared!TestStruct;
            testStructDestroyed = false;
            assert(sharedPtr.ptr !is null);
            assert(*(sharedPtr.refCount) == 1);
            assert(!testStructDestroyed);
        }

        assert(testStructDestroyed);
    });

    test("In a shared pointer the refcount is properly managed and containing object cleaned up", {
        testStructDestroyed = false; // This is just to make dfmt not add a huge amount of spaces

        {
            auto rawPtr = makeRaw!TestStruct();
            testStructDestroyed = false;
            SharedPtr!TestStruct sharedPtr = rawPtr.share;
            assert(*(sharedPtr.refCount) == 1);
            assert(sharedPtr.ptr is rawPtr);
            assert(!testStructDestroyed);

            {
                SharedPtr!TestStruct sharedPtr2 = sharedPtr;
                assert(*(sharedPtr.refCount) == 2);
                assert(*(sharedPtr2.refCount) == 2);
                assert(sharedPtr.ptr is rawPtr);
                assert(sharedPtr2.ptr is rawPtr);
                assert(!testStructDestroyed);
            }

            assert(!testStructDestroyed);
            assert(*(sharedPtr.refCount) == 1);
        }

        assert(testStructDestroyed);
    });

    test("A shared pointer that is being assigned another shared pointer takes care of its refcount first", {
        auto sharedPtr1 = makeShared!TestStruct;
        auto sharedPtr2 = makeShared!TestStruct;
        testStructDestroyed = true;
        sharedPtr1 = sharedPtr2;
        assert(testStructDestroyed);
        assert(sharedPtr2.ptr !is null);
        assert(sharedPtr1.ptr is sharedPtr2.ptr);
        assert(sharedPtr2.refCount !is null);
        assert(sharedPtr1.refCount is sharedPtr2.refCount);
        assert(*(sharedPtr2.refCount) == 2);
    });
}
