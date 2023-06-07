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

    bool isSuccessful() {
        return this.success;
    }

    bool isFailure() {
        return !this.success;
    }

    T value() {
        assert(this.success, "Result is not successful and should not be accessed. Make sure to check isSuccessful() first.");
        return this.payload.value;
    }

    string errorMessage() {
        assert(!this.success, "Result is successful so it does not have an error message. Make sure to check isSuccessful() first.");
        return this.payload.errorMessage;
    }
}

/// Create a successful result with a value.
Result!T success(T)(T value) if (!is(T == void)) {
    Result!T result;
    result.success = true;
    result.payload.value = value;
    return result;
}

/// Create a failed result with an error message.
Result!T failure(T)(string errorMessage) if (!is(T == void)) {
    Result!T result;
    result.success = false;
    result.payload.errorMessage = errorMessage;
    return result;
}

/** 
 * An OperationResult is a type that can be used to return a success or failure
 * of an operation that does not return a value. It is used for idiomatic error handling.
 */
struct OperationResult {
    private bool success;
    private string _errorMessage;

    bool isSuccessful() {
        return this.success;
    }

    bool isFailure() {
        return !this.success;
    }

    string errorMessage() {
        return this._errorMessage;
    }
}

/// Create a successful OperationResult.
OperationResult success() {
    OperationResult result;
    result.success = true;
    return result;
}

/// Create a failed OperationResult with an error message.
OperationResult failure(string errorMessage) {
    OperationResult result;
    result.success = false;
    result._errorMessage = errorMessage;
    return result;
}

private union ResultValue(T) {
    T value;
    string errorMessage;
}

version (unittest)  :  //

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
    auto result = success();
    assert(result.isSuccessful);
}

@("OperationResult can be created with a failure")
unittest {
    auto result = failure("Something went wrong");
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

@("Result isFailure is opposite of isSuccessful")
unittest {
    auto result = failure("Something went wrong");
    assert(result.isFailure);
    assert(!result.isSuccessful);
}

@("OperationResult isFailure is opposite of isSuccessful")
unittest {
    auto result = failure("Something went wrong");
    assert(result.isFailure);
    assert(!result.isSuccessful);
}
