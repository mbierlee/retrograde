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

module retrograde.wasm.opengles3.functions;

version (WebAssembly)  :  //
version (OpenGLES3)  :  //

import retrograde.wasm.opengles3.types;

extern (C):

GLuint glCreateBuffer();
void glDeleteBuffer(GLuint buffer);
void glBindBuffer(GLenum target, GLuint buffer);
void glBufferDataFloat(GLenum target, GLfloat[] data, GLenum usage);
void glBufferDataUInt(GLenum target, GLuint[] data, GLenum usage);
GLuint glCreateVertexArray();
void glDeleteVertexArray(GLuint vertextArrayObject);
void glBindVertexArray(GLuint vertextArrayObject);
void glEnableVertexAttribArray(GLuint index);
void glVertexAttribPointer(GLuint index, GLint size, GLenum type, GLbool normalized, GLsizei stride, GLintptr offset);
void glClearColor(GLclampf red, GLclampf green, GLclampf blue, GLclampf alpha);
void glClear(GLbitfield mask);
void glUseProgram(GLuint program);
void glDrawArrays(GLenum mode, GLint first, GLsizei count);
void glDrawElements(GLenum mode, GLsizei count, GLenum type, GLintptr indices);
void glEnable(GLenum cap);
void glDisable(GLenum cap);
void glCullFace(GLenum mode);
GLint glGetUniformLocation(GLuint program, string name);
GLint glGetAttribLocation(GLuint program, string name);
void glUniformMatrix4fv(GLint location, GLsizei count, GLbool transpose, GLfloat[] value);
void glDepthFunc(GLenum func);
void glStencilFunc(GLenum func, GLint refVal, GLuint mask);
void glBlendFunc(GLenum sfactor, GLenum dfactor);
GLuint glCreateTexture();
void glDeleteTexture(GLuint texture);
void glBindTexture(GLenum target, GLuint texture);
void glActiveTexture(GLenum texture);
void glTexImage2D(GLenum target, GLint level, GLint internalformat, GLsizei width, GLsizei height,
    GLint border, GLenum format, GLenum type, const(ubyte)[] pixels);
void glTexParameteri(GLenum target, GLenum pname, GLint param);
void glGenerateMipmap(GLenum target);
void glPixelStorei(GLenum pname, GLint param);
void glUniform1i(GLint location, GLint value);
