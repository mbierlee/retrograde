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

module retrograde.std.option;

struct Option(T) {
    private T _value;
    private bool _isDefined;

    T value() {
        assert(this._isDefined, "Option does not have a value. Make sure to check isDefined() before calling value()");
        return this._value;
    }

    bool isDefined() {
        return this._isDefined;
    }

    bool isEmpty() {
        return !this._isDefined;
    }
}

Option!T some(T)(T value) {
    Option!T option;
    option._value = value;
    option._isDefined = true;
    return option;
}

Option!T none(T)() {
    Option!T option;
    option._isDefined = false;
    return option;
}

version (unittest)  :  //

@("Option created with some() is defined and has a value")
unittest {
    auto option = some!int(42);
    assert(option.isDefined());
    assert(option.value == 42);
}

@("Option created with none() is not defined and has no value")
unittest {
    auto option = none!int;
    assert(!option.isDefined());
}

@("Option isEmpty() is opposite of isDefined()")
unittest {
    auto option = some!int(42);
    assert(!option.isEmpty());
    assert(option.isDefined());

    option = none!int;
    assert(option.isEmpty());
    assert(!option.isDefined());
}
