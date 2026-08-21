/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.rendering;

import retrograde.assets.model : ModelComponentType, MaterialType;

import retrograde.engine.entity : addEntityFinalizedHook, addEntityRemovedHook, EntityId, forEachEntity,
    hasComponent, withComponentData;
import retrograde.engine.graphicsapi : clearShaderProgram, getViewport, initFrame, initRenderApi,
    initRenderPass, initMaterialShader, loadEntityModel, setClearColor, unloadEntityModel, useRenderPassShaderProgram;
import retrograde.engine.rendering.lighting : collectActiveLights, registerLightEntity,
    unregisterLightEntity;
import retrograde.engine.rendering.renderpass : genericModelRenderPass;
import retrograde.engine.rendering.materialshader : vertexColorsMaterialShader, unlitMaterialShader,
    pbrMetallicRoughnessMaterialShader, lambertMaterialShader;

import retrograde.std.collections : Array, HashMap;
import retrograde.std.geometry : OrientationComponentType, PositionComponentType;
import retrograde.std.math : createOrthographicMatrix, createPerspectiveMatrix, createViewMatrixQ,
    degreesToRadians, Matrix4, Quaternion, scalar, Vector3;
import retrograde.std.stringid : sid, StringId;

/// Given to entities that should be rendered by the renderer.
enum RenderableComponentType = sid("comp_renderable");

/// Given to entities that are acting as a camera for the renderer.
enum CameraComponentType = sid("comp_camera");

/// Given to entities that act as light
enum LightComponentType = sid("comp_light");

/** 
 * Constant used to indicate that a camera or render viewport should calculate the aspect ratio based on the platform's viewport.
 */
static const scalar autoAspectRatio = 0;

/** 
 * Type of projection to be used when rendering an active camera.
 * 
 * Projection determines how 3D world coordinates are mapped to 2D screen coordinates.
 * 
 * Orthographic projection maintains parallel lines and constant object sizes regardless
 * of distance from the camera. It's ideal for 2D games, CAD applications, isometric views,
 * and technical drawings where accurate measurements and proportions are important.
 * 
 * Perspective projection simulates realistic depth by making objects appear smaller as they
 * move farther from the camera. It's the standard choice for 3D games and applications
 * where realistic spatial representation is desired.
 */
enum ProjectionType {
    /// Orthographic projection - parallel lines stay parallel, no foreshortening
    ortographic,

    /// Perspective projection - simulates realistic depth with foreshortening
    perspective
}

/** 
 * Configuration of as 3D camera
 */
struct CameraConfiguration {
    //TODO: add enabled/disabled bool in case multiple entities have comp camera

    /// Y FOV in radians
    scalar horizontalFieldOfViewRadian = degreesToRadians(55);

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

    void setOrthographicProjectionDefaults() {
        nearClippingDistance = 0;
        farClippingDistance = 1000;
        projectionType = ProjectionType.ortographic;
    }
}

/**
 * Viewport dimensions, typically used by a renderer to determine framebuffer size.
 * 
 * The viewport defines the rectangular region of the rendering surface where graphics
 * will be drawn. It is used to calculate aspect ratios for camera projection matrices
 * and to configure the graphics API's rendering region.
 */
struct Viewport {
    /// X coordinate of the viewport's origin (typically left edge)
    int x;

    /// Y coordinate of the viewport's origin (typically top edge)
    int y;

    /// Width of the viewport in pixels
    int width;

    /// Height of the viewport in pixels
    int height;
}

/**
 * Initializes the renderer and graphics API.
 * 
 * Set up render passes before calling this function, otherwise the default render pass will be used.
 */
void initRenderer() {
    initRenderApi();
    setClearColor(Color(0, 0, 0, 1));
    initRenderPasses();
    initMaterialShaders();
    initEntityManagerHooks();
}

void renderFrame() {
    initFrame();
    collectActiveLights();

    Matrix4 viewMatrix;
    Matrix4 projectionMatrix;
    Vector3 position;
    Quaternion orientation;

    if (cameraEntity != 0) {
        cameraEntity.withComponentData!Vector3(PositionComponentType, (Vector3* p) {
            position = *p;
        });

        cameraEntity.withComponentData!Quaternion(OrientationComponentType, (Quaternion* o) {
            orientation = *o;
        });

        cameraEntity.withComponentData!CameraConfiguration(CameraComponentType, (
                CameraConfiguration* c) {
            projectionMatrix = createProjectionMatrix(*c);
        });
    }

    viewMatrix = createViewMatrixQ(position, orientation);
    const Matrix4 viewProjectionMatrix = projectionMatrix * viewMatrix;

    foreach (ref renderPass; renderPasses) {
        useRenderPassShaderProgram(renderPass);

        //TODO: Optimize? Don't attempt each entity in each pass, but batch them.
        forEachEntity((EntityId entity) {
            if (entity.hasComponent(RenderableComponentType) &&
            entity.hasComponent(renderPass.componentType)) {
                renderPass.render(entity, renderPass, viewProjectionMatrix);
            }
        });

        clearShaderProgram();
    }
}

private Matrix4 createProjectionMatrix(const ref CameraConfiguration cameraConfiguration) {
    auto viewport = getViewport();

    auto aspectRatio =
        cameraConfiguration.aspectRatio == autoAspectRatio ?
        cast(scalar) viewport.width / cast(scalar) viewport.height : cameraConfiguration
        .aspectRatio;

    if (cameraConfiguration.projectionType == ProjectionType.perspective) {
        return createPerspectiveMatrix(
            cameraConfiguration.horizontalFieldOfViewRadian,
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

    return Matrix4();
}

/**
 * A render pass represents a single rendering operation in the frame rendering pipeline.
 * 
 * Render passes are used to organize rendering by grouping entities with specific components
 * and rendering them with a particular shader program. During frame rendering, each render pass
 * is executed in sequence, processing all entities that have both the RenderableComponentType
 * and the pass's specific componentType.
 * 
 * This allows for flexible rendering pipelines where different types of objects (models, particles,
 * UI elements, etc.) can be rendered with different shaders and techniques.
 */
struct RenderPass {
    string passName;
    string vertexShader;
    string fragmentShader;
    StringId componentType;
    void delegate(EntityId entity, const ref RenderPass renderPass, const ref Matrix4 viewProjectionMatrix) render;
}

struct MaterialShader {
    string materialName;
    MaterialType materialType;
    string vertexShader;
    string fragmentShader;
}

Array!RenderPass renderPasses;

HashMap!(MaterialType, MaterialShader) materialShaders;

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

enum LightType {
    point
}

/**
 * A light source. Attach one to an entity together with a position component to have
 * it light the scene.
 *
 * The defaults make a plain `Light()` a working white point light: the world is metric
 * (one unit is one meter), and at the renderer's windowed inverse-square falloff an
 * intensity and radius of 10 behave like a bare room lamp. It is saturated out to about
 * 3 m, clearly falling off by 5 m, nearly dark at 8 m and exactly zero at its radius.
 */
struct Light {
    LightType lightType;

    /// Whether the light emits at all. A disabled light is skipped entirely.
    bool isEnabled = true;

    /// Color the light emits. Alpha is unused.
    Color color = Color(1, 1, 1, 1);

    /// Brightness/intensity modifier.
    /// Unit depends on the type of light.
    /// An intensity of 0 effectively disables the light.
    float intensity = 10;

    /// Radius in which the light operates.
    /// When outside of the radius, it has no effect.
    /// A radius of 0 effectively disables the light.
    float attenuationRadius = 10;
}

private EntityId cameraEntity = 0;

private void initRenderPasses() {
    if (renderPasses.length == 0) {
        renderPasses.add(genericModelRenderPass);
    }

    foreach (ref renderPass; renderPasses) {
        initRenderPass(renderPass);
    }
}

private void initMaterialShaders() {
    if (materialShaders.length == 0) {
        materialShaders.put(vertexColorsMaterialShader.materialType, vertexColorsMaterialShader);
        materialShaders.put(unlitMaterialShader.materialType, unlitMaterialShader);
        materialShaders.put(pbrMetallicRoughnessMaterialShader.materialType, pbrMetallicRoughnessMaterialShader);
        materialShaders.put(lambertMaterialShader.materialType, lambertMaterialShader);
    }

    foreach (ref materialShader; materialShaders.values) {
        initMaterialShader(materialShader);
    }
}

private void initEntityManagerHooks() {
    addEntityFinalizedHook((EntityId entity) {
        if (entity.hasComponent(ModelComponentType)) {
            loadEntityModel(entity);
        } else if (entity.hasComponent(CameraComponentType)) {
            cameraEntity = entity;
        }

        // Deliberately not chained onto the above: an entity is free to both render and emit light.
        if (entity.hasComponent(LightComponentType)) {
            registerLightEntity(entity);
        }
    });

    addEntityRemovedHook((EntityId entity) {
        if (cameraEntity == entity) {
            cameraEntity = 0;
        }

        unregisterLightEntity(entity);
        unloadEntityModel(entity);
    });
}
