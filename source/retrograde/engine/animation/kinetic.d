/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2025 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.engine.animation.kinetic;

import retrograde.std.memory : SharedPtr;
import retrograde.std.stringid : sid;
import retrograde.std.math : QuaternionD;
import retrograde.std.geometry : OrientationComponentType;

import retrograde.engine.entity : EntityId, EntityManager;

enum RotationComponentType = sid("comp_rotation");

enum RotationProcessor = delegate(ref EntityManager entityManager, EntityId entityId) {
    entityManager.withComponentData!QuaternionD(entityId, RotationComponentType, (QuaternionD* rotation) {
        if (entityManager.hasComponent(entityId, OrientationComponentType)) {
            entityManager.withComponentData!QuaternionD(entityId, OrientationComponentType, (QuaternionD* orientation) {
                auto newOrientation = *orientation * *rotation;
                *orientation = newOrientation;
            });
        }
    });
};
