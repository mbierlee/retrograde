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

module retrograde.engine.rendering;

import retrograde.std.collections : Array;
import retrograde.std.memory : SharedPtr;
import retrograde.std.stringid : sid, StringId;
import retrograde.std.math : degreesToRadians, scalar, Matrix4D, createViewMatrix, createPerspectiveMatrix,
    createOrthographicMatrix, Vector3D, QuaternionD;
import retrograde.std.geometry : PositionComponentType, OrientationComponentType;

import retrograde.engine.service : entityManager;
import retrograde.engine.entity : Entity;
import retrograde.engine.graphicsapi : initRenderApi, initRenderPass, setClearColor, initFrame, loadEntityModel,
    unloadEntityModel, useRenderPassShaderProgram, drawModel, clearShaderProgram, getViewport;

import retrograde.data.model : ModelComponentType;

enum RenderableComponentType = sid("comp_renderable");

enum CameraComponentType = sid("comp_camera");

/** 
 * Constant used to indicate that a camera or render viewport should calculate the aspect ratio based on the platform's viewport.
 */
static const scalar autoAspectRatio = 0;

/** 
 * Type of projection to be used when rendering an active camera.
 */
enum ProjectionType {
    ortographic,
    perspective
}

/** 
 * Configuration of as 3D camera
 */
struct CameraConfiguration {
    /// Y FOV in radians
    scalar horizontalFieldOfView = degreesToRadians(55);

    /// Aspect ratio (width over height).
    scalar aspectRatio = autoAspectRatio;

    /**
     * Near clipping plane. 
     * Should be higher than 0 in perspective cameras.
     * Use setOrthographicProjectionDefaults to set sensible defaults for ortho projection.
     */
    scalar nearClippingDistance = 0.1;

    /**
     * Far clipping plane. 
     * If 0, it is considered infinite.
     * Note that infinite clipping planes only work in perspective cameras,
     * not orthographic. Use setOrthographicProjectionDefaults to set sensible defaults.
     */
    scalar farClippingDistance = 0;

    /// Type of project of camera
    ProjectionType projectionType = ProjectionType.perspective;

    /// Scaling applied when the projection type is orthographic.
    scalar orthoScale = 1;

    this(ref return scope inout typeof(this) other) {
        this.horizontalFieldOfView = other.horizontalFieldOfView;
        this.aspectRatio = other.aspectRatio;
        this.nearClippingDistance = other.nearClippingDistance;
        this.farClippingDistance = other.farClippingDistance;
        this.projectionType = other.projectionType;
        this.orthoScale = other.orthoScale;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        this.horizontalFieldOfView = other.horizontalFieldOfView;
        this.aspectRatio = other.aspectRatio;
        this.nearClippingDistance = other.nearClippingDistance;
        this.farClippingDistance = other.farClippingDistance;
        this.projectionType = other.projectionType;
        this.orthoScale = other.orthoScale;
    }

    void setOrthographicProjectionDefaults() {
        nearClippingDistance = 0;
        farClippingDistance = 1000;
        projectionType = ProjectionType.ortographic;
    }
}

/**
 * Viewport dimensions, typically used by a renderer to determine framebuffer size.
 */
struct Viewport {
    int x;
    int y;
    int width;
    int height;
}

void initRenderer() {
    initRenderApi();
    setClearColor(Color(0, 0, 0, 1));
    initRenderPasses();
    initEntityManagerHooks();
}

void renderFrame() {
    initFrame();

    Matrix4D viewMatrix;
    Matrix4D projectionMatrix;
    Vector3D position;
    QuaternionD orientation;

    if (cameraEntity.isDefined()) {
        auto maybePosition = cameraEntity.ptr.getComponentData!Vector3D(PositionComponentType);
        if (maybePosition.isDefined()) {
            position = *maybePosition.value.ptr;
        }

        auto maybeOrientation = cameraEntity.ptr.getComponentData!QuaternionD(
            OrientationComponentType);
        if (maybeOrientation.isDefined()) {
            orientation = *maybeOrientation.value.ptr;
        }

        auto maybeCameraConfiguration = cameraEntity.ptr.getComponentData!CameraConfiguration(
            CameraComponentType);
        if (maybeCameraConfiguration.isDefined()) {
            projectionMatrix = createProjectionMatrix(*maybeCameraConfiguration.value.ptr);
        }

    }

    viewMatrix = createViewMatrix(position, orientation);
    const Matrix4D viewProjectionMatrix = projectionMatrix * viewMatrix;

    foreach (ref renderPass; renderPasses) {
        useRenderPassShaderProgram(renderPass);

        //TODO: Optimize? Don't attempt each entity in each pass, but batch them.
        entityManager.forEachEntity((SharedPtr!Entity entity) {
            if (entity.ptr.hasComponent(RenderableComponentType) &&
            entity.ptr.hasComponent(renderPass.componentType)) {
                renderPass.render(entity, renderPass, viewProjectionMatrix);
            }
        });

        clearShaderProgram();
    }
}

private Matrix4D createProjectionMatrix(const ref CameraConfiguration cameraConfiguration) {
    auto viewport = getViewport();

    auto aspectRatio =
        cameraConfiguration.aspectRatio == autoAspectRatio ?
        cast(scalar) viewport.width / cast(scalar) viewport.height : cameraConfiguration
        .aspectRatio;

    if (cameraConfiguration.projectionType == ProjectionType.perspective) {
        return createPerspectiveMatrix(
            cameraConfiguration.horizontalFieldOfView,
            aspectRatio,
            cameraConfiguration.nearClippingDistance,
            cameraConfiguration.farClippingDistance
        );
    }

    if (cameraConfiguration.projectionType == ProjectionType.ortographic) {
        return createOrthographicMatrix(
            -(aspectRatio * cameraConfiguration.orthoScale),
            aspectRatio * cameraConfiguration.orthoScale,
            -cameraConfiguration.orthoScale,
            cameraConfiguration.orthoScale,
            cameraConfiguration.nearClippingDistance,
            cameraConfiguration.farClippingDistance
        );
    }

    return Matrix4D();
}

struct RenderPass {
    string passName;
    string vertexShader;
    string fragmentShader;
    StringId componentType;
    void delegate(SharedPtr!Entity entity, const ref RenderPass renderPass, const ref Matrix4D viewProjectionMatrix) render;

    SharedPtr!void apiData;

    this(ref return scope inout typeof(this) other) {
        this.passName = other.passName;
        this.vertexShader = other.vertexShader;
        this.fragmentShader = other.fragmentShader;
        this.componentType = other.componentType;
        this.render = other.render;
        this.apiData = other.apiData;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        this.passName = other.passName;
        this.vertexShader = other.vertexShader;
        this.fragmentShader = other.fragmentShader;
        this.componentType = other.componentType;
        this.render = other.render;
        this.apiData = other.apiData;
    }
}

RenderPass genericModelRenderPass = RenderPass(
    "generic",
    import("opengles3/generic_model_vertex.glsl"),
    import("opengles3/generic_model_fragment.glsl"),
    ModelComponentType,
    (SharedPtr!Entity entity, const ref RenderPass renderPass, const ref Matrix4D viewProjectionMatrix) {
    drawModel(entity, viewProjectionMatrix, renderPass);
}
);

Array!RenderPass renderPasses;

struct Color {
    /// Red
    float r;

    /// Green
    float g;

    /// Blue
    float b;

    /// Alpha
    float a;
}

private SharedPtr!Entity cameraEntity;

private void initRenderPasses() {
    if (renderPasses.length == 0) {
        renderPasses.add(genericModelRenderPass);
    }

    foreach (ref renderPass; renderPasses) {
        initRenderPass(renderPass);
    }
}

private void initEntityManagerHooks() {
    entityManager.addEntityAddedHook((SharedPtr!Entity entity) {
        if (entity.hasComponent(ModelComponentType)) {
            loadEntityModel(entity);
        } else if (entity.hasComponent(CameraComponentType)) {
            cameraEntity = entity;
        }
    });

    entityManager.addEntityRemovedHook((SharedPtr!Entity entity) {
        if (cameraEntity == entity) {
            cameraEntity = null;
        }

        unloadEntityModel(entity);
    });
}
