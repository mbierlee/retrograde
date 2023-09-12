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

import retrograde.std.collections : Array;
import retrograde.std.memory : SharedPtr;
import retrograde.std.stringid : sid;

import retrograde.engine.service : entityManager;
import retrograde.engine.entity : Entity;
import retrograde.engine.glapi : initRenderApi, setClearColor, compileShaderProgram, initFrame, loadEntityModel, unloadEntityModel,
    drawModel;

import retrograde.data.model : ModelComponentType;

enum RenderableComponentType = sid("comp_renderable");

void initRenderer() {
    initRenderApi();
    setClearColor(Color(0, 0, 0, 1));
    initRenderPasses();
    initEntityManagerHooks();
}

void renderFrame() {
    initFrame();

    foreach (const ref renderPass; renderPasses) {
        entityManager.forEachEntity((SharedPtr!Entity entity) {
            if (!entity.ptr.hasComponent(RenderableComponentType)) {
                return;
            }

            drawModel(entity, renderPass);
        });
    }
}

struct RenderPass {
    string passName;
    string vertexShader;
    string fragmentShader;
    uint program;
}

RenderPass genericRenderPass = RenderPass(
    "generic",
    import("opengles3/generic_vertex.glsl"),
    import("opengles3/generic_fragment.glsl")
);

Array!RenderPass renderPasses;

struct Color {
    /// Red
    float r;

    /// Green
    float g;

    /// Blue
    float b;

    /// Alpha
    float a;
}

private void initRenderPasses() {
    if (renderPasses.length == 0) {
        renderPasses.add(genericRenderPass);
    }

    foreach (ref renderPass; renderPasses) {
        auto program = compileShaderProgram(
            renderPass.passName,
            renderPass.vertexShader,
            renderPass.fragmentShader
        );

        renderPass.program = program;
    }
}

private void initEntityManagerHooks() {
    entityManager.addEntityAddedHook((SharedPtr!Entity entity) {
        if (entity.hasComponent(ModelComponentType)) {
            loadEntityModel(entity);
        }
    });

    entityManager.addEntityRemovedHook((SharedPtr!Entity entity) {
        unloadEntityModel(entity);
    });
}
