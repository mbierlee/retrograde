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

module retrograde.std.memory;

import retrograde.std.string : String;

version (WebAssembly) {
    public import retrograde.wasm.memory : malloc, free, calloc, realloc, memset, memcmp, memcpy, memmove;
} else {
    public import core.stdc.stdlib : malloc, free, calloc, realloc;
    public import core.stdc.string : memset, memcmp, memcpy, memmove;

    /**
     * Normally free_sized checks whether the given size is the size of
     * the allocated memory block. This implementation does not do that.
     * It behaves like free.
     * It is here because there's a version of it for WASM that does check
     * boundaries.
     *
     * Params: 
     *  ptr: The pointer to the memory block to free.
     *  size: The size of the memory block. It is ignored but here for compatibility.
     */
    export extern (C) void free_sized(void* ptr, size_t size) {
        free(ptr);
    }
}

/** 
 * Free an array pointer referenced by a slice.
 *
 * Params:
 *  slice: The slice to free.
 */
export extern (C) void free(T)(T[] slice) {
    free(slice.ptr);
}

/**
 * Allocates memory of the given type.
 * The memory is not initialized.
 *
 * Params: 
 *  T: The type of the memory to allocate.
 * Returns: A raw pointer to the allocated memory.
 */
T* allocateRaw(T)() {
    return cast(T*) malloc(T.sizeof);
}

/**
 * Allocates memory of the given type.
 * The memory is initialized to the given value.
 *
 * Params:
 *  T: The type of the memory to allocate.
 *  initial: The initial value to set the memory to.
 *           When not given, the initial value is the default value of the type.
 * Returns: A raw pointer to the allocated memory.
 */
T* makeRaw(T)(inout T initial = T.init) {
    return makeRaw(initial);
}

/// ditto
T* makeRaw(T)(inout ref T initial) {
    T* ptr = allocateRaw!T;
    assert(ptr !is null, "Could not allocate memory in makeRaw.");
    memset(ptr, 0, T.sizeof);
    *ptr = initial;
    return ptr;
}

/**
 * Allocates an array of the given type.
 * The memory is initialized to given value.
 *
 * Params:
 *  T: The type of the memory to allocate.
 *  length: The length of the array to allocate.
 *  initialValue: The initial value to set the memory to.
 *                When not given, the initial value is the default value of the type.
 * Returns: A slice to the allocated memory.
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
    private T* _ptr;

    this(T* ptr) {
        assert(ptr !is null);
        _ptr = ptr;
    }

    ~this() {
        cleanup();
    }

    @disable this(ref typeof(this));
    @disable void opAssign(ref typeof(this));

    void opAssign(typeof(null)) {
        auto ptr = release();
        free(ptr);
    }

    auto opDispatch(string s)() {
        assert(_ptr !is null, "Unique pointer is null and may not be used.");
        return mixin("_ptr." ~ s);
    }

    auto opDispatch(string s, Args...)(Args args) {
        assert(_ptr !is null, "Unique pointer is null and may not be used.");
        return mixin("_ptr." ~ s ~ "(args)");
    }

    auto opDispatch(string s, T)(T value) {
        assert(_ptr !is null, "Unique pointer is null and may not be used.");
        return mixin("_ptr." ~ s ~ " = value");
    }

    static if (!is(T == void)) {
        auto opIndex(size_t i) {
            assert(_ptr !is null, "Unique pointer is null and may not be used.");
            //TODO: Bounds checking
            return _ptr[i];
        }
    }

    /**
     * Get the raw pointer.
     * The pointer is still managed by the unique pointer and should not be freed manually.
     * Do not use it to create another smart pointer, but use one of the other methods instead
     * such as move or share.
     */
    T* ptr() {
        return _ptr;
    }

    /**
     * Returns: Whether the pointer is defined.
     */
    bool isDefined() {
        return _ptr !is null;
    }

    /**
     * Release the raw pointer.
     * The pointer is no longer managed by the unique pointer and must be freed manually.
     * This instance will become useless and should not be used anymore.
     *
     * Returns: The raw pointer.
     */
    T* release() {
        auto ptr = _ptr;
        _ptr = null;
        return ptr;
    }

    /**
     * Move the raw pointer to another unique pointer.
     * The original pointer is not freed.
     * This instance will become useless and should not be used anymore.
     *
     * Returns: The new unique pointer.
     */
    UniquePtr!T move() {
        return UniquePtr!T(release());
    }

    /**
     * Move the raw pointer to a shared pointer.
     * The original pointer is not freed.
     * This instance will become useless and should not be used anymore.
     *
     * Returns: The new shared pointer.
     */
    SharedPtr!T share() {
        return SharedPtr!T(release());
    }

    /**
     * Swap the raw pointer with another unique pointer.
     * If either pointer is null then the other pointer will become null.
     *
     * Params:
     *  other: The other unique pointer to swap with.
     */
    void swap(ref typeof(this) other) {
        auto tmp = _ptr;
        _ptr = other._ptr;
        other._ptr = tmp;
    }

    /**
     * Reset the raw pointer.
     * The previously owned pointer is freed. 
     * If no pointer is given the pointer is set to null, which
     * makes this instance useless.
     *
     * Params:
     *  ptr: The new raw pointer. When not given, the pointer is set to null.
     */
    void reset(T* ptr = null) {
        cleanup();
        _ptr = ptr;
    }

    private void cleanup() {
        if (_ptr !is null) {
            static if (!is(T == void)) {
                destroy(*_ptr);
            }

            free(_ptr);
        }

        _ptr = null;
    }
}

/** 
 * Move a unique pointer from one instance to another. 
 *
 * The source is released and becomes unusable.
 */
void move(T)(ref UniquePtr!T source, ref UniquePtr!T target) {
    target.reset(source.release());
}

/**
 * Create a unique pointer from a raw pointer.
 *
 * Params:
 *  T: The type of the pointer.
 *  ptr: The raw pointer.
 * Returns: A unique pointer.
 */
UniquePtr!T unique(T)(T* ptr) {
    return UniquePtr!T(ptr);
}

/**
 * Create a unique pointer initialized to the given value.
 *
 * Params:
 *  T: The type of the pointer.
 *  initial: The initial value. When not given, the initial value is the default value of the type.
 * Returns: A unique pointer.
 */
UniquePtr!T makeUnique(T)(const T initial = T.init) {
    return makeUnique(initial);
}

/// ditto
UniquePtr!T makeUnique(T)(const ref T initial) {
    return UniquePtr!T(makeRaw(initial));
}

/**
 * Create a unique void pointer initialized to the given value.
 *
 * Params:
 *  T: The type of the value to initialize the pointer with. Not the type of the pointer itself.
 *  initial: The initial value. When not given, the initial value is the default value of the type.
 * Returns: A unique void pointer.
 */
UniquePtr!void makeUniqueVoid(T)(const T initial = T.init) {
    void* rawPtr = cast(void*) makeRaw(initial);
    UniquePtr!void uniquePtr = UniquePtr!void(rawPtr);
    return uniquePtr;
}

/**
 * A shared pointer to allocated memory.
 *
 * A shared pointer can be copied and shared between multiple owners.
 * The memory is freed when the last owner destroys the shared pointer.
 */
struct SharedPtr(T) {
    private T* _ptr = null;
    private size_t* refCount = null;

    this(T* ptr) {
        assert(ptr !is null);
        this._ptr = ptr;
        refCount = makeRaw!size_t;
        *refCount = 1;
    }

    ~this() {
        assert(_ptr is null || refCount !is null, "Reference count is null but pointer is not null.");
        releaseShare();
    }

    this(ref return scope inout typeof(this) other) {
        _ptr = cast(T*) other._ptr;
        refCount = cast(size_t*) other.refCount;
        incrementRefCount();
    }

    /**
     * Get the raw pointer.
     * The pointer is still managed by the shared pointer and should not be freed manually.
     * Do not use it to create another smart pointer or else it might be double-freed.
     */
    T* ptr() {
        return _ptr;
    }

    /** 
     * Returns: whether the pointer is defined.
     */
    bool isDefined() const {
        return _ptr !is null;
    }

    /**
     * Returns: The number of owners of the pointer.
     */
    size_t useCount() const {
        return refCount is null ? 0 : *refCount;
    }

    /** 
     * Returns: a casted copy of the shared pointer.
     */
    SharedPtr!CastT as(CastT)() {
        SharedPtr!CastT castedPtr;
        castedPtr._ptr = cast(CastT*) _ptr;
        castedPtr.refCount = refCount;
        castedPtr.incrementRefCount();
        return castedPtr;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        if (this is other) {
            return;
        }

        releaseShare();
        _ptr = cast(T*) other._ptr;
        refCount = cast(size_t*) other.refCount;
        incrementRefCount();
    }

    void opAssign(typeof(null)) {
        releaseShare();
        _ptr = null;
        refCount = null;
    }

    auto opDispatch(string s)() {
        assert(_ptr !is null, "Shared pointer is null and may not be used.");
        return mixin("_ptr." ~ s);
    }

    auto opDispatch(string s, Args...)(Args args) {
        assert(_ptr !is null, "Shared pointer is null and may not be used.");
        return mixin("_ptr." ~ s)(args);
    }

    auto opDispatch(string s, T)(T value) {
        assert(_ptr !is null, "Shared pointer is null and may not be used.");
        return mixin("_ptr." ~ s ~ " = value");
    }

    static if (!is(T == void)) {
        auto opIndex(size_t i) {
            assert(_ptr !is null, "Shared pointer is null and may not be used.");
            //TODO: Bounds checking
            return _ptr[i];
        }
    }

    private void releaseShare() {
        if (_ptr !is null && refCount !is null) {
            assert(*refCount > 0, "Reference count is 0 but pointer is not null.");
            if (*refCount > 0) {
                (*refCount)--;
            }

            if (*refCount <= 0) {
                static if (!is(T == void)) {
                    destroy(*_ptr);
                }

                free(_ptr);
                free(refCount);
                _ptr = null;
                refCount = null;
            }
        }
    }

    private void incrementRefCount() {
        if (refCount !is null) {
            (*refCount)++;
        }
    }
}

/**
 * Create a shared pointer from a raw pointer.
 *
 * Params:
 *  T: The type of the pointer.
 *  ptr: The raw pointer.
 * Returns: A shared pointer.
 */
SharedPtr!T share(T)(T* ptr) {
    return SharedPtr!T(ptr);
}

/**
 * Create a shared pointer initialized to the given value.
 *
 * Params:
 *  T: The type of the pointer.
 *  initial: The initial value. When not given, the initial value is the default value of the type.
 * Returns: A shared pointer.
 */
SharedPtr!T makeShared(T)(inout T initial = T.init) {
    return makeShared(initial);
}

/// ditto
SharedPtr!T makeShared(T)(inout ref T initial) {
    return SharedPtr!T(makeRaw(initial));
}

/**
 * Create a shared void pointer initialized to the given value.
 *
 * Params:
 *  T: The type of the value to initialize the pointer with. Not the type of the pointer itself.
 *  initial: The initial value. When not given, the initial value is the default value of the type.
 * Returns: A shared void pointer.
 */
SharedPtr!void makeSharedVoid(T)(const T initial = T.init) {
    void* rawPtr = cast(void*) makeRaw(initial);
    SharedPtr!void sharedPtr = SharedPtr!void(rawPtr);
    return sharedPtr;
}

/** 
 * A smart pointer used as a return type from functions that can succeed or fail.
 *
 * Result pointers are a combination of UniquePtr and Result types. They contain both a managed pointer
 * and a faillure state for when there is no valid result. 
 * It is recommended to transfer the pointer into a UniquePtr or SharedPtr using unique() or share() 
 * as soon as possible.
 */
struct ResultPtr(T) {
    private bool success;
    private T* _ptr;
    String _errorMessage;

    ~this() {
        cleanup();
    }

    @disable this(ref typeof(this));
    @disable void opAssign(ref typeof(this));

    void opAssign(typeof(null)) {
        auto ptr = release();
        free(ptr);
    }

    auto opDispatch(string s)() {
        assert(_ptr !is null, "Result pointer is null and may not be used.");
        return mixin("_ptr." ~ s);
    }

    auto opDispatch(string s, Args...)(Args args) {
        assert(_ptr !is null, "Result pointer is null and may not be used.");
        return mixin("_ptr." ~ s ~ "(args)");
    }

    auto opDispatch(string s, T)(T value) {
        assert(_ptr !is null, "Result pointer is null and may not be used.");
        return mixin("_ptr." ~ s ~ " = value");
    }

    static if (!is(T == void)) {
        auto opIndex(size_t i) {
            assert(_ptr !is null, "Result pointer is null and may not be used.");
            //TODO: Bounds checking
            return _ptr[i];
        }
    }

    /**
     * Get the raw pointer.
     * The pointer is still managed by the unique pointer and should not be freed manually.
     * Do not use it to create another smart pointer, but use one of the other methods instead
     * such as move or share.
     */
    T* ptr() {
        return _ptr;
    }

    /**
     * Returns: Whether the pointer is defined.
     */
    bool isDefined() {
        return _ptr !is null;
    }

    /**
     * Release the raw pointer.
     * The pointer is no longer managed by the unique pointer and must be freed manually.
     * This instance will become useless and should not be used anymore.
     * The success of this pointer will be falsified and the faillure message will be made
     * to state that the pointer is released.
     *
     * Returns: The raw pointer.
     */
    T* release() {
        success = false;
        _errorMessage = "Result pointer is released.";
        auto ptr = _ptr;
        _ptr = null;
        return ptr;
    }

    /**
     * Move the raw pointer to another result pointer.
     * The original pointer is not freed.
     * This instance will become useless and should not be used anymore.
     *
     * Returns: The new result pointer.
     */
    ResultPtr!T move() {
        ResultPtr!T newPtr;
        newPtr.success = success;
        newPtr._errorMessage = _errorMessage;
        newPtr._ptr = release();
        return newPtr;
    }

    /**
     * Move the raw pointer to a shared pointer.
     * The original pointer is not freed.
     * This instance will become useless and should not be used anymore.
     *
     * Returns: The new shared pointer.
     */
    SharedPtr!T share() {
        return SharedPtr!T(release());
    }

    /**
     * Move the raw pointer to a unique pointer.
     * The original pointer is not freed.
     * This instance will become useless and should not be used anymore.
     *
     * Returns: The new unique pointer.
     */
    UniquePtr!T unique() {
        return UniquePtr!T(release());
    }

    /**
     * Swap the raw pointer with another result pointer.
     * If either pointer is null then the other pointer will become null.
     *
     * Params:
     *  other: The other result pointer to swap with.
     */
    void swap(ref typeof(this) other) {
        auto tmpPtr = _ptr;
        auto tmpSuccess = success;
        auto tmpMessage = _errorMessage;

        _ptr = other._ptr;
        success = other.success;
        _errorMessage = other._errorMessage;

        other._ptr = tmpPtr;
        other.success = tmpSuccess;
        other._errorMessage = tmpMessage;
    }

    /**
     * Reset the raw pointer.
     * The previously owned pointer is freed. 
     * If no pointer is given the pointer is set to null, which
     * makes this instance useless.
     * The success state and error message remain unchanged.
     *
     * Params:
     *  ptr: The new raw pointer. When not given, the pointer is set to null.
     */
    void reset(T* ptr = null) {
        cleanup();
        _ptr = ptr;
    }

    /** 
     * Returns: Wheter the result is successful or not.
     */
    bool isSuccessful() {
        return this.success;
    }

    /** 
     * Returns: Wheter the result is failed or not.
     */
    bool isFailure() {
        return !this.success;
    }

    /**
     * Returns: The error message of the result.
     */
    String errorMessage() const {
        return this._errorMessage;
    }

    private void cleanup() {
        if (_ptr !is null) {
            static if (!is(T == void)) {
                destroy(*_ptr);
            }

            free(_ptr);
        }

        _ptr = null;
    }
}

ResultPtr!T successPtr(T)(T* ptr) {
    ResultPtr!T resultPtr;
    resultPtr._ptr = ptr;
    resultPtr.success = true;
    return resultPtr;
}

ResultPtr!T failedPtr(T)(string errorMessage) {
    ResultPtr!T resultPtr;
    resultPtr._ptr = null;
    resultPtr.success = false;
    resultPtr._errorMessage = errorMessage;
    return resultPtr;
}

ResultPtr!T failedPtr(T)(String errorMessage) {
    ResultPtr!T resultPtr;
    resultPtr._ptr = null;
    resultPtr.success = false;
    resultPtr._errorMessage = errorMessage;
    return resultPtr;
}

/** 
 * Move a result pointer from one instance to another. 
 *
 * The source is released and becomes unusable.
 */
void move(T)(ref ResultPtr!T source, ref ResultPtr!T target) {
    target.success = source.success;
    target._errorMessage = source._errorMessage;
    target.reset(source.release());
}

version (UnitTesting)  :  ///

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
    UniquePtr!TestStruct testStructPtr;

    this(ref return scope inout typeof(this) other) {
        testStructPtr.reset((cast(typeof(this)) other).testStructPtr.release());
    }

    void opAssign(ref return scope inout typeof(this) other) {
        testStructPtr.reset((cast(typeof(this)) other).testStructPtr.release());
    }
}

private struct TestResultContainer {
    ResultPtr!TestStruct testStructPtr;

    this(ref return scope inout typeof(this) other) {
        testStructPtr.reset((cast(typeof(this)) other).testStructPtr.release());
    }

    void opAssign(ref return scope inout typeof(this) other) {
        testStructPtr.reset((cast(typeof(this)) other).testStructPtr.release());
    }
}

private struct TestSharedContainer {
    SharedPtr!TestStruct testStructPtr;

    this(ref return scope inout typeof(this) other) {
        auto ptr = cast(SharedPtr!TestStruct) other.testStructPtr;
        testStructPtr = ptr;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        auto ptr = cast(SharedPtr!TestStruct) other.testStructPtr;
        testStructPtr = ptr;
    }
}

UniquePtr!int makeSmart() {
    int* intPtr = makeRaw(5);
    UniquePtr!int ptr = UniquePtr!int(intPtr);
    return ptr;
}

ResultPtr!int makeSmartResult() {
    int* intPtr = makeRaw(5);
    ResultPtr!int ptr = successPtr(intPtr);
    return ptr;
}

void runStdMemoryTests() {
    runRawPointerTests();
    runUniquePointerTests();
    runSharedPointerTests();
    runResultPointerTests();
}

void runRawPointerTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Raw-pointer tests --");

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
}

void runUniquePointerTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Unique-pointer tests --");

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

    test("A unique pointer's ownership can be released", {
        auto rawPtr = makeRaw!TestStruct;
        auto uniquePtr = rawPtr.unique;
        auto rawPtr2 = uniquePtr.release;
        assert(uniquePtr.ptr is null);
        assert(rawPtr2 is rawPtr);
    });

    test("A unique pointer's ownership can be swapped", {
        auto rawPtr = makeRaw!TestStruct;
        auto uniquePtr = rawPtr.unique;
        auto rawPtr2 = makeRaw!TestStruct;
        auto uniquePtr2 = rawPtr2.unique;
        uniquePtr.swap(uniquePtr2);
        assert(uniquePtr.ptr is rawPtr2);
        assert(uniquePtr2.ptr is rawPtr);
    });

    test("A unique pointer can be reset", {
        auto rawPtr = makeRaw!TestStruct;
        auto rawPtr2 = makeRaw!TestStruct;
        auto uniquePtr = rawPtr.unique;
        uniquePtr.reset(rawPtr2);
        assert(uniquePtr.ptr is rawPtr2);
    });

    test("A unique pointer pointing to an array can be accessed like one", {
        auto rawPtr = makeRawArray!int(10, 42);
        auto uniquePtr = rawPtr.ptr.unique;

        for (size_t i = 0; i < 10; i++) {
            assert(uniquePtr[i] == 42);
        }
    });

    test("Create and use a unique pointer of a void pointer", {
        void* ptr = makeRaw!int(88);
        auto uniquePtr = UniquePtr!void(ptr);
        assert(*(cast(int*) uniquePtr.ptr) == 88);
    });

    test("Check whether a unique pointer is defined", {
        auto uniquePtr = makeRaw!TestStruct().unique;
        assert(uniquePtr.isDefined);
        free(uniquePtr._ptr);
        uniquePtr._ptr = null;
        assert(!uniquePtr.isDefined);
    });

    test("Nullify a unique pointer, basically releasing it", {
        int* intPtr = makeRaw(5);
        auto ptr = intPtr.unique();
        assert(ptr.isDefined());
        assert(ptr._ptr is intPtr);

        ptr = null;
        assert(!ptr.isDefined());
        assert(ptr._ptr is null);
    });

    test("Initialize a null unique pointer", {
        auto ptr = UniquePtr!int();
        assert(ptr._ptr is null);
    });

    test("Move unique pointer to another existing one", {
        int* intPtr = makeRaw(5);
        UniquePtr!int ptr1 = UniquePtr!int(intPtr);
        UniquePtr!int ptr2;
        move(ptr1, ptr2);

        assert(ptr1._ptr is null);
        assert(ptr2._ptr is intPtr);
    });

    test("Return unique pointer in factory method", {
        UniquePtr!int result = makeSmart();
        assert(result.ptr !is null);
        assert(*result.ptr == 5);
    });
}

void runSharedPointerTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Shared-pointer tests --");

    test("Create and use a shared pointer", {
        auto sharedPtr = SharedPtr!TestStruct(makeRaw!TestStruct);
        assert(sharedPtr.ptr.a == 42);
        assert(sharedPtr.ptr.b == 66);
        assert(sharedPtr.useCount == 1);

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
            assert(sharedPtr.useCount == 1);
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
            assert(sharedPtr.useCount == 1);
            assert(sharedPtr.ptr is rawPtr);
            assert(!testStructDestroyed);

            {
                SharedPtr!TestStruct sharedPtr2 = sharedPtr;
                assert(sharedPtr.useCount == 2);
                assert(*(sharedPtr2.refCount) == 2);
                assert(sharedPtr.ptr is rawPtr);
                assert(sharedPtr2.ptr is rawPtr);
                assert(!testStructDestroyed);
            }

            assert(!testStructDestroyed);
            assert(sharedPtr.useCount == 1);
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
        assert(sharedPtr2.useCount == 2);
    });

    test("Convert a unique pointer into a shared pointer", {
        auto uniquePtr = makeUnique!TestStruct;
        auto sharedPtr = uniquePtr.share;
        assert(uniquePtr.ptr is null);
        assert(sharedPtr.ptr !is null);
        assert(sharedPtr.useCount == 1);
    });

    test("A shared pointer pointing to an array can be accessed like one", {
        auto rawPtr = makeRawArray!int(10, 42);
        auto sharedPtr = rawPtr.ptr.share;

        for (size_t i = 0; i < 10; i++) {
            assert(sharedPtr[i] == 42);
        }
    });

    test("Create and use a shared pointer of a void pointer", {
        void* ptr = makeRaw!int(42);
        auto sharedPtr = SharedPtr!void(ptr);
        assert(sharedPtr.ptr !is null);
        assert(sharedPtr.useCount == 1);
        assert(*(cast(int*) sharedPtr.ptr) == 42);
    });

    test("Shared pointer in a container is properly refcounted", {
        auto sharedPtr = makeShared!TestStruct;
        assert(sharedPtr.useCount == 1);
        auto container = TestSharedContainer(sharedPtr);
        assert(sharedPtr.useCount == 2);
        assert(container.testStructPtr.useCount == 2);

        {
            auto container2 = TestSharedContainer(sharedPtr);
            assert(sharedPtr.useCount == 3);
            assert(container.testStructPtr.useCount == 3);
            assert(container2.testStructPtr.useCount == 3);
        }

        assert(sharedPtr.useCount == 2);
        assert(container.testStructPtr.useCount == 2);
    });

    test("Shared pointer in a shared container is properly cleaned up", {
        ///
        {
            auto sharedPtr = makeShared!TestStruct;
            assert(sharedPtr.useCount == 1);

            auto sharedContainer = makeShared(TestSharedContainer(sharedPtr));
            assert(sharedPtr.useCount == 2);
            assert(sharedContainer.testStructPtr.ptr is sharedPtr.ptr);
            assert(sharedContainer.testStructPtr.refCount is sharedPtr.refCount);
            testStructDestroyed = false;
        }

        assert(testStructDestroyed);
    });

    test("Check whether a shared pointer is defined", {
        auto sharedPtr = makeShared!TestStruct;
        assert(sharedPtr.isDefined);
        free(sharedPtr._ptr);
        free(sharedPtr.refCount);
        sharedPtr._ptr = null;
        sharedPtr.refCount = null;
        assert(!sharedPtr.isDefined);
    });

    test("Cast a shared pointer", {
        auto voidPtr = makeSharedVoid(5);
        {
            auto intPtr = voidPtr.as!int;
            assert(voidPtr.ptr is intPtr.ptr);
            assert(intPtr.useCount == 2);
        }

        assert(voidPtr.useCount == 1);
    });

    test("Nullify a shared pointer", {
        int* intPtr = makeRaw(5);
        auto ptr = intPtr.share();
        assert(ptr.isDefined());
        assert(ptr._ptr == intPtr);

        ptr = null;
        assert(!ptr.isDefined());
        assert(ptr._ptr == null);
    });
}

void runResultPointerTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- Result-pointer tests --");

    test("Create and use a result pointer with successful result", {
        auto resultPtr = successPtr(makeRaw!TestStruct);
        assert(resultPtr.isSuccessful());
        assert(!resultPtr.isFailure());
        assert(resultPtr.errorMessage == "");
        assert(resultPtr.ptr.a == 42);
        assert(resultPtr.ptr.a == 42);
        assert(resultPtr.ptr.b == 66);

        resultPtr.doubleValues();
        assert(resultPtr.a == 84);
        assert(resultPtr.b == 132);
    });

    test("Create and use a result pointer with failed result", {
        auto resultPtr = failedPtr!TestStruct("I do not like it");
        assert(resultPtr.isFailure());
        assert(!resultPtr.isSuccessful());
        assert(resultPtr.errorMessage == "I do not like it");
    });

    test("A destroyed result pointer will nullify the container pointer", {
        testStructDestroyed = false;
        {
            auto resultPtr = successPtr(makeRaw!TestStruct);
            testStructDestroyed = false;
            assert(resultPtr.ptr !is null);
        }

        assert(testStructDestroyed);
    });

    test("A destroyed result pointer will destroy the contained pointer", {
        auto rawPtr = makeRaw!TestStruct();
        testStructDestroyed = false;
        {
            auto resultPtr = successPtr(rawPtr);
            assert(resultPtr.ptr !is null);
            assert(!testStructDestroyed);
        }

        assert(testStructDestroyed);
    });

    test("A result pointer is destroyed when containing objects are", {
        testStructDestroyed = false;
        {
            TestResultContainer(successPtr(makeRaw!TestStruct));
        }

        assert(testStructDestroyed);
    });

    test("A result pointer cannot be copied", {
        auto resultPtr = successPtr(makeRaw!TestStruct);
        assert(!__traits(compiles, mixin("auto resultPtr2 = resultPtr")));
    });

    test("A result pointer's ownership can be moved", {
        auto rawPtr = makeRaw!TestStruct;
        auto resultPtr = rawPtr.successPtr;
        auto resultPtr2 = resultPtr.move;

        assert(resultPtr.ptr is null);
        assert(resultPtr.isFailure());
        assert(resultPtr.errorMessage == "Result pointer is released.");

        assert(resultPtr2.ptr is rawPtr);
        assert(resultPtr2.isSuccessful());
        assert(resultPtr2.errorMessage == "");
    });

    test("A result pointer's ownership can be released", {
        auto rawPtr = makeRaw!TestStruct;
        auto resultPtr = rawPtr.successPtr;
        auto rawPtr2 = resultPtr.release;

        assert(resultPtr.ptr is null);
        assert(resultPtr.isFailure());
        assert(resultPtr.errorMessage == "Result pointer is released.");
        assert(rawPtr2 is rawPtr);
    });

    test("A result pointer's ownership can be swapped", {
        auto rawPtr = makeRaw!TestStruct;
        auto resultPtr = rawPtr.successPtr;
        auto rawPtr2 = makeRaw!TestStruct;
        auto resultPtr2 = rawPtr2.successPtr;

        resultPtr.swap(resultPtr2);

        assert(resultPtr.ptr is rawPtr2);
        assert(resultPtr.isSuccessful());
        assert(resultPtr.errorMessage == "");

        assert(resultPtr2.ptr is rawPtr);
        assert(resultPtr2.isSuccessful());
        assert(resultPtr2.errorMessage == "");
    });

    test("A result pointer's ownership can be swapped when one is failed", {
        auto rawPtr = makeRaw!TestStruct;
        auto resultPtr = rawPtr.successPtr;
        auto resultPtr2 = failedPtr!TestStruct("It is not right");

        resultPtr.swap(resultPtr2);

        assert(resultPtr.ptr is null);
        assert(resultPtr.isFailure());
        assert(resultPtr.errorMessage == "It is not right");

        assert(resultPtr2.ptr is rawPtr);
        assert(resultPtr2.isSuccessful());
        assert(resultPtr2.errorMessage == "");
    });

    test("A result pointer can be reset", {
        auto rawPtr = makeRaw!TestStruct;
        auto rawPtr2 = makeRaw!TestStruct;
        auto resultPtr = rawPtr.successPtr;

        resultPtr.reset(rawPtr2);

        assert(resultPtr.ptr is rawPtr2);
        assert(resultPtr.isSuccessful());
        assert(resultPtr.errorMessage == "");
    });

    test("A result pointer pointing to an array can be accessed like one", {
        auto rawPtr = makeRawArray!int(10, 42);
        auto resultPtr = rawPtr.ptr.successPtr;

        for (size_t i = 0; i < 10; i++) {
            assert(resultPtr[i] == 42);
        }
    });

    test("Create and use a result pointer of a void pointer", {
        void* ptr = makeRaw!int(88);
        auto resultPtr = successPtr!void(ptr);
        assert(*(cast(int*) resultPtr.ptr) == 88);
    });

    test("Check whether a result pointer is defined", {
        auto resultPtr = makeRaw!TestStruct().successPtr;
        assert(resultPtr.isDefined);
        free(resultPtr._ptr);
        resultPtr._ptr = null;
        assert(!resultPtr.isDefined);
    });

    test("Nullify a result pointer, basically releasing it", {
        int* intPtr = makeRaw(5);
        auto ptr = intPtr.successPtr;
        assert(ptr.isDefined());
        assert(ptr._ptr is intPtr);

        ptr = null;
        assert(!ptr.isDefined());
        assert(ptr._ptr is null);
    });

    test("Initialize a null result pointer", {
        auto ptr = successPtr!int(null);
        assert(ptr._ptr is null);
    });

    test("Move result pointer to another existing one", {
        int* intPtr = makeRaw(5);
        ResultPtr!int ptr1 = successPtr!int(intPtr);
        ResultPtr!int ptr2;
        move(ptr1, ptr2);

        assert(ptr1._ptr is null);
        assert(ptr1.isFailure());
        assert(ptr1.errorMessage == "Result pointer is released.");

        assert(ptr2._ptr is intPtr);
        assert(ptr2.isSuccessful());
        assert(ptr2.errorMessage == "");
    });

    test("Return result pointer in factory method", {
        ResultPtr!int result = makeSmartResult();
        assert(result.ptr !is null);
        assert(result.isSuccessful());
        assert(result.errorMessage == "");
        assert(*result.ptr == 5);
    });

    test("Convert ResultPtr into a SharedPtr", {
        int* intPtr = makeRaw(5);
        ResultPtr!int resultPtr = successPtr!int(intPtr);
        SharedPtr!int sharedPtr = resultPtr.share();

        assert(resultPtr._ptr is null);
        assert(resultPtr.isFailure());
        assert(resultPtr.errorMessage == "Result pointer is released.");

        assert(sharedPtr.ptr is intPtr);
    });

    test("Convert ResultPtr into a UniquePtr", {
        int* intPtr = makeRaw(5);
        ResultPtr!int resultPtr = successPtr!int(intPtr);
        UniquePtr!int uniquePtr = resultPtr.unique();

        assert(resultPtr._ptr is null);
        assert(resultPtr.isFailure());
        assert(resultPtr.errorMessage == "Result pointer is released.");

        assert(uniquePtr.ptr is intPtr);
    });
}
