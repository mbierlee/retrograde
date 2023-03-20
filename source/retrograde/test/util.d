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

module retrograde.test.util;

version (unittest) {
    import std.conv : to;

    /**
     * Asserts that the given expression throws an exception of the given type
     * and that the exception message is equal to the given message.
     *
     * Params:
     *  ExceptionT = The type of exception that is expected to be thrown.
     *  ExpressionT = The expression that is expected to throw an exception.
     *  expectedMessage = The expected exception message.
     */
    void assertThrownMsg(ExceptionT : Throwable = Exception, ExpressionT)(
        string expectedMessage, lazy ExpressionT expression)
            if (!is(ExceptionT == Exception)) {
        try {
            expression;
            assert(false, "No exception was thrown. Expected: " ~ typeid(ExceptionT).to!string);
        } catch (ExceptionT e) {
            assert(e.message == expectedMessage, "Exception message was different. Expected: \"" ~ expectedMessage ~
                    "\", actual: \"" ~ e.message ~ "\"");
        } catch (Exception e) {
            //dfmt off
            assert(false, "Different type of exception was thrown. Expected: " ~
                    typeid(ExceptionT).to!string ~ ", actual: " ~ typeid(typeof(e)).to!string);
            //dfmt on
        }
    }

    /**
     * Asserts that the given expression throws an exception of the given type
     * and that the exception message is equal to the given message.
     *
     * Params:
     *  ExpressionT = The expression that is expected to throw an exception.
     *  expectedMessage = The expected exception message.
     */
    void assertThrownMsg(ExpressionT)(string expectedMessage, lazy ExpressionT expression) {
        try {
            expression;
            assert(false, "No exception was thrown.");
        } catch (Exception e) {
            assert(e.message == expectedMessage, "Exception message was different. Expected: \"" ~ expectedMessage ~
                    "\", actual: \"" ~ e.message ~ "\"");
        }
    }
}
