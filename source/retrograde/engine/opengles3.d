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

module retrograde.engine.opengles3;

version (OpenGLES3)  :  //

import retrograde.engine.entity : Entity, Component;
import retrograde.engine.rendering : Color, RenderPass;

import retrograde.data.model : ModelComponentType, Model;

import retrograde.std.memory : SharedPtr, makeShared;
import retrograde.std.collections : Array;
import retrograde.std.stringid : StringId, sid;

version (WebAssembly) {
    import retrograde.wasm.opengles3;

    public import retrograde.wasm.opengles3 : compileShaderProgram;
}

void initFrame() {
    resizeCanvasToDisplaySize();
    glClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
    glClear(GL_COLOR_BUFFER_BIT);
}

void loadEntityModel(SharedPtr!Entity entity) {
    if (entity.hasComponent(GlModelInfoComponentType)) {
        return;
    }

    auto maybeModelComponent = entity.getComponent(ModelComponentType);
    if (!maybeModelComponent.isDefined) {
        return;
    }

    auto modelComponent = maybeModelComponent.value;
    auto model = modelComponent.data.as!Model;
    if (loadedModels.exists(model.name)) {
        //TODO: Attach a GlModelInfoComponent to this entity with the loaded model.
        //      Probably need to make loadedModels into a map
        return;
    }

    auto modelInfo = makeShared!GlModelInfo;

    foreach (ref mesh; model.meshes) {
        auto vertexBufferObject = glCreateBuffer();
        glBindArrayBuffer(vertexBufferObject);

        Array!GLfloat vertexData;
        foreach (vertex; mesh.vertices) {
            vertexData.add(vertex.x);
            vertexData.add(vertex.y);
            vertexData.add(vertex.z);
            vertexData.add(vertex.w);
        }

        glArrayBufferData(vertexData.arr);
        auto vertexArrayObject = glCreateVertexArray();
        glBindVertexArray(vertexArrayObject);

        glEnableVertexAttribArray(PositionAttribLocation);
        glVertexAttribPointer(PositionAttribLocation, 4, GL_FLOAT, false, 0, 0);

        auto meshInfo = GlMeshInfo(
            vertexBufferObject,
            vertexArrayObject,
            mesh.vertices.length
        );

        modelInfo.ptr.meshes.add(meshInfo);
    }

    auto glModelInfoComponent = Component(
        GlModelInfoComponentType,
        modelInfo.as!void
    );

    entity.addComponent(glModelInfoComponent);
    loadedModels.add(model.name);

    glBindArrayBuffer(0);
    glBindVertexArray(0);
}

void unloadEntityModel(SharedPtr!Entity entity) {
    //TODO
    assert(false, "unloadEntityModel");

    //TODO: unload model from video mem
    //TODO: remove GlModelInfoComponent from entity
}

void setClearColor(Color color) {
    clearColor = color;
}

void drawModel(SharedPtr!Entity entity, const ref RenderPass renderPass) {
    if (!entity.ptr.hasComponent(GlModelInfoComponentType)) {
        return;
    }

    glUseProgram(renderPass.program);

    auto modelInfo = entity.ptr.getComponent(GlModelInfoComponentType).value.data.as!GlModelInfo;
    foreach (ref meshInfo; modelInfo.ptr.meshes) {
        glBindVertexArray(meshInfo.vertexArrayObject);
        glDrawArrays(GL_TRIANGLES, 0, meshInfo.vertexCount);
    }

    glUseProgram(0);
    glBindVertexArray(0);
}

void setViewport(uint width, uint height) {
    viewportWidth = width;
    viewportHeight = height;
}

GLclampf clamp(float val) {
    if (val < 0) {
        return 0;
    } else if (val > 1) {
        return 1;
    } else {
        return val;
    }
}

private enum GlModelInfoComponentType = sid("comp_gl_model_info");
private Color clearColor = Color(0, 0, 0, 0);
private Array!StringId loadedModels;
private uint viewportWidth = 1;
private uint viewportHeight = 1;

private enum PositionAttribLocation = 0;

private struct GlMeshInfo {
    GLuint vertexBufferObject;
    GLuint vertexArrayObject;
    GLuint vertexCount;
}

private struct GlModelInfo {
    Array!GlMeshInfo meshes;

    this(ref return scope inout typeof(this) other) {
        this.meshes = other.meshes;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        this.meshes = other.meshes;
    }
}
