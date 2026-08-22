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
import retrograde.engine.rendering.lighting : ActiveLight, ambientGroundColor, ambientIntensity,
    ambientSkyColor, selectActiveLights;
import retrograde.engine.rendering.materialshader : maxLights;

import retrograde.assets.model : ModelComponentType, Model, MaterialType, MaterialIndex, noMaterial,
    isLit, referencesTexture, TextureIndex, Texture, TextureMagFilter, TextureMinFilter, TextureWrap;
import retrograde.assets.image : Image, ChannelFormat;
import retrograde.assets.assetlibrary : getModel, getTexture;

import retrograde.std.memory : makeRaw, unique;
import retrograde.std.collections : Array, HashMap;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.math : Matrix4, Vector3, Quaternion, toTranslationMatrix4, toScalingMatrix4;
import retrograde.std.geometry : PositionComponentType, OrientationComponentType, ScaleComponentType;
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
    }

    if (materialShader.materialType.isLit) {
        shaderInfo.normalAttribLocation = glGetAttribLocation(program, "normal");
        shaderInfo.modelMatrixUniformLocation = glGetUniformLocation(program, "modelMatrix");
        shaderInfo.ambientSkyRadianceUniformLocation = glGetUniformLocation(program, "ambientSkyRadiance");
        shaderInfo.ambientGroundRadianceUniformLocation = glGetUniformLocation(program, "ambientGroundRadiance");

        static if (maxLights > 0) {
            shaderInfo.lightCountUniformLocation = glGetUniformLocation(program, "lightCount");
            shaderInfo.lightPositionRadiusUniformLocation = glGetUniformLocation(program, "lightPositionRadius[0]");
            shaderInfo.lightColorIntensityUniformLocation = glGetUniformLocation(program, "lightColorIntensity[0]");
        }
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
            if (mesh.materialIndex != noMaterial) {
                foreach (ref material; model.materials) {
                    if (material.index == mesh.materialIndex) {
                        meshInfo.materialType = material.type;
                        meshInfo.doubleSided = material.doubleSided;
                        materialTextureIndex = material.textureIndex;
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
                        // The first UV channel occupies the first `vertices.length` entries
                        // of the channel-major `uvCoords` array.
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
            glDeleteBuffer(meshInfo.elementBufferObject);
            if (meshInfo.textureObject != 0) {
                glDeleteTexture(meshInfo.textureObject);
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
        auto modelMatrixData = modelMatrix.getDataArray!float;

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
            GLsizei selectedLightCount = cast(GLsizei) selectActiveLights(position, selectedLights);

            lightPositionRadiusData.truncate(0);
            lightColorIntensityData.truncate(0);
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
            }
        }

        auto passSid = renderPass.passName.sid;
        auto maybePassInfo = renderPassInfos.get(passSid);

        foreach (ref meshInfo; modelInfo.meshes) {
            GLuint shaderProgram;
            GLint mvpMatrixUniformLocation = -1;
            GLint albedoTextureUniformLocation = -1;
            GLint modelMatrixUniformLocation = -1;
            GLint ambientSkyRadianceUniformLocation = -1;
            GLint ambientGroundRadianceUniformLocation = -1;
            GLuint vao = 0;
            auto useMaterial = false;

            static if (maxLights > 0) {
                GLint lightCountUniformLocation = -1;
                GLint lightPositionRadiusUniformLocation = -1;
                GLint lightColorIntensityUniformLocation = -1;
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
                    modelMatrixUniformLocation = materialShaderInfo.modelMatrixUniformLocation;
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
                    }
                }
            }

            if (useMaterial && meshInfo.materialType.referencesTexture
            && meshInfo.textureObject != 0 && albedoTextureUniformLocation >= 0) {
                glActiveTexture(GL_TEXTURE0);
                glBindTexture(GL_TEXTURE_2D, meshInfo.textureObject);
                glUniform1i(albedoTextureUniformLocation, 0);
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

static if (maxLights > 0) {
    // Scratch buffers reused by every draw, so packing a frame's lights allocates nothing
    // after the first few draws.
    private Array!ActiveLight selectedLights;
    private Array!GLfloat lightPositionRadiusData;
    private Array!GLfloat lightColorIntensityData;
}

private struct GlMeshInfo {
    GLuint positionBufferObject;
    GLuint colorBufferObject;
    GLuint textureCoordsBufferObject;
    GLuint normalBufferObject;
    GLuint textureObject;
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
    GLint textureCoordsAttribLocation;
    GLint albedoTextureUniformLocation;

    // A shader that does not declare these - or whose compiler stripped them because nothing
    // reads them - has no location for them, so they start out at the "absent" location.
    GLint normalAttribLocation = -1;
    GLint modelMatrixUniformLocation = -1;
    GLint ambientSkyRadianceUniformLocation = -1;
    GLint ambientGroundRadianceUniformLocation = -1;

    static if (maxLights > 0) {
        GLint lightCountUniformLocation = -1;
        GLint lightPositionRadiusUniformLocation = -1;
        GLint lightColorIntensityUniformLocation = -1;
    }
}
