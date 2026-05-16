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

module retrograde.std.result;

import retrograde.std.string : String;

/**
 * A result is a type that can be used to return a value or an error message.
 * It is used for idiomatic error handling.
 */
struct Result(T) {
    private bool success;
    private T _value;
    private String _errorMessage;

    this(ref return scope inout typeof(this) other) {
        this.success = other.success;
        static if (is(T == struct)) {
            this._value = other._value;
        } else {
            this._value = cast(T) other._value;
        }

        this._errorMessage = other._errorMessage;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        this.success = other.success;
        static if (is(T == struct)) {
            this._value = other._value;
        } else {
            this._value = cast(T) other._value;
        }

        this._errorMessage = other._errorMessage;
    }

    void opAssign()(typeof(this) other) {
        this.success = other.success;
        this._value = other._value;
        this._errorMessage = other._errorMessage;
    }

    /**
     * Returns: Wheter the result is successful or not.
     */
    bool isSuccessful() const {
        return this.success;
    }

    /**
     * Returns: Wheter the result is failed or not.
     */
    bool isFailure() const {
        return !this.success;
    }

    /**
     * Returns: The value of the result.
     */
    T value() {
        assert(this.success, "Result is not successful and should not be accessed. Make sure to check isSuccessful() first.");
        return this._value;
    }

    /**
     * Returns: The error message of the result if it is failed.
     */
    String errorMessage() const {
        assert(!this.success, "Result is successful so it does not have an error message. Make sure to check isSuccessful() first.");
        return this._errorMessage;
    }
}

/**
 * Create a successful result with a value.
 *
 * Params:
 *   T = The type of the value.
 *   value = The value to return.
 * Returns: A successful result.
 */
Result!T success(T)(T value) if (!is(T == void)) {
    Result!T result;
    result.success = true;
    result._value = value;
    return result;
}

/**
 * Create a failed result with an error message.
 *
 * Params:
 *   T = The type of the value. Even though the result is failed, a type is still required.
 *   errorMessage = The error message to return.
 * Returns: A failed result.
 */
Result!T failure(T)(string errorMessage) if (!is(T == void)) {
    Result!T result;
    result.success = false;
    result._errorMessage = errorMessage;
    return result;
}

/// Ditto
Result!T failure(T)(String errorMessage) if (!is(T == void)) {
    Result!T result;
    result.success = false;
    result._errorMessage = errorMessage;
    return result;
}

/**
 * Calls the given action with the result's value if the result is successful.
 * Does nothing if the result is a failure.
 *
 * Params:
 *   T = The type of the result's value.
 *   Fn = The type of the callable action.
 *   res = The result to check.
 *   onSuccess = The action to call with the result's value on success.
 */
void withResult(T, Fn)(Result!T res, scope Fn onSuccess) if (!is(T == void)) {
    if (res.isSuccessful) {
        onSuccess(res.value);
    }
}

/**
 * Calls the given action with the result's value if the result is successful,
 * or calls onError with the error message if the result is a failure.
 *
 * Params:
 *   T = The type of the result's value.
 *   Fn = The type of the callable action.
 *   ErrFn = The type of the callable error action.
 *   res = The result to check.
 *   onSuccess = The action to call with the result's value on success.
 *   onError = The action to call with the error message on failure.
 */
void withResult(T, Fn, ErrFn)(Result!T res, scope Fn onSuccess, scope ErrFn onError)
        if (!is(T == void)) {
    if (res.isSuccessful) {
        onSuccess(res.value);
    } else {
        onError(res.errorMessage);
    }
}

/**
 * An OperationResult is a type that can be used to return a success or failure
 * of an operation that does not return a value. It is used for idiomatic error handling.
 */
struct OperationResult {
    private bool success;
    private String _errorMessage;

    this(ref return scope inout typeof(this) other) {
        this.success = other.success;
        this._errorMessage = other._errorMessage;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        this.success = other.success;
        this._errorMessage = other._errorMessage;
    }

    void opAssign()(typeof(this) other) {
        this.success = other.success;
        this._errorMessage = other._errorMessage;
    }

    /**
     * Returns: Wheter the result is successful or not.
     */
    bool isSuccessful() const {
        return this.success;
    }

    /**
     * Returns: Wheter the result is failed or not.
     */
    bool isFailure() const {
        return !this.success;
    }

    /**
     * Returns: The error message of the result if it is failed.
     */
    String errorMessage() const {
        return this._errorMessage;
    }
}

/**
 * Create a successful OperationResult.
 *
 * Returns: A successful OperationResult.
 */
OperationResult success() {
    OperationResult result;
    result.success = true;
    return result;
}

/**
 * Create a failed OperationResult with an error message.
 *
 * Params:
 *   errorMessage = The error message to return.
 * Returns: A failed OperationResult.
 */
OperationResult failure(string errorMessage) {
    OperationResult result;
    result.success = false;
    result._errorMessage = errorMessage;
    return result;
}

/// Ditto
OperationResult failure(String errorMessage) {
    OperationResult result;
    result.success = false;
    result._errorMessage = errorMessage;
    return result;
}

/**
 * Calls the given action if the OperationResult is successful.
 * Does nothing if the result is a failure.
 *
 * Params:
 *   Fn = The type of the callable action.
 *   res = The result to check.
 *   onSuccess = The action to call on success.
 */
void withResult(Fn)(OperationResult res, scope Fn onSuccess) {
    if (res.isSuccessful) {
        onSuccess();
    }
}

/**
 * Calls the given action if the OperationResult is successful,
 * or calls onError with the error message if the result is a failure.
 *
 * Params:
 *   Fn = The type of the callable action.
 *   ErrFn = The type of the callable error action.
 *   res = The result to check.
 *   onSuccess = The action to call on success.
 *   onError = The action to call with the error message on failure.
 */
void withResult(Fn, ErrFn)(OperationResult res, scope Fn onSuccess, scope ErrFn onError) {
    if (res.isSuccessful) {
        onSuccess();
    } else {
        onError(res.errorMessage);
    }
}

version (UnitTesting)  :  ///

void runResultTests() {
    import retrograde.std.test : test, writeSection;
    import retrograde.std.string : s;

    writeSection("-- Result tests --");

    test("Result can be created with a success", () {
        auto result = success(42);
        assert(result.isSuccessful);
        assert(result.value == 42);
    });

    test("Result can be created with a failure", () {
        auto result = failure!int("Something went wrong");
        assert(!result.isSuccessful);
        assert(result.errorMessage == "Something went wrong");
    });

    test("Result failure can be created from a String", () {
        auto result = failure!int("Something went wrong".s);
        assert(!result.isSuccessful);
        assert(result.errorMessage == "Something went wrong");
    });

    test("OperationResult can be created with a success", {
        auto result = success();
        assert(result.isSuccessful);
    });

    test("OperationResult can be created with a failure", {
        auto result = failure("Something went wrong");
        assert(!result.isSuccessful);
        assert(result.errorMessage == "Something went wrong");
    });

    test("OperationResult failure can be created from a String", {
        auto result = failure("Something went wrong".s);
        assert(!result.isSuccessful);
        assert(result.errorMessage == "Something went wrong");
    });

    test("success returns a successful OperationResult", {
        auto result = success();
        assert(result.isSuccessful);
    });

    test("failure returns a failed OperationResult", {
        auto result = failure("Something went wrong");
        assert(!result.isSuccessful);
        assert(result.errorMessage == "Something went wrong");
    });

    test("Result isFailure is opposite of isSuccessful", {
        auto result = failure!int("Something went wrong");
        assert(result.isFailure);
        assert(!result.isSuccessful);
    });

    test("OperationResult isFailure is opposite of isSuccessful", {
        auto result = failure("Something went wrong");
        assert(result.isFailure);
        assert(!result.isSuccessful);
    });

    test("withResult calls action with value on successful Result", {
        auto result = success(42);
        int received = 0;
        result.withResult((int v) { received = v; });
        assert(received == 42);
    });

    test("withResult does not call action on failed Result", {
        auto result = failure!int("error");
        bool called = false;
        result.withResult((int v) { called = true; });
        assert(!called);
    });

    test("withResult calls action on successful OperationResult", {
        auto result = success();
        bool called = false;
        result.withResult(() { called = true; });
        assert(called);
    });

    test("withResult does not call action on failed OperationResult", {
        auto result = failure("error");
        bool called = false;
        result.withResult(() { called = true; });
        assert(!called);
    });

    test("withResult calls onError with error message on failed Result", {
        auto result = failure!int("something went wrong");
        String received;
        result.withResult((int v) {}, (String e) { received = e; });
        assert(received == "something went wrong");
    });

    test("withResult does not call onError on successful Result", {
        auto result = success(42);
        bool called = false;
        result.withResult((int v) {}, (String e) { called = true; });
        assert(!called);
    });

    test("withResult calls onError with error message on failed OperationResult", {
        auto result = failure("something went wrong");
        String received;
        result.withResult(() {}, (String e) { received = e; });
        assert(received == "something went wrong");
    });

    test("withResult does not call onError on successful OperationResult", {
        auto result = success();
        bool called = false;
        result.withResult(() {}, (String e) { called = true; });
        assert(!called);
    });

    test("Result error message owns its memory", {
        // Ensures the error message survives even after temporaries used to
        // build it have gone out of scope. Previously this could dangle.
        Result!int makeFailure() {
            String msg = "scoped failure".s;
            return failure!int(msg);
        }

        auto result = makeFailure();
        assert(result.errorMessage == "scoped failure");
    });
}
