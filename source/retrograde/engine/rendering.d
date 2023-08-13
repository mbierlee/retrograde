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
import retrograde.std.memory : SharedPtr;
import retrograde.std.stringid : sid;

import retrograde.engine.service : entityManager;
import retrograde.engine.entity : Entity;
import retrograde.engine.glapi : compileShaderProgram;

enum RenderableComponentType = sid("comp_renderable");

void initRenderer() {
    if (renderPasses.length == 0) {
        renderPasses.add(genericRenderPass);
    }

    foreach (renderPass; renderPasses) {
        auto program = compileShaderProgram(
            renderPass.passName,
            renderPass.vertexShader,
            renderPass.fragmentShader
        );

        renderPass.program = program;
    }
}

void renderFrame() {
    entityManager.forEachEntity((SharedPtr!Entity entity) {
        if (!entity.ptr.hasComponent(RenderableComponentType)) {
            return;
        }

        //TODO: the rest
    });
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
