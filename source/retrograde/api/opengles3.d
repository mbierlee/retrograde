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

import retrograde.engine.entity : EntityId, hasComponent, withComponentData, addComponent;
import retrograde.engine.geometry : worldTransformOf;
import retrograde.engine.rendering : activeCameraFrustum, activeCameraWorldPosition, Color,
    frustumCullingEnabled, LightType, RenderPass, RenderView, Viewport, renderPasses, MaterialShader;
import retrograde.engine.rendering.lighting : ActiveLight, ambientGroundColor, ambientIntensity,
    ambientSkyColor, selectActiveLights;
import retrograde.engine.rendering.materialshader : maxLights, maxShadowViews;
import retrograde.engine.rendering.shadow : shadowBiasMatrix, shadowSettings, shadowViews;

import retrograde.assets.model : ModelComponentType, Model, MaterialType, MaterialIndex, noMaterial,
    hasEmissive, hasMetallicRoughness, hasOcclusion, isLit, referencesTexture,
    referencesNormalTexture, BaseColorFactor, EmissiveFactor, TextureIndex, Texture,
    TextureMagFilter, TextureMinFilter, TextureWrap;
import retrograde.assets.image : Image, ChannelFormat;
import retrograde.assets.assetlibrary : getModel, getTexture;

import retrograde.std.memory : makeRaw, unique;
import retrograde.std.collections : Array, HashMap;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.geometry : Aabb;
import retrograde.std.math : Matrix4, Vector3, toNormalMatrix;
import retrograde.std.assets : AssetHandle;
import retrograde.std.dlang : CopyConstructors;
import retrograde.std.stdio : writeErrLn;

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

    createDefaultAlbedoTexture();
}

/**
 * Creates the 1x1 opaque white texture stood in for a material that has no albedo texture of
 * its own, or whose texture failed to load.
 *
 * Sampling white leaves the shader's `texture(albedoTexture, ...) * baseColorFactor` equal to
 * the factor, so an untextured material is drawn by the same program, with the same uniforms,
 * as a textured one - no "has texture" branch in any fragment shader and no second variant to
 * compile. Filters are nearest and wrapping is clamped because there is nothing to interpolate
 * or tile across a single texel.
 */
private void createDefaultAlbedoTexture() {
    static immutable ubyte[4] whitePixel = [255, 255, 255, 255];

    defaultAlbedoTextureObject = glCreateTexture();
    glBindTexture(GL_TEXTURE_2D, defaultAlbedoTextureObject);
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, 1, 1, 0, GL_RGBA, GL_UNSIGNED_BYTE, whitePixel[]);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_NEAREST);
    glBindTexture(GL_TEXTURE_2D, 0);
}

static if (maxShadowViews > 0) {
    /**
     * Creates the shadow maps and the framebuffer they are rendered through.
     *
     * The maps are one array texture with a layer per view, rather than a texture per light:
     * a shader cannot index an array of samplers with a loop variable, so a per-light sampler
     * could not be reached from the shading loop, while a layer of one array can.
     *
     * Params:
     *  enabled = whether any registered pass renders shadow maps. When nothing does, a 1x1x1
     *            array stands in for the real thing: the lit shaders sample unit 5 whatever
     *            happens, and an unbound or incomplete texture there is an error on every
     *            draw, while a complete one that nothing wrote reads as "not in shadow". It
     *            is the same trick as the default albedo texture, and it keeps a game that
     *            never asked for shadows from paying for the maps.
     */
    void initShadowMaps(bool enabled) {
        shadowMapsEnabled = enabled;
        allocateShadowMaps(enabled ? shadowSettings.mapSize : 1);

        if (!enabled) {
            return;
        }

        shadowFramebuffer = glCreateFramebuffer();
        glBindFramebuffer(GL_FRAMEBUFFER, shadowFramebuffer);
        glFramebufferTextureLayer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, shadowMapArray, 0, 0);

        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            writeErrLn("Shadow map framebuffer is incomplete; shadows will not render.");
        }

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    /**
     * Rebuilds the shadow maps at the given size, replacing whatever was there.
     *
     * A texture's allocation cannot be resized, so changing the map size means a new texture
     * object rather than a new allocation on the old one.
     */
    private void allocateShadowMaps(uint size) {
        if (shadowMapArray != 0) {
            glDeleteTexture(shadowMapArray);
        }

        GLsizei layers = shadowMapsEnabled ? maxShadowViews : 1;
        allocatedShadowMapSize = size > 0 ? size : 1;

        shadowMapArray = glCreateTexture();

        // Left bound on its own unit for the rest of the run: nothing else uses unit 5, and
        // the pass that renders into the maps has no samplers of its own, so rendering into a
        // layer while it is bound is not the feedback loop it would be for a lit draw.
        glActiveTexture(GL_TEXTURE5);
        glBindTexture(GL_TEXTURE_2D_ARRAY, shadowMapArray);
        glTexStorage3D(GL_TEXTURE_2D_ARRAY, 1, GL_DEPTH_COMPONENT24,
            allocatedShadowMapSize, allocatedShadowMapSize, layers);

        // Comparison rather than plain sampling: the shader passes the depth it wants tested
        // and gets back how much of the neighbourhood it beat, so the hardware's filtering
        // softens the shadow's edge instead of averaging depths, which would mean nothing.
        // A linear filter on a depth texture without this is incomplete and samples zero.
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_COMPARE_MODE, GL_COMPARE_REF_TO_TEXTURE);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_COMPARE_FUNC, GL_LEQUAL);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

        // Clamped so that a surface past the edge of a map repeats its border rather than
        // wrapping to the far side of the light's view, which would shadow it with something
        // nowhere near it.
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
        glTexParameteri(GL_TEXTURE_2D_ARRAY, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);

        glActiveTexture(GL_TEXTURE0);
    }

    /// Rebuilds the maps when the size they should be has changed since they were made.
    void syncShadowMapSize() {
        if (!shadowMapsEnabled) {
            return;
        }

        uint wantedSize = shadowSettings.mapSize > 0 ? shadowSettings.mapSize : 1;
        if (wantedSize == allocatedShadowMapSize) {
            return;
        }

        allocateShadowMaps(wantedSize);

        glBindFramebuffer(GL_FRAMEBUFFER, shadowFramebuffer);
        glFramebufferTextureLayer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, shadowMapArray, 0, 0);
        if (glCheckFramebufferStatus(GL_FRAMEBUFFER) != GL_FRAMEBUFFER_COMPLETE) {
            writeErrLn("Shadow map framebuffer is incomplete after a resize; shadows will not render.");
        }

        glBindFramebuffer(GL_FRAMEBUFFER, 0);
    }

    /// Makes the given view's shadow map the target, and clears what the last frame left in it.
    void beginShadowView(const ref RenderView view) {
        if (!shadowMapsEnabled) {
            return;
        }

        glBindFramebuffer(GL_FRAMEBUFFER, shadowFramebuffer);
        glFramebufferTextureLayer(GL_FRAMEBUFFER, GL_DEPTH_ATTACHMENT, shadowMapArray, 0,
            cast(GLint) view.targetLayer);
        glViewport(0, 0, allocatedShadowMapSize, allocatedShadowMapSize);
        glClear(GL_DEPTH_BUFFER_BIT);

        // Pushes what is drawn a little further from the light, so that a surface's own depth
        // does not come back nearer than itself and stripe it with its own shadow. Scaled by
        // how steeply the surface is turned away, which is where the error is worst.
        glEnable(GL_POLYGON_OFFSET_FILL);
        glPolygonOffset(cast(GLfloat) shadowSettings.slopeBias, cast(GLfloat) shadowSettings.constantBias);
    }

    /**
     * Puts the screen back as the target and hands the frame's maps to the lit shaders.
     *
     * The views are per frame rather than per entity, so they go up once for each program
     * that reads them instead of with every draw.
     */
    void endShadowPass() {
        if (!shadowMapsEnabled) {
            return;
        }

        glDisable(GL_POLYGON_OFFSET_FILL);
        glPolygonOffset(0, 0);
        glBindFramebuffer(GL_FRAMEBUFFER, 0);
        glViewport(0, 0, viewportWidth, viewportHeight);

        shadowViewProjectionData.truncate(0);
        foreach (i; 0 .. shadowViews.length) {
            // Clip space reaches [-1, 1] while a map is sampled over [0, 1], so the
            // conversion is folded in here rather than done per light per fragment.
            auto biased = shadowBiasMatrix * shadowViews[i].viewProjectionMatrix;
            auto data = biased.getDataArray!GLfloat;
            foreach (j; 0 .. 16) {
                shadowViewProjectionData.add(data[j]);
            }
        }

        if (shadowViewProjectionData.length == 0) {
            return;
        }

        GLsizei viewCount = cast(GLsizei) shadowViews.length;
        foreach (ref shaderInfo; materialShaderInfos.values) {
            if (shaderInfo.shadowViewProjectionUniformLocation < 0) {
                continue;
            }

            glUseProgram(shaderInfo.shaderProgram);
            glUniformMatrix4fv(shaderInfo.shadowViewProjectionUniformLocation, viewCount, true,
                shadowViewProjectionData.arr);

            if (shaderInfo.shadowNormalBiasUniformLocation >= 0) {
                glUniform1f(shaderInfo.shadowNormalBiasUniformLocation,
                    cast(GLfloat) shadowSettings.normalBias);
            }
        }

        glUseProgram(0);
    }
} else {
    // Shadows are compiled out of this build, so these do nothing at all. They still exist
    // because the renderer calls them without asking what the budget is: which passes a game
    // registers is a question about the game, not about how the engine was compiled.
    void initShadowMaps(bool enabled) {
    }

    void syncShadowMapSize() {
    }

    void beginShadowView(const ref RenderView view) {
    }

    void endShadowPass() {
    }
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

    if (materialShader.materialType.referencesTexture) {
        shaderInfo.textureCoordsAttribLocation = glGetAttribLocation(program, "textureCoords");
        shaderInfo.albedoTextureUniformLocation = glGetUniformLocation(program, "albedoTexture");
        shaderInfo.baseColorFactorUniformLocation = glGetUniformLocation(program, "baseColorFactor");
    }

    if (materialShader.materialType.referencesNormalTexture) {
        shaderInfo.tangentAttribLocation = glGetAttribLocation(program, "tangent");
        shaderInfo.normalTextureUniformLocation = glGetUniformLocation(program, "normalTexture");
        shaderInfo.hasNormalMapUniformLocation = glGetUniformLocation(program, "hasNormalMap");
        shaderInfo.normalTextureScaleUniformLocation = glGetUniformLocation(program,
            "normalTextureScale");
    }

    if (materialShader.materialType.hasMetallicRoughness) {
        shaderInfo.metallicRoughnessTextureUniformLocation = glGetUniformLocation(program,
            "metallicRoughnessTexture");
        shaderInfo.hasMetallicRoughnessMapUniformLocation = glGetUniformLocation(program,
            "hasMetallicRoughnessMap");
        shaderInfo.metallicFactorUniformLocation = glGetUniformLocation(program, "metallicFactor");
        shaderInfo.roughnessFactorUniformLocation = glGetUniformLocation(program,
            "roughnessFactor");
        shaderInfo.cameraWorldPositionUniformLocation = glGetUniformLocation(program,
            "cameraWorldPosition");
    }

    if (materialShader.materialType.hasOcclusion) {
        shaderInfo.occlusionTextureUniformLocation = glGetUniformLocation(program,
            "occlusionTexture");
        shaderInfo.hasOcclusionMapUniformLocation = glGetUniformLocation(program,
            "hasOcclusionMap");
        shaderInfo.occlusionStrengthUniformLocation = glGetUniformLocation(program,
            "occlusionStrength");
    }

    if (materialShader.materialType.hasEmissive) {
        shaderInfo.emissiveTextureUniformLocation = glGetUniformLocation(program,
            "emissiveTexture");
        shaderInfo.hasEmissiveMapUniformLocation = glGetUniformLocation(program,
            "hasEmissiveMap");
        shaderInfo.emissiveFactorUniformLocation = glGetUniformLocation(program,
            "emissiveFactor");
        shaderInfo.emissiveStrengthUniformLocation = glGetUniformLocation(program,
            "emissiveStrength");
    }

    if (materialShader.materialType.isLit) {
        shaderInfo.normalAttribLocation = glGetAttribLocation(program, "normal");
        shaderInfo.modelMatrixUniformLocation = glGetUniformLocation(program, "modelMatrix");
        shaderInfo.normalMatrixUniformLocation = glGetUniformLocation(program, "normalMatrix");
        shaderInfo.ambientSkyRadianceUniformLocation = glGetUniformLocation(program, "ambientSkyRadiance");
        shaderInfo.ambientGroundRadianceUniformLocation = glGetUniformLocation(program, "ambientGroundRadiance");

        static if (maxLights > 0) {
            shaderInfo.lightCountUniformLocation = glGetUniformLocation(program, "lightCount");
            shaderInfo.lightPositionRadiusUniformLocation = glGetUniformLocation(program, "lightPositionRadius[0]");
            shaderInfo.lightColorIntensityUniformLocation = glGetUniformLocation(program, "lightColorIntensity[0]");
            shaderInfo.lightDirectionUniformLocation = glGetUniformLocation(program, "lightDirection[0]");
        }

        static if (maxShadowViews > 0) {
            shaderInfo.shadowMapsUniformLocation = glGetUniformLocation(program, "shadowMaps");
            shaderInfo.shadowViewProjectionUniformLocation = glGetUniformLocation(program,
                "shadowViewProjection[0]");
            shaderInfo.lightShadowParamsUniformLocation = glGetUniformLocation(program,
                "lightShadowParams[0]");
            shaderInfo.shadowNormalBiasUniformLocation = glGetUniformLocation(program,
                "shadowNormalBias");

            // The maps live on their own unit for the whole run, so which unit that is only
            // has to be said once rather than with every draw.
            if (shaderInfo.shadowMapsUniformLocation >= 0) {
                glUseProgram(program);
                glUniform1i(shaderInfo.shadowMapsUniformLocation, 5);
                glUseProgram(0);
            }
        }
    }

    materialShaderInfos.put(materialShader.materialType, shaderInfo);
}

void initFrame() {
    resizeCanvasToDisplaySize();
    glClearColor(clearColor.r, clearColor.g, clearColor.b, clearColor.a);

    // Depth as well as color: the browser happens to clear the screen's depth buffer between
    // frames of its own accord, but nothing says it must, and relying on that would leave the
    // frame's first draw testing against whatever the last one left.
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
}

void loadEntityModel(EntityId entity) {
    if (entity.hasComponent(GlModelInfoComponentType)) {
        return;
    }

    entity.withComponentData(ModelComponentType, (AssetHandle* modelHandle) {
        auto modelResult = getModel(*modelHandle);
        if (modelResult.isFailure) {
            return;
        }

        auto modelRef = modelResult.value;
        Model* model = modelRef.ptr;

        // if (loadedModels.exists(model.name)) {
        //     //TODO: Attach a GlModelInfoComponent to this entity with the loaded model.
        //     //      Probably need to make loadedModels into a map
        //     return;
        // }

        auto modelInfo = makeRaw!GlModelInfo;
        modelInfo.bounds = model.bounds;
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
            TextureIndex materialTextureIndex = 0;
            TextureIndex materialNormalTextureIndex = 0;
            TextureIndex materialMetallicRoughnessTextureIndex = 0;
            TextureIndex materialOcclusionTextureIndex = 0;
            TextureIndex materialEmissiveTextureIndex = 0;
            if (mesh.materialIndex != noMaterial) {
                foreach (ref material; model.materials) {
                    if (material.index == mesh.materialIndex) {
                        meshInfo.materialType = material.type;
                        meshInfo.doubleSided = material.doubleSided;
                        materialTextureIndex = material.textureIndex;
                        materialNormalTextureIndex = material.normalTextureIndex;
                        materialMetallicRoughnessTextureIndex = material
                            .metallicRoughnessTextureIndex;
                        meshInfo.normalTextureScale = cast(GLfloat) material.normalTextureScale;
                        meshInfo.baseColorFactor = material.baseColorFactor;
                        meshInfo.metallicFactor = cast(GLfloat) material.metallicFactor;
                        meshInfo.roughnessFactor = cast(GLfloat) material.roughnessFactor;
                        materialOcclusionTextureIndex = material.occlusionTextureIndex;
                        meshInfo.occlusionStrength = cast(GLfloat) material.occlusionStrength;
                        materialEmissiveTextureIndex = material.emissiveTextureIndex;
                        meshInfo.emissiveFactor = material.emissiveFactor;
                        meshInfo.emissiveStrength = cast(GLfloat) material.emissiveStrength;
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

                    if (meshInfo.materialType.isLit && mesh.normals.length > 0) {
                        Array!GLfloat normalData;
                        normalData.capacity = mesh.vertices.length * 3;
                        foreach (i; 0 .. mesh.vertices.length) {
                            auto normal = mesh.normals[i];
                            normalData.add(cast(GLfloat) normal.x);
                            normalData.add(cast(GLfloat) normal.y);
                            normalData.add(cast(GLfloat) normal.z);
                        }

                        meshInfo.normalBufferObject = glCreateBuffer();
                        glBindBuffer(GL_ARRAY_BUFFER, meshInfo.normalBufferObject);
                        glBufferDataFloat(GL_ARRAY_BUFFER, normalData.arr, GL_STATIC_DRAW);
                    }

                    if (meshInfo.materialType.referencesTexture && mesh.uvChannelCount > 0) {
                        Array!GLfloat textureCoordsData;
                        textureCoordsData.capacity = mesh.vertices.length * 2;
                        foreach (i; 0 .. mesh.vertices.length) {
                            auto uv = mesh.uvCoords[i];
                            textureCoordsData.add(cast(GLfloat) uv.u);
                            textureCoordsData.add(cast(GLfloat) uv.v);
                        }

                        meshInfo.textureCoordsBufferObject = glCreateBuffer();
                        glBindBuffer(GL_ARRAY_BUFFER, meshInfo.textureCoordsBufferObject);
                        glBufferDataFloat(GL_ARRAY_BUFFER, textureCoordsData.arr, GL_STATIC_DRAW);

                        meshInfo.textureObject = createMaterialTexture(model, materialTextureIndex);
                    }

                    if (meshInfo.materialType.referencesNormalTexture
                    && materialNormalTextureIndex != 0
                    && mesh.uvChannelCount > 0) {
                        if (mesh.tangents.length == 0) {
                            writeErrLn("Material of model ", model.name,
                                " references a normal map but its mesh carries no tangents; ",
                                "skipping normal map.");
                        } else {
                            Array!GLfloat tangentData;
                            tangentData.capacity = mesh.vertices.length * 4;
                            foreach (i; 0 .. mesh.vertices.length) {
                                auto tangent = mesh.tangents[i];
                                tangentData.add(cast(GLfloat) tangent.x);
                                tangentData.add(cast(GLfloat) tangent.y);
                                tangentData.add(cast(GLfloat) tangent.z);
                                tangentData.add(cast(GLfloat) tangent.w);
                            }

                            meshInfo.tangentBufferObject = glCreateBuffer();
                            glBindBuffer(GL_ARRAY_BUFFER, meshInfo.tangentBufferObject);
                            glBufferDataFloat(GL_ARRAY_BUFFER, tangentData.arr, GL_STATIC_DRAW);

                            meshInfo.normalTextureObject = createMaterialTexture(model,
                                materialNormalTextureIndex);
                        }
                    }

                    if (meshInfo.materialType.hasMetallicRoughness
                    && materialMetallicRoughnessTextureIndex != 0
                    && mesh.uvChannelCount > 0) {
                        meshInfo.metallicRoughnessTextureObject = createMaterialTexture(model,
                            materialMetallicRoughnessTextureIndex);
                    }

                    if (meshInfo.materialType.hasOcclusion
                    && materialOcclusionTextureIndex != 0
                    && mesh.uvChannelCount > 0) {
                        if (materialOcclusionTextureIndex == materialMetallicRoughnessTextureIndex
                        && meshInfo.metallicRoughnessTextureObject != 0) {
                            meshInfo.occlusionTextureObject = meshInfo
                                .metallicRoughnessTextureObject;
                            meshInfo.occlusionTextureIsShared = true;
                        } else {
                            meshInfo.occlusionTextureObject = createMaterialTexture(model,
                                materialOcclusionTextureIndex);
                        }
                    }

                    if (meshInfo.materialType.hasEmissive
                    && materialEmissiveTextureIndex != 0
                    && mesh.uvChannelCount > 0) {
                        meshInfo.emissiveTextureObject = createMaterialTexture(model,
                            materialEmissiveTextureIndex);
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

                    if (meshInfo.materialType.referencesTexture
                    && meshInfo.textureCoordsBufferObject != 0
                    && materialShaderInfo.textureCoordsAttribLocation >= 0) {
                        glBindBuffer(GL_ARRAY_BUFFER, meshInfo.textureCoordsBufferObject);
                        glEnableVertexAttribArray(materialShaderInfo.textureCoordsAttribLocation);
                        glVertexAttribPointer(materialShaderInfo.textureCoordsAttribLocation, 2, GL_FLOAT, false, 0, 0);
                    }

                    if (meshInfo.normalBufferObject != 0
                    && materialShaderInfo.normalAttribLocation >= 0) {
                        glBindBuffer(GL_ARRAY_BUFFER, meshInfo.normalBufferObject);
                        glEnableVertexAttribArray(materialShaderInfo.normalAttribLocation);
                        glVertexAttribPointer(materialShaderInfo.normalAttribLocation, 3, GL_FLOAT, false, 0, 0);
                    }

                    if (meshInfo.tangentBufferObject != 0
                    && materialShaderInfo.tangentAttribLocation >= 0) {
                        glBindBuffer(GL_ARRAY_BUFFER, meshInfo.tangentBufferObject);
                        glEnableVertexAttribArray(materialShaderInfo.tangentAttribLocation);
                        glVertexAttribPointer(materialShaderInfo.tangentAttribLocation, 4, GL_FLOAT, false, 0, 0);
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

/**
 * Expands an 8-bit single-channel grayscale image into a tightly packed RGB byte buffer,
 * replicating the gray value across R, G and B. The result is appended to `rgb`.
 */
private void expandGrayscaleToRgb(const ref Image image, ref Array!ubyte rgb) {
    size_t pixelCount = cast(size_t) image.width * image.height;
    rgb.capacity = pixelCount * 3;
    foreach (i; 0 .. pixelCount) {
        ubyte gray = image.pixelData[i];
        rgb.add(gray);
        rgb.add(gray);
        rgb.add(gray);
    }
}

/**
 * Expands an 8-bit grayscale + alpha (2 channel) image into a tightly packed RGBA byte buffer,
 * replicating the gray value across R, G and B and taking the alpha from the second channel.
 * The result is appended to `rgba`.
 */
private void expandGrayscaleAlphaToRgba(const ref Image image, ref Array!ubyte rgba) {
    size_t pixelCount = cast(size_t) image.width * image.height;
    rgba.capacity = pixelCount * 4;
    foreach (i; 0 .. pixelCount) {
        ubyte gray = image.pixelData[i * 2];
        ubyte alpha = image.pixelData[i * 2 + 1];
        rgba.add(gray);
        rgba.add(gray);
        rgba.add(gray);
        rgba.add(alpha);
    }
}

/**
 * Creates and uploads a GL texture for the referenced texture of a material.
 * Returns the GL texture handle, or 0 when the texture could not be resolved or uploaded.
 */
private GLuint createMaterialTexture(Model* model, TextureIndex textureIndex) {
    if (textureIndex == 0) {
        return 0;
    }

    Texture* texture = null;
    foreach (ref candidate; model.textures) {
        if (candidate.index == textureIndex) {
            texture = &candidate;
            break;
        }
    }

    if (texture is null) {
        writeErrLn("Material in model ", model.name, " references unknown texture index ",
            textureIndex, "; skipping texture.");
        return 0;
    }

    auto textureResult = getTexture(texture.path);
    if (textureResult.isFailure) {
        writeErrLn("Failed to resolve texture '", texture.path, "' (index ", textureIndex,
            ") for material in model ", model.name, "; skipping texture.");
        return 0;
    }

    auto imageRef = textureResult.value;
    Image* image = imageRef.ptr;

    if (image.channelFormat != ChannelFormat.u8) {
        writeErrLn("Material texture '", texture.path,
            "' is not 8-bit per channel; skipping texture.");
        return 0;
    }

    // GL_LUMINANCE(_ALPHA) are removed from core GL 3.1+ and deprecated in WebGL2, so the
    // sampler is only ever fed the portable RGB/RGBA formats. Grayscale (1) is expanded to RGB
    // and grayscale + alpha (2) to RGBA on the CPU; 3/4-channel data is uploaded as-is.
    GLenum format;
    Array!ubyte expandedPixels;
    const(ubyte)[] pixels;
    if (image.channelCount == 1) {
        format = GL_RGB;
        expandGrayscaleToRgb(*image, expandedPixels);
        pixels = expandedPixels.arr;
    } else if (image.channelCount == 2) {
        format = GL_RGBA;
        expandGrayscaleAlphaToRgba(*image, expandedPixels);
        pixels = expandedPixels.arr;
    } else if (image.channelCount == 3) {
        format = GL_RGB;
        pixels = image.pixelData.arr;
    } else if (image.channelCount == 4) {
        format = GL_RGBA;
        pixels = image.pixelData.arr;
    } else {
        writeErrLn("Material texture '", texture.path, "' has an unsupported channel count ",
            cast(uint) image.channelCount, "; skipping texture.");
        return 0;
    }

    auto textureObject = glCreateTexture();
    glBindTexture(GL_TEXTURE_2D, textureObject);

    // Pixel data is tightly packed with no per-row padding; the default unpack alignment of 4
    // would misread rows of e.g. RGB textures whose row length is not a multiple of 4.
    glPixelStorei(GL_UNPACK_ALIGNMENT, 1);
    glTexImage2D(GL_TEXTURE_2D, 0, format, image.width, image.height, 0, format,
        GL_UNSIGNED_BYTE, pixels);

    GLenum minFilter = resolveMinFilter(texture.minFilter);
    GLenum magFilter = resolveMagFilter(texture.magFilter);
    GLenum wrapS = resolveWrap(texture.wrapS);
    GLenum wrapT = resolveWrap(texture.wrapT);

    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, wrapS);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, wrapT);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, minFilter);
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, magFilter);

    if (minFilterUsesMipmaps(minFilter)) {
        glGenerateMipmap(GL_TEXTURE_2D);
    }

    glBindTexture(GL_TEXTURE_2D, 0);
    return textureObject;
}

private GLenum resolveMagFilter(TextureMagFilter filter) {
    final switch (filter) {
    case TextureMagFilter.nearest:
        return GL_NEAREST;
    case TextureMagFilter.linear:
        return GL_LINEAR;
    case TextureMagFilter.unspecified:
        return GL_LINEAR;
    }
}

private GLenum resolveMinFilter(TextureMinFilter filter) {
    final switch (filter) {
    case TextureMinFilter.nearest:
        return GL_NEAREST;
    case TextureMinFilter.linear:
        return GL_LINEAR;
    case TextureMinFilter.nearestMipmapNearest:
        return GL_NEAREST_MIPMAP_NEAREST;
    case TextureMinFilter.linearMipmapNearest:
        return GL_LINEAR_MIPMAP_NEAREST;
    case TextureMinFilter.nearestMipmapLinear:
        return GL_NEAREST_MIPMAP_LINEAR;
    case TextureMinFilter.linearMipmapLinear:
        return GL_LINEAR_MIPMAP_LINEAR;
    case TextureMinFilter.unspecified:
        return GL_LINEAR_MIPMAP_LINEAR;
    }
}

private bool minFilterUsesMipmaps(GLenum minFilter) {
    return minFilter == GL_NEAREST_MIPMAP_NEAREST
        || minFilter == GL_LINEAR_MIPMAP_NEAREST
        || minFilter == GL_NEAREST_MIPMAP_LINEAR
        || minFilter == GL_LINEAR_MIPMAP_LINEAR;
}

private GLenum resolveWrap(TextureWrap wrap) {
    final switch (wrap) {
    case TextureWrap.repeat:
        return GL_REPEAT;
    case TextureWrap.clampToEdge:
        return GL_CLAMP_TO_EDGE;
    case TextureWrap.mirroredRepeat:
        return GL_MIRRORED_REPEAT;
    case TextureWrap.unspecified:
        return GL_REPEAT;
    }
}

void unloadEntityModel(EntityId entity) {
    entity.withComponentData(GlModelInfoComponentType, (GlModelInfo* modelInfo) {
        foreach (ref meshInfo; modelInfo.meshes) {
            glDeleteBuffer(meshInfo.positionBufferObject);
            glDeleteBuffer(meshInfo.colorBufferObject);
            glDeleteBuffer(meshInfo.textureCoordsBufferObject);
            glDeleteBuffer(meshInfo.normalBufferObject);
            glDeleteBuffer(meshInfo.tangentBufferObject);
            glDeleteBuffer(meshInfo.elementBufferObject);
            if (meshInfo.textureObject != 0) {
                glDeleteTexture(meshInfo.textureObject);
            }

            if (meshInfo.normalTextureObject != 0) {
                glDeleteTexture(meshInfo.normalTextureObject);
            }

            if (meshInfo.metallicRoughnessTextureObject != 0) {
                glDeleteTexture(meshInfo.metallicRoughnessTextureObject);
            }

            // Borrowed from the slot above when both name one texture, in which case the
            // delete there already covered it.
            if (meshInfo.occlusionTextureObject != 0 && !meshInfo.occlusionTextureIsShared) {
                glDeleteTexture(meshInfo.occlusionTextureObject);
            }

            if (meshInfo.emissiveTextureObject != 0) {
                glDeleteTexture(meshInfo.emissiveTextureObject);
            }

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

static if (maxShadowViews > 0) {
    /**
     * Draws an entity's depth alone, as the given shadow view sees it.
     *
     * Deliberately not $(D drawModel) with the lighting left out: what a shadow map holds is
     * how far the nearest surface is, which no material of that surface changes. Skipping the
     * material path entirely is what makes drawing the world once per casting light
     * affordable.
     */
    void drawModelDepth(EntityId entity, const ref RenderPass renderPass, const ref RenderView view) {
        if (!shadowMapsEnabled) {
            return;
        }

        entity.withComponentData(GlModelInfoComponentType, (GlModelInfo* modelInfo) {
            auto modelMatrix = entity.worldTransformOf();

            // Against the light's view rather than the camera's: what the camera cannot see
            // may well be what casts the shadow it does see.
            auto worldBounds = modelInfo.bounds.transformedBy(modelMatrix);
            if (frustumCullingEnabled && !view.frustum.overlaps(worldBounds)) {
                return;
            }

            auto maybePassInfo = renderPassInfos.get(renderPass.passName.sid);
            if (!maybePassInfo.isDefined) {
                return;
            }

            auto passInfo = maybePassInfo.value;
            auto passSid = renderPass.passName.sid;
            auto modelViewProjectionMatrix = view.viewProjectionMatrix * modelMatrix;
            auto modelViewProjectionMatrixData = modelViewProjectionMatrix.getDataArray!float;

            glUseProgram(passInfo.shaderProgram);
            if (passInfo.mvpMatrixUniformLocation >= 0) {
                glUniformMatrix4fv(passInfo.mvpMatrixUniformLocation, 1, true,
                    modelViewProjectionMatrixData);
            }

            foreach (ref meshInfo; modelInfo.meshes) {
                auto maybeVao = meshInfo.vertexArrayObjects.get(passSid);
                if (!maybeVao.isDefined) {
                    continue;
                }

                if (meshInfo.doubleSided) {
                    glDisable(GL_CULL_FACE);
                }

                glBindVertexArray(maybeVao.value);
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
} else {
    void drawModelDepth(EntityId entity, const ref RenderPass renderPass, const ref RenderView view) {
    }
}

void drawModel(EntityId entity, const ref RenderPass renderPass, const ref RenderView view) {
    entity.withComponentData(GlModelInfoComponentType, (GlModelInfo* modelInfo) {
        auto modelMatrix = entity.worldTransformOf();

        // Measured against the model's bounds in the world rather than its origin, so a
        // model whose origin is off screen still draws when one end of it is not. The same
        // box then picks its lights, so a light that reaches only one end is not culled.
        auto worldBounds = modelInfo.bounds.transformedBy(modelMatrix);
        if (frustumCullingEnabled && !view.frustum.overlaps(worldBounds)) {
            return;
        }

        auto modelViewProjectionMatrix = view.viewProjectionMatrix * modelMatrix;
        auto modelViewProjectionMatrixData = modelViewProjectionMatrix.getDataArray!float;
        auto modelMatrixData = modelMatrix.getDataArray!float;
        auto normalMatrixData = modelMatrix.toNormalMatrix().getDataArray!float;

        // Scaled by the intensity here rather than in the shader: it is one dial over both
        // colors, so a fragment has no use for it on its own.
        GLfloat[3] ambientSkyRadianceData;
        ambientSkyRadianceData[0] = cast(GLfloat)(ambientSkyColor.r * ambientIntensity);
        ambientSkyRadianceData[1] = cast(GLfloat)(ambientSkyColor.g * ambientIntensity);
        ambientSkyRadianceData[2] = cast(GLfloat)(ambientSkyColor.b * ambientIntensity);

        GLfloat[3] ambientGroundRadianceData;
        ambientGroundRadianceData[0] = cast(GLfloat)(ambientGroundColor.r * ambientIntensity);
        ambientGroundRadianceData[1] = cast(GLfloat)(ambientGroundColor.g * ambientIntensity);
        ambientGroundRadianceData[2] = cast(GLfloat)(ambientGroundColor.b * ambientIntensity);

        static if (maxLights > 0) {
            // Picked once for the whole entity: every mesh of a model is lit by the same lights.
            GLsizei selectedLightCount = cast(GLsizei) selectActiveLights(worldBounds,
                shadeableLightTypes[], selectedLights);

            lightPositionRadiusData.truncate(0);
            lightColorIntensityData.truncate(0);
            lightDirectionData.truncate(0);
            foreach (i; 0 .. selectedLights.length) {
                auto activeLight = selectedLights[i];
                lightPositionRadiusData.add(cast(GLfloat) activeLight.position.x);
                lightPositionRadiusData.add(cast(GLfloat) activeLight.position.y);
                lightPositionRadiusData.add(cast(GLfloat) activeLight.position.z);
                lightPositionRadiusData.add(cast(GLfloat) activeLight.light.attenuationRadius);

                lightColorIntensityData.add(cast(GLfloat) activeLight.light.color.r);
                lightColorIntensityData.add(cast(GLfloat) activeLight.light.color.g);
                lightColorIntensityData.add(cast(GLfloat) activeLight.light.color.b);
                lightColorIntensityData.add(cast(GLfloat) activeLight.light.intensity);

                // The flag is what the shader picks its term by: a point light's direction is
                // never read, and goes up as the zero vector it was collected as.
                lightDirectionData.add(cast(GLfloat) activeLight.direction.x);
                lightDirectionData.add(cast(GLfloat) activeLight.direction.y);
                lightDirectionData.add(cast(GLfloat) activeLight.direction.z);
                lightDirectionData.add(
                    activeLight.light.lightType == LightType.directional ? 1.0f : 0.0f);
            }

            static if (maxShadowViews > 0) {
                // Which of this frame's maps belongs to each of the lights this entity ended
                // up with. The selection is per entity and ordered by distance, so a light's
                // slot here is not the one it had for the entity drawn before this.
                lightShadowParamsData.truncate(0);
                foreach (i; 0 .. selectedLights.length) {
                    auto activeLight = selectedLights[i];
                    lightShadowParamsData.add(cast(GLfloat) activeLight.shadowView);
                    lightShadowParamsData.add(cast(GLfloat) activeLight.shadowViewCount);
                    lightShadowParamsData.add(0);
                    lightShadowParamsData.add(0);
                }
            }
        }

        auto passSid = renderPass.passName.sid;
        auto maybePassInfo = renderPassInfos.get(passSid);

        foreach (ref meshInfo; modelInfo.meshes) {
            GLuint shaderProgram;
            GLint mvpMatrixUniformLocation = -1;
            GLint albedoTextureUniformLocation = -1;
            GLint baseColorFactorUniformLocation = -1;
            GLint normalTextureUniformLocation = -1;
            GLint hasNormalMapUniformLocation = -1;
            GLint normalTextureScaleUniformLocation = -1;
            GLint metallicRoughnessTextureUniformLocation = -1;
            GLint hasMetallicRoughnessMapUniformLocation = -1;
            GLint metallicFactorUniformLocation = -1;
            GLint roughnessFactorUniformLocation = -1;
            GLint occlusionTextureUniformLocation = -1;
            GLint hasOcclusionMapUniformLocation = -1;
            GLint occlusionStrengthUniformLocation = -1;
            GLint emissiveTextureUniformLocation = -1;
            GLint hasEmissiveMapUniformLocation = -1;
            GLint emissiveFactorUniformLocation = -1;
            GLint emissiveStrengthUniformLocation = -1;
            GLint cameraWorldPositionUniformLocation = -1;
            GLint modelMatrixUniformLocation = -1;
            GLint normalMatrixUniformLocation = -1;
            GLint ambientSkyRadianceUniformLocation = -1;
            GLint ambientGroundRadianceUniformLocation = -1;
            GLuint vao = 0;
            auto useMaterial = false;

            static if (maxLights > 0) {
                GLint lightCountUniformLocation = -1;
                GLint lightPositionRadiusUniformLocation = -1;
                GLint lightColorIntensityUniformLocation = -1;
                GLint lightDirectionUniformLocation = -1;
            }

            static if (maxShadowViews > 0) {
                GLint lightShadowParamsUniformLocation = -1;
            }

            if (meshInfo.materialIndex != noMaterial
            && meshInfo.materialType != MaterialType.invalid
            && meshInfo.materialVertexArrayObject != 0) {
                auto maybeMaterialShaderInfo = materialShaderInfos.get(meshInfo.materialType);
                if (maybeMaterialShaderInfo.isDefined) {
                    auto materialShaderInfo = maybeMaterialShaderInfo.value;
                    shaderProgram = materialShaderInfo.shaderProgram;
                    mvpMatrixUniformLocation = materialShaderInfo.mvpMatrixUniformLocation;
                    albedoTextureUniformLocation = materialShaderInfo.albedoTextureUniformLocation;
                    baseColorFactorUniformLocation = materialShaderInfo
                        .baseColorFactorUniformLocation;
                    normalTextureUniformLocation = materialShaderInfo.normalTextureUniformLocation;
                    hasNormalMapUniformLocation = materialShaderInfo.hasNormalMapUniformLocation;
                    normalTextureScaleUniformLocation = materialShaderInfo
                        .normalTextureScaleUniformLocation;
                    metallicRoughnessTextureUniformLocation = materialShaderInfo
                        .metallicRoughnessTextureUniformLocation;
                    hasMetallicRoughnessMapUniformLocation = materialShaderInfo
                        .hasMetallicRoughnessMapUniformLocation;
                    metallicFactorUniformLocation = materialShaderInfo
                        .metallicFactorUniformLocation;
                    roughnessFactorUniformLocation = materialShaderInfo
                        .roughnessFactorUniformLocation;
                    occlusionTextureUniformLocation = materialShaderInfo
                        .occlusionTextureUniformLocation;
                    hasOcclusionMapUniformLocation = materialShaderInfo
                        .hasOcclusionMapUniformLocation;
                    occlusionStrengthUniformLocation = materialShaderInfo
                        .occlusionStrengthUniformLocation;
                    emissiveTextureUniformLocation = materialShaderInfo
                        .emissiveTextureUniformLocation;
                    hasEmissiveMapUniformLocation = materialShaderInfo
                        .hasEmissiveMapUniformLocation;
                    emissiveFactorUniformLocation = materialShaderInfo
                        .emissiveFactorUniformLocation;
                    emissiveStrengthUniformLocation = materialShaderInfo
                        .emissiveStrengthUniformLocation;
                    cameraWorldPositionUniformLocation = materialShaderInfo
                        .cameraWorldPositionUniformLocation;
                    modelMatrixUniformLocation = materialShaderInfo.modelMatrixUniformLocation;
                    normalMatrixUniformLocation = materialShaderInfo.normalMatrixUniformLocation;
                    ambientSkyRadianceUniformLocation = materialShaderInfo
                        .ambientSkyRadianceUniformLocation;
                    ambientGroundRadianceUniformLocation = materialShaderInfo
                        .ambientGroundRadianceUniformLocation;
                    vao = meshInfo.materialVertexArrayObject;
                    useMaterial = true;

                    static if (maxLights > 0) {
                        lightCountUniformLocation = materialShaderInfo.lightCountUniformLocation;
                        lightPositionRadiusUniformLocation = materialShaderInfo
                            .lightPositionRadiusUniformLocation;
                        lightColorIntensityUniformLocation = materialShaderInfo
                            .lightColorIntensityUniformLocation;
                        lightDirectionUniformLocation = materialShaderInfo
                            .lightDirectionUniformLocation;
                    }

                    static if (maxShadowViews > 0) {
                        lightShadowParamsUniformLocation = materialShaderInfo
                            .lightShadowParamsUniformLocation;
                    }
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

            if (modelMatrixUniformLocation >= 0) {
                glUniformMatrix4fv(modelMatrixUniformLocation, 1, true, modelMatrixData);
            }

            if (normalMatrixUniformLocation >= 0) {
                glUniformMatrix3fv(normalMatrixUniformLocation, 1, true, normalMatrixData);
            }

            if (ambientSkyRadianceUniformLocation >= 0) {
                glUniform3fv(ambientSkyRadianceUniformLocation, 1, ambientSkyRadianceData[]);
            }

            if (ambientGroundRadianceUniformLocation >= 0) {
                glUniform3fv(ambientGroundRadianceUniformLocation, 1, ambientGroundRadianceData[]);
            }

            static if (maxLights > 0) {
                if (lightCountUniformLocation >= 0) {
                    glUniform1i(lightCountUniformLocation, selectedLightCount);

                    if (selectedLightCount > 0) {
                        if (lightPositionRadiusUniformLocation >= 0) {
                            glUniform4fv(lightPositionRadiusUniformLocation, selectedLightCount,
                                lightPositionRadiusData.arr);
                        }

                        if (lightColorIntensityUniformLocation >= 0) {
                            glUniform4fv(lightColorIntensityUniformLocation, selectedLightCount,
                                lightColorIntensityData.arr);
                        }

                        if (lightDirectionUniformLocation >= 0) {
                            glUniform4fv(lightDirectionUniformLocation, selectedLightCount,
                                lightDirectionData.arr);
                        }

                        static if (maxShadowViews > 0) {
                            if (lightShadowParamsUniformLocation >= 0) {
                                glUniform4fv(lightShadowParamsUniformLocation, selectedLightCount,
                                    lightShadowParamsData.arr);
                            }
                        }
                    }
                }
            }

            if (useMaterial && meshInfo.materialType.referencesTexture) {
                // A material may reference no albedo texture at all, or one that failed to
                // load. Standing the 1x1 white texture in for it makes the shader's albedo
                // multiply yield the base color factor unchanged, so neither case needs a
                // branch in the fragment shader - or leaves unit 0 unbound, which would
                // sample black.
                GLuint albedoTextureObject = meshInfo.textureObject != 0
                    ? meshInfo.textureObject : defaultAlbedoTextureObject;

                if (albedoTextureUniformLocation >= 0) {
                    glActiveTexture(GL_TEXTURE0);
                    glBindTexture(GL_TEXTURE_2D, albedoTextureObject);
                    glUniform1i(albedoTextureUniformLocation, 0);
                }

                if (baseColorFactorUniformLocation >= 0) {
                    GLfloat[4] baseColorFactorData = [
                        cast(GLfloat) meshInfo.baseColorFactor.r,
                        cast(GLfloat) meshInfo.baseColorFactor.g,
                        cast(GLfloat) meshInfo.baseColorFactor.b,
                        cast(GLfloat) meshInfo.baseColorFactor.a
                    ];

                    glUniform4fv(baseColorFactorUniformLocation, 1, baseColorFactorData[]);
                }
            }

            if (useMaterial && meshInfo.materialType.referencesNormalTexture) {
                // Told on every draw, not only when there is a map: uniforms live on the
                // program, so a mesh without one would otherwise inherit the flag - and the
                // stale texture - from whichever mesh was drawn through this shader before it.
                bool hasNormalMap = meshInfo.normalTextureObject != 0
                    && meshInfo.tangentBufferObject != 0;

                if (hasNormalMap && normalTextureUniformLocation >= 0) {
                    glActiveTexture(GL_TEXTURE1);
                    glBindTexture(GL_TEXTURE_2D, meshInfo.normalTextureObject);
                    glUniform1i(normalTextureUniformLocation, 1);

                    // Back to the unit the albedo texture is bound through, so nothing that
                    // draws after this inherits unit 1 as the active one.
                    glActiveTexture(GL_TEXTURE0);

                    if (normalTextureScaleUniformLocation >= 0) {
                        glUniform1f(normalTextureScaleUniformLocation, meshInfo.normalTextureScale);
                    }
                }

                if (hasNormalMapUniformLocation >= 0) {
                    glUniform1i(hasNormalMapUniformLocation, hasNormalMap ? 1 : 0);
                }
            }

            if (useMaterial && meshInfo.materialType.hasMetallicRoughness) {
                // Told on every draw for the same reason the normal map's flag is: a mesh
                // without a map would otherwise keep the flag - and the texture - of
                // whichever mesh was last drawn through this program.
                bool hasMetallicRoughnessMap = meshInfo.metallicRoughnessTextureObject != 0;

                if (hasMetallicRoughnessMap && metallicRoughnessTextureUniformLocation >= 0) {
                    glActiveTexture(GL_TEXTURE2);
                    glBindTexture(GL_TEXTURE_2D, meshInfo.metallicRoughnessTextureObject);
                    glUniform1i(metallicRoughnessTextureUniformLocation, 2);

                    // Back to the albedo's unit, so nothing drawn after this inherits unit 2
                    // as the active one.
                    glActiveTexture(GL_TEXTURE0);
                }

                if (hasMetallicRoughnessMapUniformLocation >= 0) {
                    glUniform1i(hasMetallicRoughnessMapUniformLocation,
                        hasMetallicRoughnessMap ? 1 : 0);
                }

                if (metallicFactorUniformLocation >= 0) {
                    glUniform1f(metallicFactorUniformLocation, meshInfo.metallicFactor);
                }

                if (roughnessFactorUniformLocation >= 0) {
                    glUniform1f(roughnessFactorUniformLocation, meshInfo.roughnessFactor);
                }

                if (cameraWorldPositionUniformLocation >= 0) {
                    GLfloat[3] cameraWorldPositionData = [
                        cast(GLfloat) activeCameraWorldPosition.x,
                        cast(GLfloat) activeCameraWorldPosition.y,
                        cast(GLfloat) activeCameraWorldPosition.z
                    ];

                    glUniform3fv(cameraWorldPositionUniformLocation, 1, cameraWorldPositionData[]);
                }
            }

            if (useMaterial && meshInfo.materialType.hasOcclusion) {
                // Told every draw, like the two flags above. The texture object may be the
                // metallic-roughness one over again, which costs a second binding but no
                // second upload.
                bool hasOcclusionMap = meshInfo.occlusionTextureObject != 0;

                if (hasOcclusionMap && occlusionTextureUniformLocation >= 0) {
                    glActiveTexture(GL_TEXTURE3);
                    glBindTexture(GL_TEXTURE_2D, meshInfo.occlusionTextureObject);
                    glUniform1i(occlusionTextureUniformLocation, 3);

                    // Back to the albedo's unit, so nothing drawn after this inherits unit 3
                    // as the active one.
                    glActiveTexture(GL_TEXTURE0);

                    if (occlusionStrengthUniformLocation >= 0) {
                        glUniform1f(occlusionStrengthUniformLocation, meshInfo.occlusionStrength);
                    }
                }

                if (hasOcclusionMapUniformLocation >= 0) {
                    glUniform1i(hasOcclusionMapUniformLocation, hasOcclusionMap ? 1 : 0);
                }
            }

            if (useMaterial && meshInfo.materialType.hasEmissive) {
                // Told every draw, like the flags above: a mesh without a map would otherwise
                // keep the flag - and the texture - of whichever mesh this program drew last.
                bool hasEmissiveMap = meshInfo.emissiveTextureObject != 0;

                if (hasEmissiveMap && emissiveTextureUniformLocation >= 0) {
                    glActiveTexture(GL_TEXTURE4);
                    glBindTexture(GL_TEXTURE_2D, meshInfo.emissiveTextureObject);
                    glUniform1i(emissiveTextureUniformLocation, 4);

                    // Back to the albedo's unit, so nothing drawn after this inherits unit 4
                    // as the active one.
                    glActiveTexture(GL_TEXTURE0);
                }

                if (hasEmissiveMapUniformLocation >= 0) {
                    glUniform1i(hasEmissiveMapUniformLocation, hasEmissiveMap ? 1 : 0);
                }

                if (emissiveFactorUniformLocation >= 0) {
                    GLfloat[3] emissiveFactorData = [
                        cast(GLfloat) meshInfo.emissiveFactor.r,
                        cast(GLfloat) meshInfo.emissiveFactor.g,
                        cast(GLfloat) meshInfo.emissiveFactor.b
                    ];

                    glUniform3fv(emissiveFactorUniformLocation, 1, emissiveFactorData[]);
                }

                if (emissiveStrengthUniformLocation >= 0) {
                    glUniform1f(emissiveStrengthUniformLocation, meshInfo.emissiveStrength);
                }
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

// Shared by every material that has no albedo texture of its own. Deliberately not created by
// createMaterialTexture: unloadEntityModel deletes any non-zero mesh texture, and this one
// outlives every model.
private GLuint defaultAlbedoTextureObject;

static if (maxShadowViews > 0) {
    // The frame's shadow maps: one array texture with a layer per view, and the framebuffer
    // each layer is rendered through in turn.
    private GLuint shadowMapArray;
    private GLuint shadowFramebuffer;
    private uint allocatedShadowMapSize = 1;

    // Whether any registered pass renders the maps. When nothing does they are a 1x1
    // placeholder that only exists so the lit shaders have something complete to sample.
    private bool shadowMapsEnabled;

    // Scratch buffers reused every frame, so a steady scene stops allocating.
    private Array!GLfloat shadowViewProjectionData;
    private Array!GLfloat lightShadowParamsData;
}

static if (maxLights > 0) {
    // The light types the material shaders have a term and uniforms for: lightPositionRadius
    // places a point light, lightDirection aims a directional one, and lightColorIntensity
    // describes both. Any other type needs its own uniforms and its own term before it can be
    // added here.
    private static immutable LightType[2] shadeableLightTypes = [
        LightType.point, LightType.directional
    ];

    // Scratch buffers reused by every draw, so packing a frame's lights allocates nothing
    // after the first few draws.
    private Array!ActiveLight selectedLights;
    private Array!GLfloat lightPositionRadiusData;
    private Array!GLfloat lightColorIntensityData;
    private Array!GLfloat lightDirectionData;
}

private struct GlMeshInfo {
    GLuint positionBufferObject;
    GLuint colorBufferObject;
    GLuint textureCoordsBufferObject;
    GLuint normalBufferObject;
    GLuint tangentBufferObject;
    GLuint textureObject;
    GLuint normalTextureObject;
    GLfloat normalTextureScale = 1.0;

    /// Packed metallic-roughness map of the mesh's material - roughness in green, metalness in
    /// blue. 0 when the material has none, leaving the factors below to describe the surface.
    GLuint metallicRoughnessTextureObject;

    /// Dials of the mesh material's metallic-roughness BRDF, multiplied over the map above where
    /// there is one. Both start at glTF's default for an absent factor - a fully rough metal -
    /// which is what `Material` defaults them to.
    GLfloat metallicFactor = 1.0;
    GLfloat roughnessFactor = 1.0;

    /// Ambient occlusion map of the mesh's material, read from its red channel. 0 when the
    /// material has none. Often the very object above: glTF packs occlusion into the same
    /// image, and a material naming one texture for both slots uploads it once.
    GLuint occlusionTextureObject;

    /// Whether the object above is that borrowed copy rather than one of this slot's own, so
    /// unloading knows not to delete the same texture twice.
    bool occlusionTextureIsShared;

    /// How far the occlusion map is allowed to darken indirect light. 1 is the map at full
    /// strength, 0 ignores it.
    GLfloat occlusionStrength = 1.0;

    /// Emissive map of the mesh's material, saying where the surface glows. 0 when the
    /// material has none and it emits evenly by its factor alone.
    GLuint emissiveTextureObject;

    /// Light the mesh's material gives off by itself, added to the shaded surface. Multiplies
    /// the map above where there is one. Black - the default - emits nothing, which is what a
    /// material that never asked to glow stores.
    EmissiveFactor emissiveFactor;

    /// Multiplier over the factor above, carrying emission past the [0, 1] it is authored in.
    GLfloat emissiveStrength = 1.0;

    /// Multiplier over the albedo, from the mesh's material. Applies whether or not the
    /// material has a texture; without one it is the mesh's color outright.
    BaseColorFactor baseColorFactor;
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

    /// The model's bounds in its own space, kept so a frame need not go back to the asset.
    Aabb bounds;

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
    GLint textureCoordsAttribLocation;
    GLint albedoTextureUniformLocation;
    GLint baseColorFactorUniformLocation = -1;

    // A shader that does not declare these - or whose compiler stripped them because nothing
    // reads them - has no location for them, so they start out at the "absent" location.
    GLint normalAttribLocation = -1;
    GLint tangentAttribLocation = -1;
    GLint normalTextureUniformLocation = -1;
    GLint hasNormalMapUniformLocation = -1;
    GLint normalTextureScaleUniformLocation = -1;
    GLint metallicRoughnessTextureUniformLocation = -1;
    GLint hasMetallicRoughnessMapUniformLocation = -1;
    GLint metallicFactorUniformLocation = -1;
    GLint roughnessFactorUniformLocation = -1;
    GLint occlusionTextureUniformLocation = -1;
    GLint hasOcclusionMapUniformLocation = -1;
    GLint occlusionStrengthUniformLocation = -1;
    GLint emissiveTextureUniformLocation = -1;
    GLint hasEmissiveMapUniformLocation = -1;
    GLint emissiveFactorUniformLocation = -1;
    GLint emissiveStrengthUniformLocation = -1;
    GLint cameraWorldPositionUniformLocation = -1;
    GLint modelMatrixUniformLocation = -1;
    GLint normalMatrixUniformLocation = -1;
    GLint ambientSkyRadianceUniformLocation = -1;
    GLint ambientGroundRadianceUniformLocation = -1;

    static if (maxLights > 0) {
        GLint lightCountUniformLocation = -1;
        GLint lightPositionRadiusUniformLocation = -1;
        GLint lightColorIntensityUniformLocation = -1;
        GLint lightDirectionUniformLocation = -1;
    }

    static if (maxShadowViews > 0) {
        GLint shadowMapsUniformLocation = -1;
        GLint shadowViewProjectionUniformLocation = -1;
        GLint lightShadowParamsUniformLocation = -1;
        GLint shadowNormalBiasUniformLocation = -1;
    }
}
