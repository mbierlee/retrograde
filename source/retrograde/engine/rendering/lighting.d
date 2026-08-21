/**
 * Retrograde Engine
 *
 * Collection and per-entity selection of the lights that shine on a frame.
 *
 * This module is renderer-agnostic: it decides which lights reach a given point in the
 * world, a graphics API implementation only uploads what it hands back.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.rendering.lighting;

import retrograde.engine.entity : EntityId, getComponentData;
import retrograde.engine.rendering : Light, LightComponentType;
import retrograde.engine.rendering.materialshader : maxLights;

import retrograde.std.collections : Array;
import retrograde.std.geometry : PositionComponentType;
import retrograde.std.math : scalar, Vector3;

/// The actively used light culling strategy
LightCullingStrategy lightCullingStrategy = LightCullingStrategy.none;

/**
 * Strategies for culling lights that are applied
 * in the forward-rendered shaders.
 *
 * These only govern culling by relevance. The shader has room for a fixed number of
 * lights, so whichever strategy is picked, an entity reached by more than
 * $(D maxLights) of them still has the surplus culled in the end, nearest lights first
 * to survive.
 */
enum LightCullingStrategy {
    /**
     * Never cull a light for being irrelevant to an entity.
     * This prevents any accidental culling, but might be
     * very expensive.
     * The $(D maxLights) budget still applies.
     */
    none,

    /**
     * Cull lights that fall outside an entity's range,
     * based on their position, the light's position and its
     * attenuation range.
     */
    outsideRange,
}

/// A light collected for the current frame, together with the world position it shines from.
struct ActiveLight {
    Vector3 position;
    Light light;
}

/**
 * The lights that emit anything this frame, in no particular order.
 *
 * Rebuilt by $(D collectActiveLights) once per frame; use $(D selectActiveLights) to get
 * the ones that actually reach a particular spot.
 */
Array!ActiveLight activeLights;

private Array!EntityId lightEntities;

/**
 * Track an entity as a light emitter.
 *
 * Called from the renderer's entity hooks, so that collecting the frame's lights does not
 * have to walk every entity in the world.
 */
void registerLightEntity(EntityId entity) {
    if (!lightEntities.exists(entity)) {
        lightEntities.add(entity);
    }
}

/// Stop tracking an entity as a light emitter.
void unregisterLightEntity(EntityId entity) {
    auto index = lightEntities.find(entity);
    if (index != -1) {
        lightEntities.remove(index);
    }
}

/**
 * Refills $(D activeLights) from the registered light entities.
 *
 * Lights that cannot emit anything - switched off, or with an intensity or attenuation
 * radius of zero - are left out, as are entities that lost their light or position
 * component since they were registered.
 */
void collectActiveLights() {
    // Truncating rather than clearing keeps the capacity from last frame, so a scene with a
    // steady number of lights stops allocating after the first frame.
    activeLights.truncate(0);

    foreach (ref entity; lightEntities) {
        auto maybeLight = entity.getComponentData!Light(LightComponentType);
        if (!maybeLight.isDefined) {
            continue;
        }

        Light light = *maybeLight.value;
        if (!light.isEnabled || light.intensity <= 0 || light.attenuationRadius <= 0) {
            continue;
        }

        auto maybePosition = entity.getComponentData!Vector3(PositionComponentType);
        if (!maybePosition.isDefined) {
            continue;
        }

        activeLights.add(ActiveLight(*maybePosition.value, light));
    }
}

/**
 * Picks the lights among `candidates` that reach `target`, nearest first, at most `maxCount`
 * of them.
 *
 * Which lights are culled for being irrelevant is up to the current
 * $(D lightCullingStrategy). Under $(D LightCullingStrategy.outsideRange) a light is culled
 * unless the target is within its attenuation radius, beyond which the falloff has it
 * contribute nothing anyway. Under $(D LightCullingStrategy.none) that range test is skipped
 * and every candidate is considered, so a light whose radius falls short of the entity's
 * origin can still light part of its mesh.
 *
 * `maxCount` culls in the end whatever the strategy, since the shader has room for a fixed
 * number of lights: $(D LightCullingStrategy.none) means "never cull a light for being out of
 * range", not "hand back more lights than fit". Whatever the strategy, it is the nearest
 * lights that survive that final cull.
 *
 * Params:
 *  candidates = the lights to choose from, typically $(D activeLights).
 *  target = the world position being lit.
 *  maxCount = how many lights the caller can take. Zero selects nothing.
 *  selected = receives the chosen lights, nearest first. Truncated first, so its capacity
 *             carries over between calls.
 * Returns: the number of lights written to `selected`.
 */
size_t selectLights(const ref Array!ActiveLight candidates, const Vector3 target,
    const size_t maxCount, ref Array!ActiveLight selected) {
    selected.truncate(0);
    if (maxCount == 0) {
        return 0;
    }

    foreach (i; 0 .. candidates.length) {
        ActiveLight candidate = candidates[i];

        // Needed whatever the strategy: it is what orders the selection, and so what decides
        // which lights survive the final maxCount cull.
        scalar distance = (candidate.position - target).magnitude;

        //TODO: Measured from the entity's origin, so a mesh bigger than the light's radius
        //      can be culled even though part of it is lit. Needs per-entity bounding volumes.
        //      LightCullingStrategy.none is the blunt way out of that until it exists.
        if (lightCullingStrategy == LightCullingStrategy.outsideRange
            && distance > candidate.light.attenuationRadius) {
            continue;
        }

        // `selected` is kept sorted as it is built, so the last entry is the farthest one held
        // and a full selection can reject a farther candidate outright.
        if (selected.length == maxCount
            && distance >= (selected[maxCount - 1].position - target).magnitude) {
            continue;
        }

        size_t insertIndex = selected.length;
        foreach (j; 0 .. selected.length) {
            if (distance < (selected[j].position - target).magnitude) {
                insertIndex = j;
                break;
            }
        }

        if (selected.length < maxCount) {
            selected.add(candidate);
        }

        for (size_t j = selected.length - 1; j > insertIndex; j--) {
            selected.replace(j, selected[j - 1]);
        }

        selected.replace(insertIndex, candidate);
    }

    return selected.length;
}

/**
 * Picks the lights of the current frame that reach `target`, nearest first, culling by the
 * current $(D lightCullingStrategy) and then by the build's $(D maxLights) budget - which
 * culls whatever the strategy, since that is the room the shader has.
 *
 * Returns: the number of lights written to `selected`.
 */
size_t selectActiveLights(const Vector3 target, ref Array!ActiveLight selected) {
    return selectLights(activeLights, target, maxLights, selected);
}

version (UnitTesting)  :  //

import retrograde.std.test : test, writeSection;

private ActiveLight testLight(scalar x, scalar y, scalar z, scalar attenuationRadius) {
    Light light;
    light.attenuationRadius = attenuationRadius;
    return ActiveLight(Vector3(x, y, z), light);
}

void runLightingTests() {
    writeSection("-- Lighting tests --");

    test("Select no lights when there are no candidates", {
        Array!ActiveLight candidates;
        Array!ActiveLight selected;

        assert(selectLights(candidates, Vector3(0, 0, 0), 8, selected) == 0);
        assert(selected.length == 0);
    });

    test("Select nothing when the caller takes no lights", {
        Array!ActiveLight candidates;
        candidates.add(testLight(1, 0, 0, 10));
        Array!ActiveLight selected;

        assert(selectLights(candidates, Vector3(0, 0, 0), 0, selected) == 0);
        assert(selected.length == 0);
    });

    test("Exclude lights that are beyond their attenuation radius", {
        Array!ActiveLight candidates;
        candidates.add(testLight(3, 0, 0, 10)); // within
        candidates.add(testLight(20, 0, 0, 10)); // out of range
        candidates.add(testLight(10, 0, 0, 10)); // exactly on the radius, still counts
        Array!ActiveLight selected;

        lightCullingStrategy = LightCullingStrategy.outsideRange;
        assert(selectLights(candidates, Vector3(0, 0, 0), 8, selected) == 2);
        assert(selected.length == 2);
        assert(selected[0].position.x == 3);
        assert(selected[1].position.x == 10);
    });

    test("Keep lights that are out of range when nothing is culled by relevance", {
        Array!ActiveLight candidates;
        candidates.add(testLight(3, 0, 0, 10)); // within
        candidates.add(testLight(20, 0, 0, 10)); // far beyond its radius, kept anyway
        Array!ActiveLight selected;

        lightCullingStrategy = LightCullingStrategy.none;
        assert(selectLights(candidates, Vector3(0, 0, 0), 8, selected) == 2);
        assert(selected[0].position.x == 3);
        assert(selected[1].position.x == 20);

        lightCullingStrategy = LightCullingStrategy.outsideRange;
    });

    test("The light budget still culls when nothing is culled by relevance", {
        // All three are well outside their own radius, so only the strategy keeps them in.
        Array!ActiveLight candidates;
        candidates.add(testLight(0, 0, 30, 1));
        candidates.add(testLight(0, 0, 10, 1));
        candidates.add(testLight(0, 0, 20, 1));
        Array!ActiveLight selected;

        lightCullingStrategy = LightCullingStrategy.none;
        assert(selectLights(candidates, Vector3(0, 0, 0), 2, selected) == 2);
        assert(selected[0].position.z == 10);
        assert(selected[1].position.z == 20);

        lightCullingStrategy = LightCullingStrategy.outsideRange;
        assert(selectLights(candidates, Vector3(0, 0, 0), 2, selected) == 0);
    });

    test("Select lights nearest first", {
        Array!ActiveLight candidates;
        candidates.add(testLight(0, 0, 5, 100));
        candidates.add(testLight(0, 0, 1, 100));
        candidates.add(testLight(0, 0, 9, 100));
        candidates.add(testLight(0, 0, 3, 100));
        Array!ActiveLight selected;

        assert(selectLights(candidates, Vector3(0, 0, 0), 8, selected) == 4);
        assert(selected[0].position.z == 1);
        assert(selected[1].position.z == 3);
        assert(selected[2].position.z == 5);
        assert(selected[3].position.z == 9);
    });

    test("Cap the selection at the given maximum, keeping the nearest", {
        Array!ActiveLight candidates;
        candidates.add(testLight(0, 0, 8, 100));
        candidates.add(testLight(0, 0, 2, 100));
        candidates.add(testLight(0, 0, 6, 100));
        candidates.add(testLight(0, 0, 4, 100));
        Array!ActiveLight selected;

        assert(selectLights(candidates, Vector3(0, 0, 0), 2, selected) == 2);
        assert(selected.length == 2);
        assert(selected[0].position.z == 2);
        assert(selected[1].position.z == 4);
    });

    test("Select lights relative to the target, not the origin", {
        Array!ActiveLight candidates;
        candidates.add(testLight(0, 0, 0, 3));
        candidates.add(testLight(10, 0, 0, 3));
        Array!ActiveLight selected;

        assert(selectLights(candidates, Vector3(9, 0, 0), 8, selected) == 1);
        assert(selected[0].position.x == 10);
    });

    test("Collect lights of entities that emit", {
        import retrograde.engine.entity : createEntity, resetEcs;
        import retrograde.engine.entityfactory : addLight, addPosition;
        import retrograde.std.string : s;

        resetEcs();

        auto entity = createEntity("ent_light_test".s).value;
        entity.addPosition(1, 2, 3);
        entity.addLight(Light());
        entity.registerLightEntity();

        collectActiveLights();
        assert(activeLights.length == 1);
        assert(activeLights[0].position == Vector3(1, 2, 3));
        assert(activeLights[0].light.isEnabled);

        entity.unregisterLightEntity();
    });

    test("Collect skips lights that cannot emit anything", {
        import retrograde.engine.entity : createEntity, resetEcs;
        import retrograde.engine.entityfactory : addLight, addPosition;
        import retrograde.std.string : s;

        resetEcs();

        Light disabled;
        disabled.isEnabled = false;

        Light noIntensity;
        noIntensity.intensity = 0;

        Light noRadius;
        noRadius.attenuationRadius = 0;

        auto disabledEntity = createEntity("ent_disabled_light".s).value;
        disabledEntity.addPosition(0, 0, 0);
        disabledEntity.addLight(disabled);
        disabledEntity.registerLightEntity();

        auto noIntensityEntity = createEntity("ent_dark_light".s).value;
        noIntensityEntity.addPosition(0, 0, 0);
        noIntensityEntity.addLight(noIntensity);
        noIntensityEntity.registerLightEntity();

        auto noRadiusEntity = createEntity("ent_pointless_light".s).value;
        noRadiusEntity.addPosition(0, 0, 0);
        noRadiusEntity.addLight(noRadius);
        noRadiusEntity.registerLightEntity();

        // A light entity that never got a position cannot be placed in the world.
        auto positionlessEntity = createEntity("ent_placeless_light".s).value;
        positionlessEntity.addLight(Light());
        positionlessEntity.registerLightEntity();

        collectActiveLights();
        assert(activeLights.length == 0);

        disabledEntity.unregisterLightEntity();
        noIntensityEntity.unregisterLightEntity();
        noRadiusEntity.unregisterLightEntity();
        positionlessEntity.unregisterLightEntity();
    });

    test("Unregistered light entities stop being collected", {
        import retrograde.engine.entity : createEntity, resetEcs;
        import retrograde.engine.entityfactory : addLight, addPosition;
        import retrograde.std.string : s;

        resetEcs();

        auto entity = createEntity("ent_light_test".s).value;
        entity.addPosition(0, 0, 0);
        entity.addLight(Light());
        entity.registerLightEntity();

        collectActiveLights();
        assert(activeLights.length == 1);

        entity.unregisterLightEntity();
        collectActiveLights();
        assert(activeLights.length == 0);
    });
}
