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
import retrograde.std.stringid : sid, StringId;

import retrograde.engine.service : entityManager;
import retrograde.engine.entity : Entity;
import retrograde.engine.glapi : initRenderApi, setClearColor, compileShaderProgram, initFrame, loadEntityModel, unloadEntityModel,
    useRenderPassShaderProgram, drawModel, clearShaderProgram;

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
        useRenderPassShaderProgram(renderPass);

        //TODO: Optimize? Don't attempt each entity in each pass, but batch them.
        entityManager.forEachEntity((SharedPtr!Entity entity) {
            if (entity.ptr.hasComponent(RenderableComponentType) &&
            entity.ptr.hasComponent(renderPass.componentType)) {
                renderPass.render(entity, renderPass);
            }
        });

        clearShaderProgram();
    }
}

struct RenderPass {
    string passName;
    string vertexShader;
    string fragmentShader;
    StringId componentType;
    void delegate(SharedPtr!Entity entity, const ref RenderPass renderPass) render;

    uint program;
}

RenderPass genericModelRenderPass = RenderPass(
    "generic",
    import("opengles3/generic_model_vertex.glsl"),
    import("opengles3/generic_model_fragment.glsl"),
    ModelComponentType,
    (SharedPtr!Entity entity, const ref RenderPass renderPass) {
    drawModel(entity, renderPass);
}
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
        renderPasses.add(genericModelRenderPass);
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
