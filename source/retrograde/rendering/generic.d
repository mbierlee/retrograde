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
    Color;
import retrograde.core.entity : Entity, EntityCollection;
import retrograde.core.platform : Platform, Viewport, platformEventChannel, ViewportResizeEventMessage;
import retrograde.core.math : Matrix4D, scalar, createPerspectiveMatrix, createOrthographicMatrix, createViewMatrix,
    Vector3D, QuaternionD, toTranslationMatrix, toScalingMatrix;
import retrograde.core.messaging : MessageHandler;

import retrograde.components.rendering : RenderableComponent, CameraComponent, ActiveCameraComponent,
    ModelComponent, OrthoBackgroundComponent;
import retrograde.components.geometry : Position3DComponent, Orientation3DComponent, Scale3DComponent;

import poodinis : Autowire;

/** 
 * A general purpose 2D/3D render system suitable for most games.
 *
 * It uses an injected GraphicsApi to render graphics.
 */
class GenericRenderSystem : RenderSystem {
    private @Autowire Platform platform;
    private @Autowire GraphicsApi graphicsApi;
    private @Autowire MessageHandler messageHandler;

    private Viewport viewport;
    private CameraConfiguration cameraConfiguration;
    private Matrix4D projectionMatrix;
    private Color clearColor = Color(0.576f, 0.439f, 0.859f, 1.0f);

    private Entity activeCamera;
    private EntityCollection orthoBackgrounds = new EntityCollection();
    private EntityCollection models = new EntityCollection();

    override public void initialize() {
        viewport = platform.getViewport();
        updateView();
        graphicsApi.setClearColor(clearColor);
    }

    override public void update() {
        handleMessages();
    }

    override public void draw() {
        graphicsApi.clearAllBuffers();

        if (orthoBackgrounds.length > 0) {
            foreach (Entity orthoBackground; orthoBackgrounds) {
                graphicsApi.drawOrthoBackground(orthoBackground);
            }

            graphicsApi.clearDepthStencilBuffers();
        }

        if (activeCamera) {
            activeCamera.maybeWithComponent!CameraComponent((c) {
                if (cameraConfiguration != c.cameraConfiguration) {
                    cameraConfiguration = c.cameraConfiguration;
                    updateProjectionMatrix();
                }
            });
        }

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
            viewport = message.newViewport;
            updateView();
        });
    }

    private void updateView() {
        graphicsApi.updateViewport(viewport);
        updateProjectionMatrix();
    }

    private void updateProjectionMatrix() {
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
