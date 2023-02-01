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

module retrograde.rendering.generic;

import retrograde.core.rendering : RenderSystem, GraphicsApi, autoAspectRatio, CameraConfiguration, ProjectionType,
    Color, TextureFilteringMode;
import retrograde.core.entity : Entity, EntityCollection;
import retrograde.core.platform : Platform, Viewport, platformEventChannel, ViewportResizeEventMessage;
import retrograde.core.math : Matrix4D, scalar, createPerspectiveMatrix, createOrthographicMatrix, createViewMatrix,
    Vector3D, QuaternionD, toTranslationMatrix, toScalingMatrix;
import retrograde.core.messaging : MessageHandler;

import retrograde.components.rendering : RenderableComponent, CameraComponent, ActiveCameraComponent,
    ModelComponent, OrthoBackgroundComponent;
import retrograde.components.geometry : Position3DComponent, Orientation3DComponent, Scale3DComponent;

import poodinis : Autowire;

import std.conv : to;
import std.math.rounding : ceil;

/** 
 * A general purpose 2D/3D render system suitable for most games.
 *
 * It uses an injected GraphicsApi to render graphics.
 */
class GenericRenderSystem : RenderSystem {
    private @Autowire Platform platform;
    private @Autowire GraphicsApi graphicsApi;
    private @Autowire MessageHandler messageHandler;

    private Viewport platformViewport;
    private CameraConfiguration cameraConfiguration;
    private Matrix4D projectionMatrix;
    private scalar _viewportAspectRatio = autoAspectRatio;
    private TextureFilteringMode _defaultMinificationTextureFilteringMode;
    private TextureFilteringMode _defaultMagnificationTextureFilteringMode;

    private Entity activeCamera;
    private EntityCollection orthoBackgrounds = new EntityCollection();
    private EntityCollection models = new EntityCollection();

    public Color clearColor = Color(0f, 0f, 0f, 1.0f);

    /**
     * Get the aspect ratio of the renderer's viewport.
     */
    public @property scalar viewportAspectRatio() {
        return _viewportAspectRatio;
    }

    /**
     * Set the aspect ratio of the renderer's viewport.
     *
     * The renderer's viewport will automatically be adjusted to maintain aspect ratio when
     * the platform's viewport is resized. Set to 'autoAspectRatio' or 0 to disable this
     * autocorrection and use the platform's viewport ascpect ratio instead.
     */
    public @property void viewportAspectRatio(scalar newRatio) {
        _viewportAspectRatio = newRatio;
        updateView();
    }

    /** 
     * Gets the default minification texture filtering mode.
     */
    public @property TextureFilteringMode defaultMinificationTextureFilteringMode() {
        return _defaultMinificationTextureFilteringMode;
    }

    /** 
     * Sets the default minification texture filtering mode.
     * If TextureFilteringMode.globalDefault is set it is up to the graphics API to 
     * decide what is considered as default.
     */
    public @property void defaultMinificationTextureFilteringMode(
        TextureFilteringMode textureFilteringMode) {
        _defaultMinificationTextureFilteringMode = textureFilteringMode;
        graphicsApi.setDefaultTextureFilteringModes(textureFilteringMode, _defaultMagnificationTextureFilteringMode);
    }

    /** 
     * Gets the default magnification texture filtering mode.
     */
    public @property TextureFilteringMode defaultMagnificationTextureFilteringMode() {
        return _defaultMagnificationTextureFilteringMode;
    }

    /** 
     * Sets the default magnification texture filtering mode.
     * If TextureFilteringMode.globalDefault is set it is up to the graphics API to 
     * decide what is considered as default.
     */
    public @property void defaultMagnificationTextureFilteringMode(
        TextureFilteringMode textureFilteringMode) {
        _defaultMagnificationTextureFilteringMode = textureFilteringMode;
        graphicsApi.setDefaultTextureFilteringModes(_defaultMinificationTextureFilteringMode, textureFilteringMode);
    }

    override public void initialize() {
        defaultMinificationTextureFilteringMode = TextureFilteringMode.linear;
        defaultMagnificationTextureFilteringMode = TextureFilteringMode.linear;
        platformViewport = platform.getViewport();
        updateView();
        graphicsApi.setClearColor(clearColor);
    }

    override public void update() {
        handleMessages();
    }

    override public void draw() {
        graphicsApi.clearAllBuffers();

        if (orthoBackgrounds.length > 0) {
            graphicsApi.useDefaultBackgroundShader();
            foreach (Entity orthoBackground; orthoBackgrounds) {
                graphicsApi.drawOrthoBackground(orthoBackground);
            }

            graphicsApi.clearDepthStencilBuffers();
        }

        if (activeCamera) {
            activeCamera.maybeWithComponent!CameraComponent((c) {
                if (cameraConfiguration != c.cameraConfiguration) {
                    cameraConfiguration = c.cameraConfiguration;
                    auto renderViewport = createRenderViewport(platformViewport);
                    updateProjectionMatrix(renderViewport);
                }
            });
        }

        graphicsApi.useDefaultModelShader();
        auto viewProjectionMatrix = projectionMatrix * createRenderViewMatrix();
        foreach (Entity model; models) {
            auto modelViewProjectionMatrix = createModelViewProjectionMatrix(model, viewProjectionMatrix);
            graphicsApi.drawModel(model, modelViewProjectionMatrix);
        }
    }

    override public bool acceptsEntity(Entity entity) {
        return entity.hasComponent!RenderableComponent ||
            (entity.hasComponent!CameraComponent && entity.hasComponent!ActiveCameraComponent);
    }

    override protected void processAcceptedEntity(Entity entity) {
        if (entity.hasComponent!ActiveCameraComponent) {
            activeCamera = entity;
        }

        if (entity.hasComponent!RenderableComponent) {
            if (entity.hasComponent!OrthoBackgroundComponent) {
                orthoBackgrounds.add(entity);
            }

            if (entity.hasComponent!ModelComponent) {
                models.add(entity);
            }

            graphicsApi.loadIntoMemory(entity);

            entity.maybeWithComponent!ModelComponent((c) {
                if (c.removeWhenLoadedIntoVideoMemory) {
                    entity.removeComponent!ModelComponent;
                }
            });

            //TODO: Remove textures when loaded in memory
        }
    }

    override protected void processRemovedEntity(Entity entity) {
        if (activeCamera == entity) {
            activeCamera = null;
        }

        if (entity.hasComponent!RenderableComponent) {
            if (entity.hasComponent!OrthoBackgroundComponent) {
                orthoBackgrounds.remove(entity);
            }

            if (entity.hasComponent!ModelComponent) {
                models.remove(entity);
            }

            graphicsApi.unloadFromVideoMemory(entity);
        }
    }

    private void handleMessages() {
        messageHandler.receiveMessages(platformEventChannel, (
                immutable ViewportResizeEventMessage message) {
            platformViewport = message.newViewport;
            updateView();
        });
    }

    private void updateView() {
        auto renderViewport = createRenderViewport(platformViewport);
        graphicsApi.updateViewport(renderViewport);
        updateProjectionMatrix(renderViewport);
    }

    private Viewport createRenderViewport(const Viewport viewport) {
        auto newViewport = cast(Viewport) viewport;

        if (viewportAspectRatio != autoAspectRatio) {
            import std.stdio;

            if (viewport.width > viewport.height) {
                newViewport.width = ceil(viewport.height * viewportAspectRatio).to!int;
                if (newViewport.width > viewport.width) {
                    newViewport.height = ceil(viewport.width / viewportAspectRatio).to!int;
                    newViewport.width = ceil(newViewport.height * viewportAspectRatio).to!int;
                }
            } else if (viewport.height > viewport.width) {
                newViewport.height = ceil(viewport.width / viewportAspectRatio).to!int;
            }

            newViewport.x = ceil((viewport.width - newViewport.width) / 2.0).to!int;
            newViewport.y = ceil((viewport.height - newViewport.height) / 2.0).to!int;
        }

        return newViewport;
    }

    private void updateProjectionMatrix(Viewport viewport) {
        auto aspectRatio =
            cameraConfiguration.aspectRatio == autoAspectRatio ?
            cast(scalar) viewport.width / cast(scalar) viewport.height
            : cameraConfiguration.aspectRatio;

        if (cameraConfiguration.projectionType == ProjectionType.perspective) {
            projectionMatrix = createPerspectiveMatrix(
                cameraConfiguration.horizontalFieldOfView,
                aspectRatio,
                cameraConfiguration.nearClippingDistance,
                cameraConfiguration.farClippingDistance
            );
        } else if (cameraConfiguration.projectionType == ProjectionType.ortographic) {
            projectionMatrix = createOrthographicMatrix(
                -(aspectRatio * cameraConfiguration.orthoScale),
                aspectRatio * cameraConfiguration.orthoScale,
                -cameraConfiguration.orthoScale,
                cameraConfiguration.orthoScale,
                cameraConfiguration.nearClippingDistance,
                cameraConfiguration.farClippingDistance
            );
        }
    }

    private Matrix4D createRenderViewMatrix() {
        if (!activeCamera) {
            return Matrix4D.identity;
        }

        auto position =
            activeCamera.getFromComponent!Position3DComponent(c => c.position, Vector3D(0));

        auto orientation =
            activeCamera.getFromComponent!Orientation3DComponent(c => c.orientation, QuaternionD());

        return createViewMatrix(position, orientation);
    }

    private Matrix4D createModelViewProjectionMatrix(Entity entity, Matrix4D viewProjectionMatrix) {
        auto position = entity.getFromComponent!Position3DComponent(c => c.position,
            Vector3D(0));
        auto orientation = entity.getFromComponent!Orientation3DComponent(c => c.orientation, QuaternionD());
        auto scale = entity.getFromComponent!Scale3DComponent(c => c.scale,
            Vector3D(1));

        auto modelMatrix = position.toTranslationMatrix() * orientation.toRotationMatrix() * scale.toScalingMatrix();
        auto modelViewProjectionMatrix = viewProjectionMatrix * modelMatrix;
        return modelViewProjectionMatrix;
    }
}
