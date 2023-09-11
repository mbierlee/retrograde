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

enum GL_COLOR_BUFFER_BIT = 0x00004000;
enum GL_TRIANGLES = 0x0004;
enum GL_FLOAT = 0x1406;

export extern (C) void resizeCanvasToDisplaySize();

export extern (C) GLuint glCreateBuffer();
export extern (C) void glBindArrayBuffer(GLuint buffer);
export extern (C) void glArrayBufferData(GLfloat[] data);
export extern (C) GLuint glCreateVertexArray();
export extern (C) void glBindVertexArray(GLuint vertextArrayObject);
export extern (C) void glEnableVertexAttribArray(GLuint index);
export extern (C) void glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLbool normalized, GLsizei stride,
    GLintptr offset);
export extern (C) void glClearColor(GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
export extern (C) void glClear(GLbitfield mask);
export extern (C) void glUseProgram(GLuint program);
export extern (C) void glDrawArrays(GLenum mode, GLint first, GLsizei count);

export extern (C) void setViewport(uint width, uint height) {
    glesSetViewport(width, height);
}

export extern (C) GLuint compileShaderProgram(string name, string vertexShader, string fragmentShader);
