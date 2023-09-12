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

module retrograde.wasm.opengles3;

version (WebAssembly)  :  //
version (OpenGLES3)  :  //

import retrograde.api.opengles3 : glesSetViewport = setViewport;

alias GLuint = uint;
alias GLint = int;
alias GLfloat = float;
alias GLclampf = float; // Use clamp()
alias GLbool = bool;
alias GLsizei = int;
alias GLintptr = int;
alias GLenum = uint;
alias GLbitfield = uint;

// https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Constants

// Clearing buffers
enum GL_COLOR_BUFFER_BIT = 0x00004000;

// Rendering primitives
enum GL_TRIANGLES = 0x0004;

// Buffers
enum GL_STATIC_DRAW = 0x88E4;
enum GL_ARRAY_BUFFER = 0x8892;
enum GL_ELEMENT_ARRAY_BUFFER = 0x8893;

// Enabling and disabling
enum GL_DITHER = 0x0BD0;

// Data types
enum GL_UNSIGNED_INT = 0x1405;
enum GL_FLOAT = 0x1406;

export extern (C) void resizeCanvasToDisplaySize();

export extern (C) GLuint glCreateBuffer();
export extern (C) void glDeleteBuffer(GLuint buffer);
export extern (C) void glBindBuffer(GLenum target, GLuint buffer);
export extern (C) void glBufferDataFloat(GLenum target, GLfloat[] data, GLenum usage);
export extern (C) void glBufferDataUInt(GLenum target, GLuint[] data, GLenum usage);
export extern (C) GLuint glCreateVertexArray();
export extern (C) void glDeleteVertexArray(GLuint vertextArrayObject);
export extern (C) void glBindVertexArray(GLuint vertextArrayObject);
export extern (C) void glEnableVertexAttribArray(GLuint index);
export extern (C) void glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLbool normalized, GLsizei stride,
    GLintptr offset);
export extern (C) void glClearColor(GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
export extern (C) void glClear(GLbitfield mask);
export extern (C) void glUseProgram(GLuint program);
export extern (C) void glDrawArrays(GLenum mode, GLint first, GLsizei count);
export extern (C) void glDrawElements(GLenum mode, GLsizei count, GLenum type, GLintptr indices);
export extern (C) void glDisable(GLenum cap);

export extern (C) void setViewport(uint width, uint height) {
    glesSetViewport(width, height);
}

export extern (C) GLuint compileShaderProgram(string name, string vertexShader, string fragmentShader);
