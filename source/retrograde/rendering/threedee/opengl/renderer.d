/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2018 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.rendering.threedee.opengl.renderer;

version(Have_derelict_gl3) {

import retrograde.entity;
import retrograde.graphics;
import retrograde.file;
import retrograde.model;
import retrograde.rendering.threedee.opengl.shader;
import retrograde.rendering.threedee.opengl.model;
import retrograde.rendering.threedee.opengl.uniform;
import retrograde.math;
import retrograde.camera;
import retrograde.geometry;
import retrograde.rendering.threedee.opengl.error;
import retrograde.viewport;

import poodinis;

import derelict.opengl3.gl3;

import std.string;
import std.algorithm;
import std.experimental.logger;
import std.exception;

class OpenGl3RenderSystemInitException : Exception {
    this(string reason) {
        super("Could not initialize OpenGL render system: " ~ reason);
    }
}

class OpenGlRenderSystem : EntityProcessor {
    private const GLVersion minimumOpenGlVersion = GLVersion.GL45;
    private const string uniformModelViewProjectionName = "modelViewProjection";
    private const string uniformIsTexturedName = "isTextured";
    private static const uint[TextureFilterMode] textureFilterModeMapping;

    private GLVersion loadedOpenGlVersion;
    private UniformBlock _retrogradeFramestateBlock = new UniformBlock("RetrogradeFramestate");
    private UniformBlock _retrogradeModelstateBlock = new UniformBlock("RetrogradeModelstate");
    private Matrix4D projectionMatrix;
    private Entity cameraEntity;
    private GLuint globalSampler;
    private TextureFilterMode _globalTextureFilteringMode = TextureFilterMode.trilinear;
    private Viewport viewport;

    @Autowire
    private ShaderProgramFactory[] shaderProgramFactories;

    @Autowire
    private SharedUniformBlockBuilder sharedUniformBlockBuilder;

    @Autowire
    private Logger log;

    @Autowire
    private ErrorService errorService;

    @Autowire
    private ViewportFactory viewportFactory;

    public @property UniformBlock retrogradeFramestateBlock() {
        return _retrogradeFramestateBlock;
    }

    public @property UniformBlock retrogradeModelstateBlock() {
        return _retrogradeModelstateBlock;
    }

    public @property void globalTextureFilteringMode(TextureFilterMode textureFilterMode) {
        this._globalTextureFilteringMode = textureFilterMode;
        if (globalSampler) {
            glSamplerParameteri(globalSampler, GL_TEXTURE_MIN_FILTER, textureFilterModeMapping[globalTextureFilteringMode]);
            glSamplerParameteri(globalSampler, GL_TEXTURE_MAG_FILTER, textureFilterModeMapping[globalTextureFilteringMode]);
        }
    }

    public @property TextureFilterMode globalTextureFilteringMode() {
        return _globalTextureFilteringMode;
    }

    public static this() {
        textureFilterModeMapping = [
            TextureFilterMode.nearestNeighbor: GL_NEAREST,
            TextureFilterMode.linear: GL_LINEAR,
            TextureFilterMode.trilinear: GL_LINEAR_MIPMAP_LINEAR
        ];
    }

    public override void initialize() {
        viewport = viewportFactory.create();

        loadedOpenGlVersion = DerelictGL3.reload(minimumOpenGlVersion);

        //TODO: Log loaded GL version

        glEnable(GL_CULL_FACE);
        glEnable(GL_DEPTH_TEST);
        glDepthFunc(GL_LEQUAL);

        initializeShaderPrograms();
        initializeSamplers();
        updateProjectionMatrix(); // TODO: Only update on resize of window/context

        errorService.throwOnErrors!OpenGl3RenderSystemInitException;
    }

    private void initializeSamplers() {
        glCreateSamplers(1, &globalSampler);
        glSamplerParameteri(globalSampler, GL_TEXTURE_MIN_FILTER, textureFilterModeMapping[globalTextureFilteringMode]);
        auto magFilter = globalTextureFilteringMode == TextureFilterMode.trilinear ? GL_LINEAR : textureFilterModeMapping[globalTextureFilteringMode];
        glSamplerParameteri(globalSampler, GL_TEXTURE_MAG_FILTER, magFilter);
        glBindSampler(0, globalSampler);
    }

    private void initializeShaderPrograms() {
        foreach (factory; shaderProgramFactories) {
            auto shaderProgram = cast(OpenGlShaderProgram) factory.createShaderProgram();
            if (shaderProgram && !shaderProgram.isCompiled) {
                shaderProgram.compile();
            }
        }
    }

    protected override void processAcceptedEntity(Entity entity) {
        if (entity.hasComponent!CameraComponent) {
            cameraEntity = entity;
        }
    }

    protected override void processRemovedEntity(Entity entity) {
        if (entity is cameraEntity) {
            cameraEntity = null;
        }
    }

    public override void draw() {
        GLfloat[] clearColor = [0.25, 0.25, 0.25, 1];
        glClearBufferfv(GL_COLOR, 0, clearColor.ptr);
        glClearBufferfi(GL_DEPTH_STENCIL, 0, 1, 0);

        auto viewProjectionMatrix = projectionMatrix * createViewMatrix();

        foreach (entity; _entities.getAll()) {
            if (entity is cameraEntity) {
                continue;
            }

            auto position = entity.getFromComponent!Position3DComponent(c => c.position, Vector3D(0, 0, 0));
            auto orientation = entity.getFromComponent!OrientationR3Component(c => c.orientation, QuaternionD.nullRotation);
            auto scale = entity.getFromComponent!Scale3DComponent(c => c.scale, Vector3D(1, 1, 1));
            auto modelMatrix = position.toTranslationMatrix() * orientation.toRotationMatrix() * scale.toScalingMatrix();
            _retrogradeModelstateBlock.uniforms.set(Uniform(uniformModelViewProjectionName, viewProjectionMatrix * modelMatrix));

            auto model = cast(OpenGlModel) entity.getFromComponent!ModelComponent(c => c.model);
            if (!model.isLoadedIntoVram()) {
                model.loadIntoVram();
                errorService.logErrors();
            }

            bool hasTexture = false;
            if (entity.hasComponent!TextureComponent) {
                auto texture = cast(OpenGlTexture) entity.getFromComponent!TextureComponent(c => c.texture);
                if (texture) {
                    if (!texture.isLoadedIntoVram()) {
                        texture.loadIntoVram();
                        errorService.logErrors();
                    }

                    hasTexture = true;
                    texture.applyTexture();
                }
            }

            _retrogradeModelstateBlock.uniforms.set(Uniform(uniformIsTexturedName, hasTexture));

            if (entity.hasComponent!ShaderProgramComponent) {
                auto shaderProgram = cast(OpenGlShaderProgram) entity.getFromComponent!ShaderProgramComponent(c => c.shaderProgram);
                if (shaderProgram) {
                    useShaderProgram(shaderProgram);
                }
            } else {
                glUseProgram(0);
            }

            model.draw();
        }

        viewport.swapBuffers();
    }

    private Matrix4D createViewMatrix() {
        if (!cameraEntity) {
            return Matrix4D.identity;
        }

        auto position = cameraEntity.getFromComponent!Position3DComponent(c => c.position, Vector3D(0));

        if (cameraEntity.hasComponent!PitchYawComponent) {
            auto pitchYaw = cameraEntity.getFromComponent!PitchYawComponent(c => c.pitchYawVector);
            return createFirstPersonViewMatrix(position, pitchYaw.x, pitchYaw.y);
        }

        auto orientation = cameraEntity.getFromComponent!OrientationR3Component(c => c.orientation, QuaternionD.createRotation(0, standardUpVector.vector));
        return position.toTranslationMatrix() * orientation.toRotationMatrix();
    }

    private void useShaderProgram(OpenGlShaderProgram program) {
        foreach(uniformBlock; program.uniformBlocks) {
            if (uniformBlock is null) {
                continue;
            }

            try {
                sharedUniformBlockBuilder.buildData(uniformBlock, program);
            } catch (UniformBlockBuildException e) {
                log.error(e.msg);
            }

            program.bindUniformBlock(uniformBlock);
        }

        program.use();
    }

    public override void cleanup() {
        viewport.cleanup();
    }

    public override bool acceptsEntity(Entity entity) {
        if (entity.hasComponent!RenderableModelComponent && entity.hasComponent!ModelComponent) {
            auto model = cast(OpenGlModel) entity.getFromComponent!ModelComponent(c => c.model);
            return model !is null;
        }

        return entity.hasComponent!CameraComponent;
    }

    private void updateProjectionMatrix() {
        auto viewportDimensions = viewport.dimensions;
        double aspectRatio = cast(double) viewportDimensions.width / cast(double) viewportDimensions.height;
        //TODO: Make fov configurable
        projectionMatrix = createPerspectiveMatrix(45, aspectRatio, 0.1, 1_000);
    }

}

class OpenGlTexture : Texture {
    private RectangleU dimensions;
    private GLuint textureObject;
    private ubyte[] texelData;
    private bool loadedIntoVram = false;
    private bool generateMipMaps;

    this(ubyte[] texelData, RectangleU dimensions, bool generateMipMaps = true) {
        enforce!Exception(texelData.length % 4 == 0, "textelData should be aligned to 4-byte values (32bit). Does it contain the proper data format?");
        this.texelData = texelData;
        this.dimensions = dimensions;
        this.generateMipMaps = generateMipMaps;
    }

    public void loadIntoVram() {
        if (loadedIntoVram) return;

        glCreateTextures(GL_TEXTURE_2D, 1, &textureObject);
        glBindTexture(GL_TEXTURE_2D, textureObject);
        glTextureStorage2D(textureObject, 1, GL_RGBA8, dimensions.width, dimensions.height);
        glTextureSubImage2D(textureObject, 0, dimensions.x, dimensions.y, dimensions.width, dimensions.height, GL_RGBA, GL_UNSIGNED_BYTE, texelData.ptr);

        if (generateMipMaps) {
            glGenerateTextureMipmap(textureObject);
        }

        texelData = [];
        loadedIntoVram = true;
    }

    public bool isLoadedIntoVram() {
        return loadedIntoVram;
    }

    public void applyTexture() {
        glBindTexture(GL_TEXTURE_2D, textureObject);
    }

    public override RectangleU getTextureSize() {
        return dimensions;
    }

    public override string getName() {
        throw new Exception("Not yet implemented");
    }
}

}
