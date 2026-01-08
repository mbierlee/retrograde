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
import retrograde.std.math : QuaternionD;
import retrograde.std.geometry : OrientationComponentType;

import retrograde.engine.entity : EntityId, withComponentData, hasComponent;

enum RotationComponentType = sid("comp_rotation");

enum RotationProcessor = delegate(EntityId entity) {
    entity.withComponentData!QuaternionD(RotationComponentType, (QuaternionD* rotation) {
        if (entity.hasComponent(OrientationComponentType)) {
            entity.withComponentData!QuaternionD(OrientationComponentType, (
                QuaternionD* orientation) {
                auto newOrientation = *orientation * *rotation;
                *orientation = newOrientation;
            });
        }
    });
};
