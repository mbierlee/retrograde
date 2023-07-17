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
     * Returns: The value of the result.
     */
    T value() {
        assert(this.success, "Result is not successful and should not be accessed. Make sure to check isSuccessful() first.");
        return this.payload.value;
    }

    /** 
     * Returns: The error message of the result if it is failed.
     */
    string errorMessage() {
        assert(!this.success, "Result is successful so it does not have an error message. Make sure to check isSuccessful() first.");
        return this.payload.errorMessage;
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
    result.payload.value = value;
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
     * Returns: The error message of the result if it is failed.
     */
    string errorMessage() {
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

private union ResultValue(T) {
    T value;
    string errorMessage;
}

version (UnitTesting)  :  ///

void runResultTests() {
    import retrograde.std.test : test, writeSection;

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

    test("OperationResult can be created with a success", {
        auto result = success();
        assert(result.isSuccessful);
    });

    test("OperationResult can be created with a failure", {
        auto result = failure("Something went wrong");
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
        auto result = failure("Something went wrong");
        assert(result.isFailure);
        assert(!result.isSuccessful);
    });

    test("OperationResult isFailure is opposite of isSuccessful", {
        auto result = failure("Something went wrong");
        assert(result.isFailure);
        assert(!result.isSuccessful);
    });
}
