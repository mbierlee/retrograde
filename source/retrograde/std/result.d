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

module retrograde.std.result;

/** 
 * A result is a type that can be used to return a value or an error message.
 * It is used for idiomatic error handling.
 */
struct Result(T) {
    private bool success;
    private ResultValue!T payload;

    this(T value) {
        this.success = true;
        this.payload.value = value;
    }

    static if (!is(T == string)) {
        this(string errorMessage) {
            this.success = false;
            this.payload.errorMessage = errorMessage;
        }
    }

    bool isSuccessful() {
        return this.success;
    }

    T value() {
        assert(this.success, "Result is not successful and should not be accessed. Make sure to check isSuccessful() first.");
        return this.payload.value;
    }

    string errorMessage() {
        assert(!this.success, "Result is successful so it does not have an error message. Make sure to check isSuccessful() first.");
        return this.payload.errorMessage;
    }

    private static failure(string errorMessage) {
        return Result!T(errorMessage);
    }
}

/// Create a successful result with a value.
Result!T success(T)(T value) if (!is(T == void)) {
    return Result!T(value);
}

/// Create a failed result with an error message.
Result!T failure(T)(string errorMessage) if (!is(T == void)) {
    return Result!T.failure(errorMessage);
}

/** 
 * An OperationResult is a type that can be used to return a success or failure
 * of an operation that does not return a value. It is used for idiomatic error handling.
 */
struct OperationResult {
    private bool success;
    private string _errorMessage;

    this(bool isSuccessful, string errorMessage = "") {
        this.success = isSuccessful;
        this._errorMessage = errorMessage;
    }

    bool isSuccessful() {
        return this.success;
    }

    string errorMessage() {
        return this._errorMessage;
    }
}

/// Create a successful OperationResult.
OperationResult success() {
    return OperationResult(true);
}

/// Create a failed OperationResult with an error message.
OperationResult failure(string errorMessage) {
    return OperationResult(false, errorMessage);
}

private union ResultValue(T) {
    T value;
    string errorMessage;
}

version (unittest)  :  //

@("Result can be created with a value")
unittest {
    auto result = Result!int(42);
    assert(result.isSuccessful);
    assert(result.value == 42);
}

@("Result can be created with an error message")
unittest {
    auto result = Result!int("Something went wrong");
    assert(!result.isSuccessful);
    assert(result.errorMessage == "Something went wrong");
}

@("Result can be created with a string value")
unittest {
    auto result = Result!string("Hello world");
    assert(result.isSuccessful);
    assert(result.value == "Hello world");
}

@("success returns a successful result")
unittest {
    auto result = success(42);
    assert(result.isSuccessful);
    assert(result.value == 42);
}

@("failure returns a failed result")
unittest {
    auto result = failure!int("Something went wrong");
    assert(!result.isSuccessful);
    assert(result.errorMessage == "Something went wrong");
}

@("OperationResult can be created with a success")
unittest {
    auto result = OperationResult(true);
    assert(result.isSuccessful);
}

@("OperationResult can be created with a failure")
unittest {
    auto result = OperationResult(false, "Something went wrong");
    assert(!result.isSuccessful);
    assert(result.errorMessage == "Something went wrong");
}

@("success returns a successful OperationResult")
unittest {
    auto result = success();
    assert(result.isSuccessful);
}

@("failure returns a failed OperationResult")
unittest {
    auto result = failure("Something went wrong");
    assert(!result.isSuccessful);
    assert(result.errorMessage == "Something went wrong");
}
