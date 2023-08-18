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

module retrograde.wasm.glapi;

version (WebAssembly)  :  //
version (WebGl2)  :  //

import retrograde.engine.entity : Entity, Component;
import retrograde.engine.rendering : Color, RenderPass;

import retrograde.data.model : ModelComponentType, Model;

import retrograde.std.memory : SharedPtr, makeShared;
import retrograde.std.collections : Array;
import retrograde.std.stringid : StringId, sid;

alias GLuint = uint;
alias GLint = int;
alias GLfloat = float;
alias GLclampf = float; // Use clamp()
alias GLbool = bool;
alias GLsizei = int;
alias GLintptr = int;
alias GLenum = uint;
alias GLbitfield = uint;

enum GlConstant : GLenum {
    // Clearing buffers
    COLOR_BUFFER_BIT = 0x00004000,

    // Rendering primitives
    TRIANGLES = 0x0004,

    // Data types
    FLOAT = 0x1406,
}

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

GLclampf clamp(float val) {
    if (val < 0) {
        return 0;
    } else if (val > 1) {
        return 1;
    } else {
        return val;
    }
}

export extern (C) void setViewport(uint width, uint height) {
    viewportWidth = width;
    viewportHeight = height;
}

/// -----------------------
/// API standard functions.
/// Other public exports in this module are not part of the standard Retrograde GL api.

export extern (C) GLuint compileShaderProgram(string name, string vertexShader, string fragmentShader);

void initFrame() {
    resizeCanvasToDisplaySize();
    glClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
    glClear(GlConstant.COLOR_BUFFER_BIT);
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
        glVertexAttribPointer(PositionAttribLocation, 4, GlConstant.FLOAT, false, 0, 0);

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
        glDrawArrays(GlConstant.TRIANGLES, 0, meshInfo.vertexCount);
    }

    glUseProgram(0);
    glBindVertexArray(0);
}

/// ---------------------

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
