/**
 * Retrograde Engine
 *
 * Shadow mapping: deciding what each shadow-casting light needs to see.
 *
 * A shadow map is the scene's depth as a light sees it. A surface is in shadow when something
 * else was nearer to the light along the same ray, which is a depth comparison the sampler
 * hardware does. This module works out the points of view those depths are rendered from; the
 * graphics API renders and samples them.
 *
 * Every map of a frame lives in one layer of a single array texture, and every light type is
 * described the same way: a first layer plus a count of views. A directional light takes one
 * view, a point light six - one per cube face - and a spot light would take one. The array is
 * what lets a shader reach any light's map: GLSL ES 3.00 forbids indexing an array of samplers
 * with a loop variable, so a per-light sampler could not be looked up in the shading loop,
 * while a layer of one array can.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.rendering.shadow;

import retrograde.engine.rendering : activeCameraConfiguration, activeCameraOrientation,
    activeCameraViewport, activeCameraWorldPosition, autoAspectRatio, CameraConfiguration,
    LightType, ProjectionType, RenderView, Viewport;
import retrograde.engine.rendering.lighting : ActiveLight, activeLights;
import retrograde.engine.rendering.materialshader : maxShadowViews;

import retrograde.std.collections : Array;
import retrograde.std.geometry : Frustum;
import retrograde.std.math : atan2, createOrthographicMatrix, createPerspectiveMatrix,
    createViewMatrixQ, degreesToRadians, Matrix4, maxOf, minOf, Quaternion, scalar, tan,
    Vector3, Vector4;

/**
 * How shadows are rendered. Every setting can be changed at any time; a change takes effect
 * on the next frame.
 */
struct ShadowSettings {
    /**
     * Width and height in texels of every shadow map.
     *
     * The one quality dial: a map covers a fixed piece of the world, so more texels is a
     * sharper shadow edge. It costs `mapSize * mapSize * maxShadowViews * 3` bytes of depth
     * storage - 25 MB at the default over a budget of 8 views, 100 MB at 2048 - which is why
     * the default is the modest size rather than the good-looking one. Raise it where the
     * memory budget is known, such as a native build or a game that has measured its own.
     *
     * Changing it rebuilds the maps at the start of the next frame, since a texture's
     * allocation cannot be resized in place. A size of 0 is treated as 1.
     */
    uint mapSize = 1024;

    /**
     * How far from the camera a directional light's shadows reach, in world units.
     *
     * A directional light shines over the whole world, so something has to say which part of
     * it is worth spending a map on. Its map covers the camera's view up to this distance;
     * past it, surfaces are lit as if nothing blocked the light. Raising it shadows more of
     * the view at the cost of spreading the same texels over more world, making the shadow's
     * edges more aliased.
     *
     * It also sets how far behind that volume casters are still drawn, so a wall just out of
     * view still casts into it.
     */
    scalar distance = 50;

    /**
     * Depth offsets applied while drawing casters, countering the self-shadowing that a
     * surface's own depth causes when its map texel is compared against itself.
     *
     * The slope term scales with how steeply a surface is turned away from the light, which
     * is where the error is largest; the constant term is a flat offset in depth units. Too
     * little leaves acne - dark stripes over lit surfaces - and too much makes shadows
     * detach from what casts them.
     */
    scalar slopeBias = 2;

    /// ditto
    scalar constantBias = 4;

    /**
     * How far a receiving surface's lookup is pushed along its own normal, in world units.
     *
     * Complements the depth biases above: they work in the map's depth, this works across
     * its surface, which is what remedies acne on a surface facing the light edge-on. Scaled
     * by how steeply the light hits, so a surface facing the light straight on is untouched.
     */
    scalar normalBias = 0.02;
}

/// How shadows are rendered this frame. See $(D ShadowSettings).
ShadowSettings shadowSettings;

/**
 * The points of view this frame's shadow maps are rendered from, one per map layer.
 *
 * Filled by $(D prepareShadowViews) at the start of the shadow pass, and read by the graphics
 * API to render each map and to tell receiving surfaces where each map looks from. Empty when
 * no light casts, which is the usual case for a scene that never opted in.
 */
Array!RenderView shadowViews;

/**
 * Turns clip space into the [0, 1] range a shadow map is sampled in.
 *
 * A view projection lands on [-1, 1] in every axis, while a texture lookup and a depth
 * comparison both want [0, 1]. Folding the conversion in here keeps it out of the shader,
 * which would otherwise do it per light per fragment.
 */
// dfmt off
static immutable Matrix4 shadowBiasMatrix = Matrix4(
    0.5, 0,   0,   0.5,
    0,   0.5, 0,   0.5,
    0,   0,   0.5, 0.5,
    0,   0,   0,   1
);
// dfmt on

/**
 * The direction the given face of a point light's cube of maps looks in, in the order
 * +X, -X, +Y, -Y, +Z, -Z.
 *
 * That order is what a receiving shader picks a face by, so it cannot be changed on one side
 * alone. Each face looks along its axis: an orientation faces its own negative Z, so the one
 * facing +X turns -90 degrees about Y, and so on.
 *
 * Returned one at a time rather than as an array of six because a local array of quaternions
 * has to be filled with a default that is not all zero bits, which needs a runtime this
 * build does not have. See `docs/betterc-pitfalls.md`.
 */
private Quaternion cubeFaceOrientation(const size_t face) {
    if (face == 0) {
        return Quaternion.createRotation(degreesToRadians(-90), Vector3(0, 1, 0));
    }

    if (face == 1) {
        return Quaternion.createRotation(degreesToRadians(90), Vector3(0, 1, 0));
    }

    if (face == 2) {
        return Quaternion.createRotation(degreesToRadians(90), Vector3(1, 0, 0));
    }

    if (face == 3) {
        return Quaternion.createRotation(degreesToRadians(-90), Vector3(1, 0, 0));
    }

    if (face == 4) {
        return Quaternion.createRotation(degreesToRadians(180), Vector3(0, 1, 0));
    }

    return Quaternion();
}

/// How many map layers a light of the given type needs.
uint shadowViewCountOf(const LightType lightType) {
    return lightType == LightType.point ? 6 : 1;
}

/**
 * Picks this frame's shadow-casting lights and works out the view each of their maps is
 * rendered from.
 *
 * Fills `views` and $(D shadowViews) alike, and stamps every chosen light in $(D activeLights)
 * with the layer its map starts at, so that a surface picking its lights later can tell which
 * map belongs to which. A light that is not chosen keeps the $(D ActiveLight) default of no
 * map at all, and is shaded unshadowed.
 *
 * Lights are taken in a fixed order - directional first, then point lights nearest the camera -
 * rather than in whatever order they were collected in, so that a budget too small for every
 * caster drops the same lights every frame instead of flickering between them.
 */
void prepareShadowViews(ref Array!RenderView views) {
    views.truncate(0);
    shadowViews.truncate(0);

    static if (maxShadowViews > 0) {
        foreach (i; 0 .. activeLights.length) {
            ActiveLight light = activeLights[i];
            light.shadowView = -1;
            light.shadowViewCount = 0;
            activeLights.replace(i, light);
        }

        foreach (pass; 0 .. 2) {
            // Directional lights in the first pass, point lights in the second: the sun is
            // what a scene misses most when the budget runs out.
            bool wantDirectional = pass == 0;

            while (true) {
                auto candidate = nextCaster(wantDirectional, views.length);
                if (candidate < 0) {
                    break;
                }

                ActiveLight light = activeLights[candidate];
                uint viewCount = shadowViewCountOf(light.light.lightType);
                light.shadowView = cast(int) views.length;
                light.shadowViewCount = cast(int) viewCount;
                activeLights.replace(candidate, light);

                if (light.light.lightType == LightType.directional) {
                    appendView(views, directionalShadowView(light.direction));
                } else {
                    appendPointViews(views, light.position, light.light.attenuationRadius);
                }
            }
        }
    }
}

/**
 * The still-unchosen caster that should take the next slot, or -1 when none fits.
 *
 * Point lights are ordered by distance to the camera so that the lights whose shadows are
 * most visible are the ones that get maps.
 */
private ptrdiff_t nextCaster(const bool wantDirectional, const size_t usedViews) {
    ptrdiff_t best = -1;
    scalar bestDistance = 0;

    foreach (i; 0 .. activeLights.length) {
        ActiveLight candidate = activeLights[i];
        if (!candidate.light.castsShadows || candidate.shadowViewCount > 0) {
            continue;
        }

        bool isDirectional = candidate.light.lightType == LightType.directional;
        if (isDirectional != wantDirectional) {
            continue;
        }

        if (usedViews + shadowViewCountOf(candidate.light.lightType) > maxShadowViews) {
            continue;
        }

        if (isDirectional) {
            return i;
        }

        scalar distance = (candidate.position - activeCameraWorldPosition).magnitude;
        if (best < 0 || distance < bestDistance) {
            best = i;
            bestDistance = distance;
        }
    }

    return best;
}

private void appendView(ref Array!RenderView views, RenderView view) {
    view.targetLayer = cast(uint) views.length;
    views.add(view);
    shadowViews.add(view);
}

/**
 * Builds the view a directional light's single map is rendered from.
 *
 * A directional light has no position, so the map's box is fitted around what the camera can
 * see: the camera's own frustum, cut at $(D ShadowSettings.distance), measured along the
 * light's axes. The light's eye then sits behind that box by the same distance, so that
 * casters standing just outside the camera's view still land in the map and drop shadows into
 * it.
 */
RenderView directionalShadowView(const Vector3 lightDirection) {
    Quaternion lightOrientation = orientationFacing(lightDirection);

    Vector3[8] corners;
    cameraFrustumCorners(corners);

    // Rotation only: where the box sits along the light's axes is what is being measured, and
    // the eye that fixes the origin is not known until it has been.
    const Matrix4 lightRotation = createViewMatrixQ(Vector3(0), lightOrientation);

    Vector3 lightSpaceMin = transformPoint(lightRotation, corners[0]);
    Vector3 lightSpaceMax = lightSpaceMin;
    foreach (i; 1 .. 8) {
        Vector3 point = transformPoint(lightRotation, corners[i]);
        lightSpaceMin = minOf(lightSpaceMin, point);
        lightSpaceMax = maxOf(lightSpaceMax, point);
    }

    // Grown by a texel's worth on every side. Fitted to the corners exactly, the box leaves
    // whatever sits on its edge - the corners themselves among them - landing on the boundary,
    // where rounding decides whether it is in the map at all. A texel of margin settles that
    // and costs a texel of resolution.
    uint mapSize = shadowSettings.mapSize > 0 ? shadowSettings.mapSize : 1;
    Vector3 margin = Vector3(
        (lightSpaceMax.x - lightSpaceMin.x) / cast(scalar) mapSize,
        (lightSpaceMax.y - lightSpaceMin.y) / cast(scalar) mapSize,
        (lightSpaceMax.z - lightSpaceMin.z) / cast(scalar) mapSize
    );

    lightSpaceMin = lightSpaceMin - margin;
    lightSpaceMax = lightSpaceMax + margin;

    scalar halfWidth = (lightSpaceMax.x - lightSpaceMin.x) * 0.5;
    scalar halfHeight = (lightSpaceMax.y - lightSpaceMin.y) * 0.5;
    scalar depth = lightSpaceMax.z - lightSpaceMin.z;

    // A degenerate box - a camera looking at nothing, or a zero distance - would divide by
    // zero in the projection. A hair of extent costs nothing and keeps the matrix finite.
    halfWidth = halfWidth > 0 ? halfWidth : cast(scalar) 0.001;
    halfHeight = halfHeight > 0 ? halfHeight : cast(scalar) 0.001;

    // The light looks along its own negative Z, so standing at larger Z than the whole box
    // puts all of it in front of the eye.
    Vector3 lightSpaceEye = Vector3(
        (lightSpaceMin.x + lightSpaceMax.x) * 0.5,
        (lightSpaceMin.y + lightSpaceMax.y) * 0.5,
        lightSpaceMax.z + shadowSettings.distance
    );

    Vector3 worldEye = transformPoint(lightOrientation.toRotationMatrix(), lightSpaceEye);

    RenderView view;
    view.eyePosition = worldEye;
    const Matrix4 viewMatrix = createViewMatrixQ(worldEye, lightOrientation);

    // Near at zero rather than at the box: the slab between the eye and the box is exactly
    // where the casters that are out of the camera's view stand.
    const Matrix4 projectionMatrix = createOrthographicMatrix(
        -halfWidth, halfWidth,
        -halfHeight, halfHeight,
        0, depth + shadowSettings.distance
    );

    view.viewProjectionMatrix = projectionMatrix * viewMatrix;
    view.frustum = Frustum.fromViewProjection(view.viewProjectionMatrix);
    return view;
}

/**
 * Appends the six views a point light's cube of maps is rendered from, in the face order of
 * $(D cubeFaceOrientations).
 *
 * Each face is a square 90 degree view, which is what tiles six of them into the whole sphere
 * around the light. They reach as far as the light does: past its attenuation radius it
 * contributes nothing, so there is nothing there to shadow.
 */
void appendPointViews(ref Array!RenderView views, const Vector3 position, const scalar radius) {
    scalar farDistance = radius > 0 ? radius : cast(scalar) 1;

    foreach (i; 0 .. 6) {
        RenderView view;
        view.eyePosition = position;
        const Matrix4 viewMatrix = createViewMatrixQ(position, cubeFaceOrientation(i));
        const Matrix4 projectionMatrix = createPerspectiveMatrix(
            degreesToRadians(90), 1, cast(scalar) 0.05, farDistance);

        view.viewProjectionMatrix = projectionMatrix * viewMatrix;
        view.frustum = Frustum.fromViewProjection(view.viewProjectionMatrix);
        appendView(views, view);
    }
}

/**
 * The eight world-space corners of what the active camera sees, cut at
 * $(D ShadowSettings.distance).
 *
 * The near four come first, then the far four; within each, the order is bottom-left,
 * bottom-right, top-left, top-right. Only the set of them matters to the fit, not the order.
 */
void cameraFrustumCorners(ref Vector3[8] corners) {
    CameraConfiguration config = activeCameraConfiguration;

    scalar aspectRatio = config.aspectRatio;
    if (aspectRatio == autoAspectRatio) {
        auto viewport = activeCameraViewport;
        aspectRatio = viewport.height > 0
            ? cast(scalar) viewport.width / cast(scalar) viewport.height : cast(scalar) 1;
    }

    // A far plane of zero means the camera sees forever, so the shadow distance is the only
    // thing bounding the box. Otherwise whichever runs out first does.
    scalar farDistance = config.farClippingDistance == 0
        ? shadowSettings.distance
        : (config.farClippingDistance < shadowSettings.distance
                ? config.farClippingDistance : shadowSettings.distance);

    scalar nearDistance = config.nearClippingDistance;

    scalar nearHalfHeight;
    scalar nearHalfWidth;
    scalar farHalfHeight;
    scalar farHalfWidth;

    if (config.projectionType == ProjectionType.perspective) {
        // Despite its name the field of view is applied vertically by the renderer's
        // projection, and the box has to be shaped the way what is actually drawn is.
        scalar halfFovTangent = tan(cast(scalar) 0.5 * config.horizontalFieldOfViewRadian);
        nearHalfHeight = nearDistance * halfFovTangent;
        farHalfHeight = farDistance * halfFovTangent;
    } else {
        nearHalfHeight = config.orthoScale;
        farHalfHeight = config.orthoScale;
    }

    nearHalfWidth = nearHalfHeight * aspectRatio;
    farHalfWidth = farHalfHeight * aspectRatio;

    const Matrix4 cameraRotation = activeCameraOrientation.toRotationMatrix();

    size_t index = 0;
    foreach (isFar; 0 .. 2) {
        scalar halfWidth = isFar ? farHalfWidth : nearHalfWidth;
        scalar halfHeight = isFar ? farHalfHeight : nearHalfHeight;
        scalar depth = isFar ? farDistance : nearDistance;

        foreach (corner; 0 .. 4) {
            scalar x = (corner & 1) ? halfWidth : -halfWidth;
            scalar y = (corner & 2) ? halfHeight : -halfHeight;

            // Negative Z is forward, the way everything else in the engine faces.
            Vector3 cameraSpace = Vector3(x, y, -depth);
            corners[index] = transformPoint(cameraRotation, cameraSpace) + activeCameraWorldPosition;
            index++;
        }
    }
}

/**
 * An orientation that faces the given direction.
 *
 * A directional light is aimed by its entity's orientation, but what reaches this module is
 * the direction that orientation produced, which is all the fit needs: any orientation facing
 * the same way frames the same box, since rolling it only turns the box about the light's own
 * axis.
 */
private Quaternion orientationFacing(const Vector3 direction) {
    Vector3 forward = direction;
    scalar length = forward.magnitude;
    if (length <= 0) {
        return Quaternion();
    }

    forward = forward / length;

    // An orientation faces its own negative Z, so the rotation wanted is the one taking that
    // axis onto the direction.
    Vector3 defaultForward = Vector3(0, 0, -1);
    scalar alignment = defaultForward.dot(forward);

    if (alignment > cast(scalar) 0.9999) {
        return Quaternion();
    }

    if (alignment < cast(scalar)-0.9999) {
        // Exactly opposite: every axis square to the default forward turns it around, and
        // which one is picked only rolls the result.
        return Quaternion.createRotation(degreesToRadians(180), Vector3(0, 1, 0));
    }

    Vector3 axis = defaultForward.cross(forward);
    scalar angle = atan2(axis.magnitude, alignment);
    return Quaternion.createRotation(angle, axis);
}

/// Applies a transform to a point, ignoring the perspective row.
private Vector3 transformPoint(const Matrix4 transform, const Vector3 point) {
    Vector4 transformed = transform * Vector4(point, 1);
    return Vector3(transformed.x, transformed.y, transformed.z);
}

version (UnitTesting)  :  //

import retrograde.engine.rendering : Color, Light;
import retrograde.std.geometry : Aabb;
import retrograde.std.test : test, writeSection;

void runShadowTests() {
    writeSection("-- Shadow tests --");

    test("Camera frustum corners lie in front of an unturned camera", {
        resetShadowTestState();
        activeCameraWorldPosition = Vector3(0, 0, 0);
        activeCameraOrientation = Quaternion();
        shadowSettings.distance = 10;

        Vector3[8] corners;
        cameraFrustumCorners(corners);

        foreach (i; 0 .. 8) {
            assert(corners[i].z < 0);
        }
    });

    test("Camera frustum corners reach no further than the shadow distance", {
        resetShadowTestState();
        activeCameraWorldPosition = Vector3(0, 0, 0);
        activeCameraOrientation = Quaternion();
        shadowSettings.distance = 10;

        Vector3[8] corners;
        cameraFrustumCorners(corners);

        foreach (i; 0 .. 8) {
            assert(corners[i].z >= -10.001);
        }
    });

    test("Camera frustum corners are cut by a nearer far plane", {
        resetShadowTestState();
        activeCameraWorldPosition = Vector3(0, 0, 0);
        activeCameraOrientation = Quaternion();
        shadowSettings.distance = 100;
        activeCameraConfiguration.farClippingDistance = 5;

        Vector3[8] corners;
        cameraFrustumCorners(corners);

        foreach (i; 0 .. 8) {
            assert(corners[i].z >= -5.001);
        }
    });

    test("Camera frustum corners follow the camera's position", {
        resetShadowTestState();
        activeCameraWorldPosition = Vector3(100, 0, 0);
        activeCameraOrientation = Quaternion();
        shadowSettings.distance = 10;

        Vector3[8] corners;
        cameraFrustumCorners(corners);

        foreach (i; 0 .. 8) {
            assert(corners[i].x > 50);
        }
    });

    test("A directional shadow view sees every camera frustum corner", {
        resetShadowTestState();
        activeCameraWorldPosition = Vector3(0, 0, 0);
        activeCameraOrientation = Quaternion();
        shadowSettings.distance = 20;

        auto view = directionalShadowView(Vector3(0, -1, 0));

        Vector3[8] corners;
        cameraFrustumCorners(corners);
        foreach (i; 0 .. 8) {
            assert(view.frustum.overlaps(Aabb(corners[i], corners[i])));
        }
    });

    test("A directional shadow view sees a caster standing above the camera's view", {
        resetShadowTestState();
        activeCameraWorldPosition = Vector3(0, 0, 0);
        activeCameraOrientation = Quaternion();
        shadowSettings.distance = 20;

        auto view = directionalShadowView(Vector3(0, -1, 0));

        // Straight up from the middle of what the camera sees, which is outside the camera's
        // own frustum but squarely between the sun and the ground it shades.
        auto caster = Vector3(0, 30, -10);
        assert(view.frustum.overlaps(Aabb(caster, caster)));
    });

    test("Point shadow views cover every axis around the light", {
        resetShadowTestState();
        Array!RenderView views;
        appendPointViews(views, Vector3(0, 0, 0), 10);
        assert(views.length == 6);

        static immutable Vector3[6] probes = [
            Vector3(5, 0, 0), Vector3(-5, 0, 0),
            Vector3(0, 5, 0), Vector3(0, -5, 0),
            Vector3(0, 0, 5), Vector3(0, 0, -5)
        ];

        foreach (p; 0 .. 6) {
            bool covered = false;
            foreach (v; 0 .. views.length) {
                if (views[v].frustum.overlaps(Aabb(probes[p], probes[p]))) {
                    covered = true;
                    break;
                }
            }

            assert(covered);
        }
    });

    test("Point shadow views are numbered by the layer they render into", {
        resetShadowTestState();
        Array!RenderView views;
        appendPointViews(views, Vector3(0, 0, 0), 10);

        foreach (i; 0 .. views.length) {
            assert(views[i].targetLayer == i);
        }
    });

    test("A light that does not cast gets no shadow views", {
        resetShadowTestState();
        addTestLight(LightType.directional, false);

        Array!RenderView views;
        prepareShadowViews(views);

        assert(views.length == 0);
        assert(activeLights[0].shadowView == -1);
        assert(activeLights[0].shadowViewCount == 0);
    });

    // Each of these needs room in the build's budget for the lights it sets up, so each is
    // compiled only into a build that has it. A build with no budget at all is covered by the
    // test that nothing casts, further down.
    static if (maxShadowViews >= 1) {
        test("A casting directional light takes one shadow view", {
            resetShadowTestState();
            addTestLight(LightType.directional, true);

            Array!RenderView views;
            prepareShadowViews(views);

            assert(views.length == 1);
            assert(activeLights[0].shadowView == 0);
            assert(activeLights[0].shadowViewCount == 1);
        });
    }

    static if (maxShadowViews >= 6) {
        test("A casting point light takes six shadow views", {
            resetShadowTestState();
            addTestLight(LightType.point, true);

            Array!RenderView views;
            prepareShadowViews(views);

            assert(views.length == 6);
            assert(activeLights[0].shadowView == 0);
            assert(activeLights[0].shadowViewCount == 6);
        });
    }

    static if (maxShadowViews >= 7) {
        test("Directional lights are given views before point lights", {
            resetShadowTestState();
            addTestLight(LightType.point, true);
            addTestLight(LightType.directional, true);

            Array!RenderView views;
            prepareShadowViews(views);

            // The directional light was added second but is shadowed first, so it holds layer 0.
            assert(activeLights[1].shadowView == 0);
            assert(activeLights[0].shadowView == 1);
        });
    }

    test("A light that does not fit the remaining budget gets no shadow views", {
        resetShadowTestState();
        foreach (i; 0 .. maxShadowViews + 1) {
            addTestLight(LightType.directional, true);
        }

        Array!RenderView views;
        prepareShadowViews(views);

        assert(views.length == maxShadowViews);

        size_t lastLight = maxShadowViews;
        assert(activeLights[lastLight].shadowView == -1);
    });

    static if (maxShadowViews >= 1) {
        test("Preparing shadow views clears what the previous frame left", {
            resetShadowTestState();
            addTestLight(LightType.directional, true);

            Array!RenderView views;
            prepareShadowViews(views);
            prepareShadowViews(views);

            assert(views.length == 1);
            assert(shadowViews.length == 1);
        });

        test("A light that stops casting loses its shadow view", {
            resetShadowTestState();
            addTestLight(LightType.directional, true);

            Array!RenderView views;
            prepareShadowViews(views);
            assert(activeLights[0].shadowView == 0);

            ActiveLight light = activeLights[0];
            light.light.castsShadows = false;
            activeLights.replace(0, light);
            prepareShadowViews(views);

            assert(views.length == 0);
            assert(activeLights[0].shadowView == -1);
        });
    } else {
        test("Nothing casts when the build has no shadow views", {
            resetShadowTestState();
            addTestLight(LightType.directional, true);
            addTestLight(LightType.point, true);

            Array!RenderView views;
            prepareShadowViews(views);

            assert(views.length == 0);
            assert(activeLights[0].shadowView == -1);
            assert(activeLights[1].shadowView == -1);
        });
    }
}

private void resetShadowTestState() {
    activeLights.truncate(0);
    shadowViews.truncate(0);
    shadowSettings = ShadowSettings();
    activeCameraConfiguration = CameraConfiguration();
    activeCameraViewport = Viewport(0, 0, 800, 600);
    activeCameraWorldPosition = Vector3(0, 0, 0);
    activeCameraOrientation = Quaternion();
}

private void addTestLight(const LightType lightType, const bool castsShadows) {
    Light light;
    light.lightType = lightType;
    light.castsShadows = castsShadows;
    light.color = Color(1, 1, 1, 1);
    light.intensity = 1;
    light.attenuationRadius = 10;

    activeLights.add(ActiveLight(Vector3(0, 2, 0), Vector3(0, -1, 0), light));
}
