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

module retrograde.engine.rendering;

import retrograde.std.stdio : writeln; // temp

import retrograde.std.collections : Array;

version (WebAssembly) {
    import retrograde.wasm.glapi;
}

void initRenderer() {
    if (renderPasses.length == 0) {
        renderPasses.add(genericRenderPass);
    }

    version (WebAssembly) { // Temp to make unit tests still work
        foreach (renderPass; renderPasses) {
            auto program = compileShaderProgram(
                renderPass.passName,
                renderPass.vertexShader,
                renderPass.fragmentShader
            );

            renderPass.program = program;
        }
    }
}

void renderFrame() {
    // writeln("render");
}

struct RenderPass {
    string passName;
    string vertexShader;
    string fragmentShader;
    uint program;
}

RenderPass genericRenderPass = RenderPass(
    "generic",
    import("ogles3/generic_vertex.glsl"),
    import("ogles3/generic_fragment.glsl")
);

Array!RenderPass renderPasses;
