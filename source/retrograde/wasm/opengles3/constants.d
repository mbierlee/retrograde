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

module retrograde.wasm.opengles3.constants;

version (WebAssembly)  :  //
version (OpenGLES3)  :  //

// https://developer.mozilla.org/en-US/docs/Web/API/WebGL_API/Constants

// Clearing buffers
enum GL_COLOR_BUFFER_BIT = 0x00004000;

// Rendering primitives
enum GL_TRIANGLES = 0x0004;

// Blending modes
enum GL_SRC_ALPHA = 0x0302;
enum GL_ONE_MINUS_SRC_ALPHA = 0x0303;

// Buffers
enum GL_STATIC_DRAW = 0x88E4;
enum GL_ARRAY_BUFFER = 0x8892;
enum GL_ELEMENT_ARRAY_BUFFER = 0x8893;

// Culling
enum GL_CULL_FACE = 0x0B44;
enum GL_FRONT = 0x0404;
enum GL_BACK = 0x0405;
enum GL_FRONT_AND_BACK = 0x0408;

// Enabling and disabling
enum GL_BLEND = 0x0BE2;
enum GL_DEPTH_TEST = 0x0B71;
enum GL_DITHER = 0x0BD0;
enum GL_STENCIL_TEST = 0x0B90;

// Depth or stencil tests
enum GL_EQUAL = 0x0202;
enum GL_LEQUAL = 0x0203;

// Data types
enum GL_UNSIGNED_INT = 0x1405;
enum GL_FLOAT = 0x1406;
