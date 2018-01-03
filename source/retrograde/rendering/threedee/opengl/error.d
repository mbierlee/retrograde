/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2018 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.rendering.threedee.opengl.error;

version(Have_derelict_gl3) {

import std.experimental.logger;
import std.string;
import std.exception;

import poodinis;

import derelict.opengl3.gl3;

class ErrorService {

    @Autowire
    private Logger logger;

    public GLenum[] getAllErrors() {
        GLenum[] errors;
        while(true) {
            GLenum error = glGetError();
            if (error == GL_NO_ERROR) {
                break;
            }

            errors ~= error;
        }
        return errors;
    }

    public void throwOnErrors(ExceptionType : Exception)(string action = "") {
        auto errors = getAllErrors();
        auto actionSpecifier = !action.empty ? " while " ~ action : "";
        if (errors.length > 0) {
            throw new ExceptionType(format("OpenGL errors were flagged%s: %s", actionSpecifier, errors));
        }
    }

    public void logErrorsIfAny() {
        auto errors = getAllErrors();
        if (errors.length > 0) {
            logger.error(format("OpenGL errors were flagged: %s", errors));
        }

    }
}

}
