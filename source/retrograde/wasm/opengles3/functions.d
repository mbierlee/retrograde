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

module retrograde.wasm.opengles3.functions;

import retrograde.wasm.opengles3.types;

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
export extern (C) void glEnable(GLenum cap);
export extern (C) void glDisable(GLenum cap);
export extern (C) void glCullFace(GLenum mode);
export extern (C) GLint glGetUniformLocation(GLuint program, string name);
export extern (C) void glUniformMatrix4fv(GLint location, GLsizei count, GLbool transpose, GLfloat[] value);
