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

module retrograde.engine.animation.kinetic;

import retrograde.std.stringid : sid;
import retrograde.std.math : Quaternion, Vector3;
import retrograde.std.geometry : PositionComponentType, OrientationComponentType, ScaleComponentType;

import retrograde.engine.entity : EntityId, withComponentData, hasComponent;

enum RotationComponentType = sid("comp_rotation");
enum TranslationComponentType = sid("comp_translation");
enum ScalingComponentType = sid("comp_scaling");

/**
 * Applies the entity's rotation to its orientation each cycle.
 */
enum RotationProcessor = delegate(EntityId entity) {
    entity.withComponentData!Quaternion(RotationComponentType, (Quaternion* rotation) {
        if (entity.hasComponent(OrientationComponentType)) {
            entity.withComponentData!Quaternion(OrientationComponentType, (
                Quaternion* orientation) {
                auto newOrientation = *orientation * *rotation;
                *orientation = newOrientation;
            });
        }
    });
};

/**
 * Adds the entity's translation to its position each cycle.
 */
enum TranslationProcessor = delegate(EntityId entity) {
    entity.withComponentData!Vector3(TranslationComponentType, (Vector3* translation) {
        if (entity.hasComponent(PositionComponentType)) {
            entity.withComponentData!Vector3(PositionComponentType, (Vector3* position) {
                auto newPosition = *position + *translation;
                *position = newPosition;
            });
        }
    });
};

/**
 * Multiplies the entity's scale by its scaling factor each cycle.
 *
 * Scaling is applied per component, a scaling of (1, 1, 1) leaves the scale as-is.
 */
enum ScalingProcessor = delegate(EntityId entity) {
    entity.withComponentData!Vector3(ScalingComponentType, (Vector3* scaling) {
        if (entity.hasComponent(ScaleComponentType)) {
            entity.withComponentData!Vector3(ScaleComponentType, (Vector3* scale) {
                auto newScale = *scale * *scaling;
                *scale = newScale;
            });
        }
    });
};
