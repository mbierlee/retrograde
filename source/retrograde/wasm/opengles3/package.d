/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2025 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.wasm.opengles3;

version (WebAssembly)  :  //
version (OpenGLES3)  :  //

public import retrograde.wasm.opengles3.types;
public import retrograde.wasm.opengles3.constants;
public import retrograde.wasm.opengles3.functions;

import retrograde.api.opengles3 : glesSetViewport = setViewport;

export extern (C) void resizeCanvasToDisplaySize();

export extern (C) void setViewport(uint width, uint height) {
    glesSetViewport(width, height);
}

export extern (C) GLuint compileShaderProgram(string name, string vertexShader, string fragmentShader);
