/**
 * Retrograde Engine
 *
 * This module implements an OpenGL ES 3 based render API.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.api.opengles3;

version (OpenGLES3)  :  //

import retrograde.engine.entity : EntityId, hasComponent, withComponentData, addComponent,
    getComponentData;
import retrograde.engine.rendering : Color, RenderPass, Viewport;

import retrograde.data.model : ModelComponentType, Model, maxUvChannels;

import retrograde.std.memory : makeRaw, unique;
import retrograde.std.collections : Array, HashMap;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.math : Matrix4, Vector3, Quaternion, toTranslationMatrix4, toScalingMatrix4;
import retrograde.std.geometry : PositionComponentType, OrientationComponentType, ScaleComponentType;
import retrograde.std.dlang : CopyConstructors;

version (WebAssembly) {
    import retrograde.wasm.opengles3;

    public import retrograde.wasm.opengles3 : compileShaderProgram;
}

void initRenderApi() {
    glDisable(GL_DITHER);

    glCullFace(GL_BACK);
    glEnable(GL_CULL_FACE);

    glDepthFunc(GL_LEQUAL);
    glEnable(GL_DEPTH_TEST);

    glStencilFunc(GL_EQUAL, 1, 0xFF);
    glEnable(GL_STENCIL_TEST);

    glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    glEnable(GL_BLEND);
}

void initRenderPass(ref RenderPass renderPass) {
    auto program = compileShaderProgram(
        renderPass.passName,
        renderPass.vertexShader,
        renderPass.fragmentShader
    );

    GlRenderPassInfo passInfo;
    passInfo.shaderProgram = program;
    passInfo.mvpMatrixUniformLocation = glGetUniformLocation(program, "modelViewProjectionMatrix");

    renderPassInfos.put(renderPass.passName.sid, passInfo);
}

void initFrame() {
    resizeCanvasToDisplaySize();
    glClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);
    glClear(GL_COLOR_BUFFER_BIT);
}

void loadEntityModel(EntityId entity) {
    if (entity.hasComponent(GlModelInfoComponentType)) {
        return;
    }

    entity.withComponentData(ModelComponentType, (Model* model) {
        // if (loadedModels.exists(model.name)) {
        //     //TODO: Attach a GlModelInfoComponent to this entity with the loaded model.
        //     //      Probably need to make loadedModels into a map
        //     return;
        // }

        auto modelInfo = makeRaw!GlModelInfo;
        foreach (ref mesh; model.meshes) {
            Array!GLfloat positionData;
            Array!GLfloat colorData;

            // Pre-allocate for efficiency
            positionData.capacity = mesh.vertices.length * 4;
            colorData.capacity = mesh.vertices.length * 4;

            foreach (ref vertex; mesh.vertices) {
                positionData.add(cast(GLfloat) vertex.x);
                positionData.add(cast(GLfloat) vertex.y);
                positionData.add(cast(GLfloat) vertex.z);
                positionData.add(cast(GLfloat) vertex.w);
                colorData.add(cast(GLfloat) vertex.r);
                colorData.add(cast(GLfloat) vertex.g);
                colorData.add(cast(GLfloat) vertex.b);
                colorData.add(cast(GLfloat) vertex.a);
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

            GlMeshInfo meshInfo;
            meshInfo.positionBufferObject = positionBufferObject;
            meshInfo.colorBufferObject = colorBufferObject;
            meshInfo.vertexArrayObject = vertexArrayObject;
            meshInfo.elementBufferObject = 0;
            meshInfo.vertexCount = mesh.vertices.length;
            meshInfo.elementCount = 0;
            meshInfo.uvChannelCount = mesh.uvChannelCount;

            for (ubyte c = 0; c < mesh.uvChannelCount; c++) {
                Array!GLfloat uvData;
                uvData.capacity = mesh.vertices.length * 2;
                size_t channelStart = cast(size_t) c * mesh.vertices.length;
                for (size_t i = 0; i < mesh.vertices.length; i++) {
                    auto coord = mesh.uvCoords[channelStart + i];
                    uvData.add(cast(GLfloat) coord.u);
                    uvData.add(cast(GLfloat) coord.v);
                }

                auto uvBufferObject = glCreateBuffer();
                glBindBuffer(GL_ARRAY_BUFFER, uvBufferObject);
                glBufferDataFloat(GL_ARRAY_BUFFER, uvData.arr, GL_STATIC_DRAW);
                glEnableVertexAttribArray(UvAttribLocationBase + c);
                glVertexAttribPointer(UvAttribLocationBase + c, 2, GL_FLOAT, false, 0, 0);

                meshInfo.uvBufferObjects[c] = uvBufferObject;
            }

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

            modelInfo.meshes.add(meshInfo);
        }

        entity.addComponent(GlModelInfoComponentType, modelInfo.unique());
        // loadedModels.add(model.name);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, 0);
        glBindVertexArray(0);
    });
}

void unloadEntityModel(EntityId entity) {
    entity.withComponentData(GlModelInfoComponentType, (GlModelInfo* modelInfo) {
        foreach (ref meshInfo; modelInfo.meshes) {
            glDeleteBuffer(meshInfo.positionBufferObject);
            glDeleteBuffer(meshInfo.colorBufferObject);
            glDeleteBuffer(meshInfo.elementBufferObject);
            for (ubyte c = 0; c < meshInfo.uvChannelCount; c++) {
                glDeleteBuffer(meshInfo.uvBufferObjects[c]);
            }

            glDeleteVertexArray(meshInfo.vertexArrayObject);
        }
    });

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

void useRenderPassShaderProgram(ref RenderPass renderPass) {
    auto passInfo = renderPassInfos.get(renderPass.passName.sid);
    if (passInfo.isDefined) {
        glUseProgram(passInfo.value.shaderProgram);
    }
}

void clearShaderProgram() {
    glUseProgram(0);
}

void drawModel(EntityId entity, const ref RenderPass renderPass, const ref Matrix4 viewProjectionMatrix) {
    entity.withComponentData(GlModelInfoComponentType, (GlModelInfo* modelInfo) {
        Vector3 position;
        Quaternion orientation;
        Vector3 scale = 1;

        auto maybePosition = entity.getComponentData!Vector3(PositionComponentType);
        if (maybePosition.isDefined()) {
            position = *maybePosition.value;
        }

        auto maybeOrientation = entity.getComponentData!Quaternion(OrientationComponentType);
        if (maybeOrientation.isDefined()) {
            orientation = *maybeOrientation.value;
        }

        auto maybeScale = entity.getComponentData!Vector3(ScaleComponentType);
        if (maybeScale.isDefined()) {
            scale = *maybeScale.value;
        }

        auto modelMatrix = position.toTranslationMatrix4() * orientation.toRotationMatrix() * scale.toScalingMatrix4();
        auto modelViewProjectionMatrix = viewProjectionMatrix * modelMatrix;

        auto passInfo = renderPassInfos.get(renderPass.passName.sid);
        if (passInfo.isDefined) {
            auto mvpMatrixUniformLocation = passInfo.value.mvpMatrixUniformLocation;
            if (mvpMatrixUniformLocation >= 0) {
                auto modelViewProjectionMatrixData = modelViewProjectionMatrix.getDataArray!float;
                glUniformMatrix4fv(mvpMatrixUniformLocation, 1, true, modelViewProjectionMatrixData);
            }
        }

        foreach (ref meshInfo; modelInfo.meshes) {
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
    });
}

void setViewport(uint width, uint height) {
    viewportWidth = width;
    viewportHeight = height;
}

Viewport getViewport() {
    return Viewport(0, 0, viewportWidth, viewportHeight);
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
private HashMap!(StringId, GlRenderPassInfo) renderPassInfos;

private enum PositionAttribLocation = 0;
private enum ColorAttribLocation = 1;
private enum UvAttribLocationBase = 2;

private struct GlMeshInfo {
    GLuint positionBufferObject;
    GLuint colorBufferObject;
    GLuint vertexArrayObject;
    GLuint elementBufferObject;
    GLuint vertexCount;
    GLuint elementCount;
    GLuint[maxUvChannels] uvBufferObjects;
    ubyte uvChannelCount;
}

private struct GlModelInfo {
    Array!GlMeshInfo meshes;

    mixin CopyConstructors!GlModelInfo;
}

private struct GlRenderPassInfo {
    GLuint shaderProgram;
    GLint mvpMatrixUniformLocation;
}
