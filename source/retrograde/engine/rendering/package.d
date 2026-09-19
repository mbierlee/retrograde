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
import retrograde.engine.geometry : worldPositionOf;
import retrograde.engine.graphicsapi : clearShaderProgram, getViewport, initFrame, initRenderApi,
    initRenderPass, initMaterialShader, initShadowMaps, loadEntityModel, setClearColor,
    unloadEntityModel, useRenderPassShaderProgram;
import retrograde.engine.rendering.lighting : collectActiveLights, registerLightEntity,
    unregisterLightEntity;
import retrograde.engine.rendering.renderpass : genericModelRenderPass;
import retrograde.engine.rendering.materialshader : maxShadowViews, vertexColorsMaterialShader,
    unlitMaterialShader, pbrMetallicRoughnessMaterialShader, lambertMaterialShader;

static if (maxShadowViews > 0) {
    import retrograde.engine.rendering.renderpass : shadowMapRenderPass;
}

import retrograde.std.collections : Array, HashMap;
import retrograde.std.geometry : Frustum, OrientationComponentType;
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

    // After the passes, which is what says whether the maps are worth allocating, and before
    // the material shaders, which bind the sampler that reads them.
    initShadowMaps(shadowMapsAreRendered());

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
        position = cameraEntity.worldPositionOf();

        cameraEntity.withComponentData!Quaternion(OrientationComponentType, (Quaternion* o) {
            orientation = *o;
        });

        cameraEntity.withComponentData!CameraConfiguration(CameraComponentType, (
                CameraConfiguration* c) {
            activeCameraConfiguration = *c;
            projectionMatrix = createProjectionMatrix(*c);
        });
    }

    activeCameraWorldPosition = position;
    activeCameraOrientation = orientation;
    activeCameraViewport = getViewport();

    viewMatrix = createViewMatrixQ(position, orientation);
    const Matrix4 viewProjectionMatrix = projectionMatrix * viewMatrix;
    activeCameraFrustum = Frustum.fromViewProjection(viewProjectionMatrix);

    RenderView cameraView;
    cameraView.viewProjectionMatrix = viewProjectionMatrix;
    cameraView.frustum = activeCameraFrustum;
    cameraView.eyePosition = position;

    foreach (ref renderPass; renderPasses) {
        useRenderPassShaderProgram(renderPass);

        // Gathered once and drawn from every view of the pass: a pass that draws the world
        // several times over - a shadow pass, once per casting light - would otherwise walk
        // every entity in the world again for each of them.
        //TODO: Optimize? Don't attempt each entity in each pass, but batch them.
        passEntities.truncate(0);
        forEachEntity((EntityId entity) {
            if (entity.hasComponent(RenderableComponentType) &&
            entity.hasComponent(renderPass.componentType)) {
                passEntities.add(entity);
            }
        });

        passViews.truncate(0);
        if (renderPass.beginPass !is null) {
            renderPass.beginPass(passViews);
        } else {
            passViews.add(cameraView);
        }

        foreach (ref view; passViews) {
            if (renderPass.beginView !is null) {
                renderPass.beginView(view);
            }

            foreach (entity; passEntities) {
                renderPass.render(entity, renderPass, view);
            }
        }

        if (renderPass.endPass !is null) {
            renderPass.endPass();
        }

        clearShaderProgram();
    }
}

// Reused between passes and frames, so a steady scene stops allocating after the first frame.
private Array!EntityId passEntities;
private Array!RenderView passViews;

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
    void delegate(EntityId entity, const ref RenderPass renderPass, const ref RenderView view) render;

    /**
     * Optional. Called once before any view, and fills the views this pass draws this frame.
     *
     * A pass that leaves this null draws the active camera's view, once, which is what an
     * ordinary pass wants. One that fills several - a shadow pass, one per casting light -
     * has its entities drawn once per view.
     */
    void delegate(ref Array!RenderView views) beginPass;

    /**
     * Optional. Called before each view, and makes what that view draws into current: its
     * framebuffer and layer, its viewport, and whatever it needs cleared.
     */
    void delegate(const ref RenderView view) beginView;

    /**
     * Optional. Called once after the last view, and puts back whatever $(D beginView)
     * changed, so the pass after this one draws to the screen as it expects to.
     *
     * There is deliberately no per-view counterpart: the next $(D beginView) makes its own
     * target current, so a view has nothing to undo.
     */
    void delegate() endPass;
}

/**
 * One point of view the world is drawn from in a frame.
 *
 * Ordinarily that is the active camera's, but a pass may draw the same entities from
 * somewhere else entirely - a shadow pass draws them as each casting light sees them.
 */
struct RenderView {
    /// Combined view and projection of this point of view.
    Matrix4 viewProjectionMatrix;

    /// What this point of view sees, in world space. Entities outside it are not drawn.
    Frustum frustum;

    /// Where this point of view sits in the world.
    Vector3 eyePosition;

    /// Which layer of the shadow map array this view renders into. Unused by a camera view.
    uint targetLayer;
}

struct MaterialShader {
    string materialName;
    MaterialType materialType;
    string vertexShader;
    string fragmentShader;
}

Array!RenderPass renderPasses;

HashMap!(MaterialType, MaterialShader) materialShaders;

/// Where the camera of the frame being rendered sits in the world.
Vector3 activeCameraWorldPosition;

/// Which way the camera of the frame being rendered faces.
Quaternion activeCameraOrientation;

/// How the camera of the frame being rendered projects the world.
CameraConfiguration activeCameraConfiguration;

/// The viewport the frame being rendered is sized to, which is what a camera without an
/// aspect ratio of its own derives one from.
Viewport activeCameraViewport;

/// What the camera of the frame being rendered sees, in world space. Entities whose bounds
/// fall outside it are not drawn while $(D frustumCullingEnabled) is set.
Frustum activeCameraFrustum;

/**
 * Whether entities whose bounds fall outside the active camera's frustum are skipped.
 *
 * On by default. Turn it off to draw everything regardless of where the camera looks, which
 * is useful when an entity is missing and the bounds it was culled by are suspect: a model
 * whose bounds do not cover its vertices is culled while still on screen, and this tells
 * that apart from it not being drawn at all.
 */
bool frustumCullingEnabled = true;

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
    /// Shines in every direction from where its entity is positioned, falling off with distance.
    point,

    /// Shines the same everywhere, along the direction its entity is oriented in. A sun.
    directional
}

/**
 * A light source. Attach one to an entity to have it light the scene.
 *
 * Where the light shines from comes from the entity, not from here: a point light is
 * placed by its position component, a directional light aimed by its orientation
 * component - along that orientation's negative Z axis, the way everything else in the
 * engine faces. A directional light without an orientation shines along the world's
 * negative Z axis.
 *
 * The defaults make a plain `Light()` a working white point light: the world is metric
 * (one unit is one meter), and at the renderer's windowed inverse-square falloff an
 * intensity of 30 over a radius of 10 behaves like a bare room lamp. It is saturated out
 * to about 3 m, clearly falling off by 5 m, nearly dark at 8 m and exactly zero at its
 * radius.
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
    ///
    /// The lit materials divide their diffuse response by pi, so this default carries the
    /// factor of pi that keeps a plain `Light()` as bright as the description above.
    ///
    /// A directional light has no falloff to dim it, so what it emits is what every lit
    /// surface receives: for one of those the factor of pi is the whole of it, and an
    /// intensity of about 3 lights a white surface facing it to full brightness.
    float intensity = 30;

    /// Radius in which the light operates.
    /// When outside of the radius, it has no effect.
    /// A radius of 0 effectively disables the light.
    ///
    /// Only read for a point light: a directional light reaches everything whatever this says.
    float attenuationRadius = 10;

    /**
     * Whether this light casts shadows.
     *
     * Off by default: a casting light has the scene's casters drawn again from where it
     * stands - six times over for a point light - so it is worth opting in to deliberately
     * rather than paying for by surprise. A light that casts nothing still lights everything
     * it reaches; what it loses is only that other things block it.
     *
     * Needs the shadow render pass to be registered. Without it this is read by nothing and
     * costs nothing.
     */
    bool castsShadows = false;
}

private EntityId cameraEntity = 0;

private void initRenderPasses() {
    if (renderPasses.length == 0) {
        static if (maxShadowViews > 0) {
            // Before the pass that draws lit surfaces: a shadow map has to be complete before
            // anything samples it.
            renderPasses.add(shadowMapRenderPass);
        }

        renderPasses.add(genericModelRenderPass);
    }

    foreach (ref renderPass; renderPasses) {
        initRenderPass(renderPass);
    }
}

/**
 * Whether any registered pass renders shadow maps.
 *
 * What the maps cost is only worth paying where something draws them, and a game is free to
 * set up its passes without the shadow pass.
 */
private bool shadowMapsAreRendered() {
    static if (maxShadowViews > 0) {
        foreach (ref renderPass; renderPasses) {
            if (renderPass.passName.sid == shadowMapRenderPass.passName.sid) {
                return true;
            }
        }
    }

    return false;
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
