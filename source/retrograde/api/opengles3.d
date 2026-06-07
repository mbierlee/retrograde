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
import retrograde.engine.rendering : Color, RenderPass, Viewport, renderPasses, MaterialShader;

import retrograde.assets.model : ModelComponentType, Model, MaterialType, MaterialIndex, noMaterial;

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
    passInfo.positionAttribLocation = glGetAttribLocation(program, "position");

    renderPassInfos.put(renderPass.passName.sid, passInfo);
}

void initMaterialShader(ref MaterialShader materialShader) {
    auto program = compileShaderProgram(
        materialShader.materialName,
        materialShader.vertexShader,
        materialShader.fragmentShader
    );

    GlMaterialShaderInfo shaderInfo;
    shaderInfo.shaderProgram = program;
    shaderInfo.mvpMatrixUniformLocation = glGetUniformLocation(program, "modelViewProjectionMatrix");
    shaderInfo.positionAttribLocation = glGetAttribLocation(program, "position");

    if (materialShader.materialType == MaterialType.vertexColors) {
        shaderInfo.colorsAttribLocation = glGetAttribLocation(program, "color");
    }

    materialShaderInfos.put(materialShader.materialType, shaderInfo);
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

            // Pre-allocate for efficiency
            positionData.capacity = mesh.vertices.length * 4;

            foreach (ref vertex; mesh.vertices) {
                positionData.add(cast(GLfloat) vertex.x);
                positionData.add(cast(GLfloat) vertex.y);
                positionData.add(cast(GLfloat) vertex.z);
                positionData.add(cast(GLfloat) vertex.w);
            }

            auto positionBufferObject = glCreateBuffer();
            glBindBuffer(GL_ARRAY_BUFFER, positionBufferObject);
            glBufferDataFloat(GL_ARRAY_BUFFER, positionData.arr, GL_STATIC_DRAW);

            GlMeshInfo meshInfo;
            meshInfo.positionBufferObject = positionBufferObject;
            meshInfo.elementBufferObject = 0;
            meshInfo.vertexCount = mesh.vertices.length;
            meshInfo.elementCount = 0;

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

            foreach (ref renderPass; renderPasses) {
                if (!entity.hasComponent(renderPass.componentType)) {
                    continue;
                }

                auto passSid = renderPass.passName.sid;
                auto maybePassInfo = renderPassInfos.get(passSid);
                if (!maybePassInfo.isDefined) {
                    continue;
                }

                auto passInfo = maybePassInfo.value;
                auto vertexArrayObject = glCreateVertexArray();
                glBindVertexArray(vertexArrayObject);

                glBindBuffer(GL_ARRAY_BUFFER, positionBufferObject);
                if (passInfo.positionAttribLocation >= 0) {
                    glEnableVertexAttribArray(passInfo.positionAttribLocation);
                    glVertexAttribPointer(passInfo.positionAttribLocation, 4, GL_FLOAT, false, 0, 0);
                }

                if (meshInfo.elementBufferObject != 0) {
                    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, meshInfo.elementBufferObject);
                }

                meshInfo.vertexArrayObjects.put(passSid, vertexArrayObject);
            }

            meshInfo.materialIndex = mesh.materialIndex;
            if (mesh.materialIndex != noMaterial) {
                foreach (ref material; model.materials) {
                    if (material.index == mesh.materialIndex) {
                        meshInfo.materialType = material.type;
                        meshInfo.doubleSided = material.doubleSided;
                        break;
                    }
                }
            }

            if (mesh.materialIndex != noMaterial && meshInfo.materialType != MaterialType.invalid) {
                auto maybeMaterialShaderInfo = materialShaderInfos.get(meshInfo.materialType);
                if (maybeMaterialShaderInfo.isDefined) {
                    auto materialShaderInfo = maybeMaterialShaderInfo.value;

                    if (meshInfo.materialType == MaterialType.vertexColors) {
                        Array!GLfloat colorData;
                        colorData.capacity = mesh.vertices.length * 4;
                        foreach (ref vertex; mesh.vertices) {
                            colorData.add(cast(GLfloat) vertex.r);
                            colorData.add(cast(GLfloat) vertex.g);
                            colorData.add(cast(GLfloat) vertex.b);
                            colorData.add(cast(GLfloat) vertex.a);
                        }

                        meshInfo.colorBufferObject = glCreateBuffer();
                        glBindBuffer(GL_ARRAY_BUFFER, meshInfo.colorBufferObject);
                        glBufferDataFloat(GL_ARRAY_BUFFER, colorData.arr, GL_STATIC_DRAW);
                    }

                    auto materialVao = glCreateVertexArray();
                    glBindVertexArray(materialVao);

                    glBindBuffer(GL_ARRAY_BUFFER, positionBufferObject);
                    if (materialShaderInfo.positionAttribLocation >= 0) {
                        glEnableVertexAttribArray(materialShaderInfo.positionAttribLocation);
                        glVertexAttribPointer(materialShaderInfo.positionAttribLocation, 4, GL_FLOAT, false, 0, 0);
                    }

                    if (meshInfo.materialType == MaterialType.vertexColors
                    && meshInfo.colorBufferObject != 0
                    && materialShaderInfo.colorsAttribLocation >= 0) {
                        glBindBuffer(GL_ARRAY_BUFFER, meshInfo.colorBufferObject);
                        glEnableVertexAttribArray(materialShaderInfo.colorsAttribLocation);
                        glVertexAttribPointer(materialShaderInfo.colorsAttribLocation, 4, GL_FLOAT, false, 0, 0);
                    }

                    if (meshInfo.elementBufferObject != 0) {
                        glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, meshInfo.elementBufferObject);
                    }

                    meshInfo.materialVertexArrayObject = materialVao;
                }
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
            foreach (ref GLuint vao; meshInfo.vertexArrayObjects) {
                glDeleteVertexArray(vao);
            }

            glDeleteVertexArray(meshInfo.materialVertexArrayObject);
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
        auto modelViewProjectionMatrixData = modelViewProjectionMatrix.getDataArray!float;

        auto passSid = renderPass.passName.sid;
        auto maybePassInfo = renderPassInfos.get(passSid);

        foreach (ref meshInfo; modelInfo.meshes) {
            GLuint shaderProgram;
            GLint mvpMatrixUniformLocation = -1;
            GLuint vao = 0;
            auto useMaterial = false;

            if (meshInfo.materialIndex != noMaterial
                && meshInfo.materialType != MaterialType.invalid
                && meshInfo.materialVertexArrayObject != 0) {
                auto maybeMaterialShaderInfo = materialShaderInfos.get(meshInfo.materialType);
                if (maybeMaterialShaderInfo.isDefined) {
                    auto materialShaderInfo = maybeMaterialShaderInfo.value;
                    shaderProgram = materialShaderInfo.shaderProgram;
                    mvpMatrixUniformLocation = materialShaderInfo.mvpMatrixUniformLocation;
                    vao = meshInfo.materialVertexArrayObject;
                    useMaterial = true;
                }
            }

            if (!useMaterial) {
                if (!maybePassInfo.isDefined) {
                    continue;
                }

                auto maybeVao = meshInfo.vertexArrayObjects.get(passSid);
                if (!maybeVao.isDefined) {
                    continue;
                }

                shaderProgram = maybePassInfo.value.shaderProgram;
                mvpMatrixUniformLocation = maybePassInfo.value.mvpMatrixUniformLocation;
                vao = maybeVao.value;
            }

            glUseProgram(shaderProgram);
            if (mvpMatrixUniformLocation >= 0) {
                glUniformMatrix4fv(mvpMatrixUniformLocation, 1, true, modelViewProjectionMatrixData);
            }

            if (meshInfo.doubleSided) {
                glDisable(GL_CULL_FACE);
            }

            glBindVertexArray(vao);
            if (meshInfo.elementCount > 0) {
                glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, meshInfo.elementBufferObject);
                glDrawElements(GL_TRIANGLES, meshInfo.elementCount, GL_UNSIGNED_INT, 0);
            } else {
                glDrawArrays(GL_TRIANGLES, 0, meshInfo.vertexCount);
            }

            if (meshInfo.doubleSided) {
                glEnable(GL_CULL_FACE);
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
private HashMap!(MaterialType, GlMaterialShaderInfo) materialShaderInfos;

private struct GlMeshInfo {
    GLuint positionBufferObject;
    GLuint colorBufferObject;
    HashMap!(StringId, GLuint) vertexArrayObjects;
    GLuint materialVertexArrayObject;
    GLuint elementBufferObject;
    GLuint vertexCount;
    GLuint elementCount;
    MaterialIndex materialIndex = noMaterial;
    MaterialType materialType;

    /// Common material property: when true this mesh renders both faces (back-face culling disabled).
    bool doubleSided;

    mixin CopyConstructors!GlMeshInfo;
}

private struct GlModelInfo {
    Array!GlMeshInfo meshes;

    mixin CopyConstructors!GlModelInfo;
}

private struct GlRenderPassInfo {
    GLuint shaderProgram;
    GLint mvpMatrixUniformLocation;
    GLint positionAttribLocation;
}

private struct GlMaterialShaderInfo {
    GLuint shaderProgram;
    GLint mvpMatrixUniformLocation;
    GLint positionAttribLocation;
    GLint colorsAttribLocation;
}
