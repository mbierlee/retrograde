/**
 * Retrograde Engine
 *
 * Where entities are in the world, worked out from their spatial components.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.geometry;

import retrograde.engine.entity : EntityId, getComponentData;

import retrograde.std.geometry : OriginOffsetComponentType, OrientationComponentType,
    PositionComponentType, ScaleComponentType;
import retrograde.std.math : Matrix4, Quaternion, scalar, toScalingMatrix4,
    toTranslationMatrix4, toTranslationVector, Vector3;

/**
 * Returns: The matrix taking points in the entity's own space to the world.
 *
 * An entity is rotated and scaled about its origin, and its position is where that origin
 * sits in the world. An origin offset moves the entity away from its origin, in its own space,
 * so an offset entity sits beside its position, and turning or scaling it swings it around,
 * or pushes it away from, that position rather than spinning or growing it in place.
 *
 * Every consumer of an entity's placement goes through here, so the renderer, the camera and
 * the lights agree on where an entity is. An entity without a position has its origin at
 * the world origin, one without an orientation is unrotated, one without a scale is its
 * natural size, and one without an origin offset is centered on its origin.
 */
Matrix4 worldTransformOf(EntityId entity) {
    Vector3 position;
    Quaternion orientation;
    Vector3 scale = 1;
    Vector3 originOffset;

    auto maybePosition = entity.getComponentData!Vector3(PositionComponentType);
    if (maybePosition.isDefined) {
        position = *maybePosition.value;
    }

    auto maybeOrientation = entity.getComponentData!Quaternion(OrientationComponentType);
    if (maybeOrientation.isDefined) {
        orientation = *maybeOrientation.value;
    }

    auto maybeScale = entity.getComponentData!Vector3(ScaleComponentType);
    if (maybeScale.isDefined) {
        scale = *maybeScale.value;
    }

    auto maybeOriginOffset = entity.getComponentData!Vector3(OriginOffsetComponentType);
    if (maybeOriginOffset.isDefined) {
        originOffset = *maybeOriginOffset.value;
    }

    // The offset is applied first so that it is turned and stretched along with the entity:
    // that is what has the entity swing around its origin rather than spin beside it.
    return position.toTranslationMatrix4() * orientation.toRotationMatrix()
        * scale.toScalingMatrix4() * originOffset.toTranslationMatrix4();
}

/**
 * Returns: Where the entity's own center ends up in the world.
 *
 * This is the translation of $(D worldTransformOf), so an entity with an origin offset is
 * beside its position, where its rotation and scale carry the offset to.
 */
Vector3 worldPositionOf(EntityId entity) {
    return entity.worldTransformOf().toTranslationVector();
}

version (UnitTesting)  :  //

import retrograde.engine.entity : createEntity, resetEcs;
import retrograde.engine.entityfactory : addOrientation, addOriginOffset, addPosition, addScale;
import retrograde.std.math : degreesToRadians, Vector4;
import retrograde.std.string : s;
import retrograde.std.test : test, writeSection;

private bool isNear(const Vector3 actual, const scalar x, const scalar y, const scalar z) {
    enum tolerance = 0.001;
    return actual.x > x - tolerance && actual.x < x + tolerance
        && actual.y > y - tolerance && actual.y < y + tolerance
        && actual.z > z - tolerance && actual.z < z + tolerance;
}

void runEngineGeometryTests() {
    writeSection("-- Engine geometry tests --");

    test("An entity without spatial components is at the world origin", {
        resetEcs();
        auto entity = createEntity("ent_test".s).value;

        assert(entity.worldTransformOf() == Matrix4.identity);
        assert(entity.worldPositionOf() == Vector3(0, 0, 0));
    });

    test("An entity without an origin offset is at its position", {
        resetEcs();
        auto entity = createEntity("ent_test".s).value;
        entity.addPosition(1, 2, 3);

        assert(entity.worldPositionOf() == Vector3(1, 2, 3));
    });

    test("An origin offset moves an unturned entity beside its position", {
        resetEcs();
        auto entity = createEntity("ent_test".s).value;
        entity.addPosition(1, 2, 3);
        entity.addOriginOffset(-10, 0, 0);

        assert(entity.worldPositionOf() == Vector3(-9, 2, 3));
    });

    test("A turned entity swings around its position", {
        resetEcs();
        auto entity = createEntity("ent_test".s).value;
        entity.addPosition(1, 2, 3);
        entity.addOriginOffset(-10, 0, 0);
        entity.addOrientation(degreesToRadians(180), Vector3(0, 1, 0));

        // The entity is 10 to the left of its position; a half turn puts it 10 to the right.
        assert(isNear(entity.worldPositionOf(), 11, 2, 3));
    });

    test("A scaled entity is pushed away from its position", {
        resetEcs();
        auto entity = createEntity("ent_test".s).value;
        entity.addPosition(1, 2, 3);
        entity.addOriginOffset(-10, 0, 0);
        entity.addScale(2);

        assert(isNear(entity.worldPositionOf(), -19, 2, 3));
    });

    test("Points of an offset entity are turned about its position", {
        resetEcs();
        auto entity = createEntity("ent_test".s).value;
        entity.addOriginOffset(-1, 0, 0);
        entity.addOrientation(degreesToRadians(90), Vector3(0, 1, 0));

        // A point two to the right of the entity is one to the right of its position, and a
        // quarter turn to the left about the Y axis brings that to one ahead of the position.
        auto point = entity.worldTransformOf() * Vector4(2, 0, 0, 1);

        assert(isNear(Vector3(point.x, point.y, point.z), 0, 0, -1));
    });
}
