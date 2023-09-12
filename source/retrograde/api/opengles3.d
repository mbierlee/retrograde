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

module retrograde.api.opengles3;

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

void initRenderApi() {
    glDisable(GL_DITHER);
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
    // if (loadedModels.exists(model.name)) {
    //     //TODO: Attach a GlModelInfoComponent to this entity with the loaded model.
    //     //      Probably need to make loadedModels into a map
    //     return;
    // }

    auto modelInfo = makeShared!GlModelInfo;
    foreach (ref mesh; model.meshes) {
        Array!GLfloat positionData;
        Array!GLfloat colorData;
        foreach (vertex; mesh.vertices) {
            positionData.add(vertex.x);
            positionData.add(vertex.y);
            positionData.add(vertex.z);
            positionData.add(vertex.w);
            colorData.add(vertex.r);
            colorData.add(vertex.g);
            colorData.add(vertex.b);
            colorData.add(vertex.a);
        }

        auto vertexArrayObject = glCreateVertexArray();
        glBindVertexArray(vertexArrayObject);

        auto positionBufferObject = glCreateBuffer();
        glBindBuffer(GL_ARRAY_BUFFER, positionBufferObject);
        glBufferDataFloat(GL_ARRAY_BUFFER, positionData.arr, GL_STATIC_DRAW);
        glEnableVertexAttribArray(PositionAttribLocation);
        glVertexAttribPointer(PositionAttribLocation, 4, GL_FLOAT, false, 0, 0);

        auto colorBufferObject = glCreateBuffer();
        glBindBuffer(GL_ARRAY_BUFFER, colorBufferObject);
        glBufferDataFloat(GL_ARRAY_BUFFER, colorData.arr, GL_STATIC_DRAW);
        glEnableVertexAttribArray(ColorAttribLocation);
        glVertexAttribPointer(ColorAttribLocation, 4, GL_FLOAT, false, 0, 0);

        auto meshInfo = GlMeshInfo(
            positionBufferObject,
            colorBufferObject,
            vertexArrayObject,
            0,
            mesh.vertices.length,
            0
        );

        if (mesh.faces.length > 0) {
            GLuint elementBufferObject = glCreateBuffer();
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, elementBufferObject);
            Array!GLuint indexData;
            foreach (face; mesh.faces) {
                indexData.add(face.vA);
                indexData.add(face.vB);
                indexData.add(face.vC);
            }

            glBufferDataUInt(GL_ELEMENT_ARRAY_BUFFER, indexData.arr, GL_STATIC_DRAW);
            meshInfo.elementBufferObject = elementBufferObject;
            meshInfo.elementCount = indexData.length;
        }

        modelInfo.ptr.meshes.add(meshInfo);
    }

    auto glModelInfoComponent = Component(
        GlModelInfoComponentType,
        modelInfo.as!void
    );

    entity.addComponent(glModelInfoComponent);
    // loadedModels.add(model.name);

    glBindBuffer(GL_ARRAY_BUFFER, 0);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
    glBindVertexArray(0);
}

void unloadEntityModel(SharedPtr!Entity entity) {
    if (entity.ptr.hasComponent(GlModelInfoComponentType)) {
        auto modelInfo = entity.ptr.getComponent(GlModelInfoComponentType)
            .value.data.as!GlModelInfo;
        foreach (ref meshInfo; modelInfo.meshes) {
            glDeleteBuffer(meshInfo.positionBufferObject);
            glDeleteBuffer(meshInfo.colorBufferObject);
            glDeleteBuffer(meshInfo.elementBufferObject);
            glDeleteVertexArray(meshInfo.vertexArrayObject);
        }
    }

    // if (entity.ptr.hasComponent(ModelComponentType)) {
    //     auto model = entity.getComponent(ModelComponentType).value.data.as!Model;
    //     auto modelNameIndex = loadedModels.find(model.name);
    //     if (modelNameIndex != -1) {
    //         loadedModels.remove(modelNameIndex);
    //     }
    // }
}

void setClearColor(Color color) {
    clearColor = color;
}

void useRenderPassShaderProgram(const ref RenderPass renderPass) {
    glUseProgram(renderPass.program);
}

void clearShaderProgram() {
    glUseProgram(0);
}

void drawModel(SharedPtr!Entity entity, const ref RenderPass renderPass) {
    if (!entity.ptr.hasComponent(GlModelInfoComponentType)) {
        return;
    }

    auto modelInfo = entity.ptr.getComponent(GlModelInfoComponentType).value.data.as!GlModelInfo;
    foreach (ref meshInfo; modelInfo.ptr.meshes) {
        glBindVertexArray(meshInfo.vertexArrayObject);
        if (meshInfo.elementCount > 0) {
            glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, meshInfo.elementBufferObject);
            glDrawElements(GL_TRIANGLES, meshInfo.elementCount, GL_UNSIGNED_INT, 0);
        } else {
            glDrawArrays(GL_TRIANGLES, 0, meshInfo.vertexCount);
        }
    }

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
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
// private Array!StringId loadedModels;
private uint viewportWidth = 1;
private uint viewportHeight = 1;

private enum PositionAttribLocation = 0;
private enum ColorAttribLocation = 1;

private struct GlMeshInfo {
    GLuint positionBufferObject;
    GLuint colorBufferObject;
    GLuint vertexArrayObject;
    GLuint elementBufferObject;
    GLuint vertexCount;
    GLuint elementCount;
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
