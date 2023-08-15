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

import retrograde.engine.entity : Entity, Component;
import retrograde.engine.rendering : Color, RenderPass;

import retrograde.data.model : ModelComponentType, Model;

import retrograde.std.memory : SharedPtr, makeSharedVoid;
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
    Model* model = cast(Model*) modelComponent.data.ptr; //TODO: typecast as shared pointer instead. The share is lost here!
    if (loadedModels.exists(model.name)) {
        //TODO: Attach a GlModelInfoComponent to this entity with the loaded model.
        //      Probably need to make loadedModels into a map
        return;
    }

    auto vertextBufferObject = glCreateBuffer();
    glBindArrayBuffer(vertextBufferObject);

    Array!GLfloat vertexData;
    foreach (vertex; model.vertices) {
        vertexData.add(vertex.x);
        vertexData.add(vertex.y);
        vertexData.add(vertex.z);
        vertexData.add(vertex.w);
    }

    glArrayBufferData(vertexData.arr);
    auto vertextArrayObject = glCreateVertexArray();
    glBindVertexArray(vertextArrayObject);

    // TODO: Take attrib locations from global constants
    glEnableVertexAttribArray(0);
    glVertexAttribPointer(0, 4, GlConstant.FLOAT, false, 0, 0);

    auto glModelInfoData = makeSharedVoid(GlModelInfo(
            vertextBufferObject,
            vertextArrayObject
    ));

    auto glModelInfoComponent = Component(
        GlModelInfoComponentType,
        glModelInfoData
    );

    entity.addComponent(glModelInfoComponent);

    loadedModels.add(model.name);
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

    auto modelInfo = cast(GlModelInfo*) entity.ptr.getComponent(
        GlModelInfoComponentType).value.data.ptr; //TODO: cast sharedpointer
    glUseProgram(renderPass.program);
    glBindVertexArray(modelInfo.vertexArrayObject);
    glDrawArrays(GlConstant.TRIANGLES, 0, 3); //TODO: get count from modelInfo
}

/// ---------------------

private enum GlModelInfoComponentType = sid("comp_gl_model_info");
private Color clearColor = Color(0, 0, 0, 0);
private Array!StringId loadedModels;

private struct GlModelInfo {
    GLuint vertexBufferObject;
    GLuint vertexArrayObject;
    //TODO: Add GlMeshInfos 
}
