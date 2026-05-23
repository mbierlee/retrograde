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

module retrograde.engine.entityfactory;

import retrograde.std.memory : makeUnique;
import retrograde.std.math : Vector3, Quaternion;
import retrograde.std.geometry : PositionComponentType, OrientationComponentType, ScaleComponentType;

import retrograde.engine.entity : EntityId, addComponent;
import retrograde.engine.animation.kinetic : RotationComponentType;

void addPosition(EntityId entity, const double x, const double y, const double z) {
    entity.addPosition(Vector3(x, y, z));
}

void addPosition(EntityId entity, const Vector3 position) {
    entity.addComponent(PositionComponentType, makeUnique(position));
}

void addOrientation(EntityId entity, double radianAngle, const Vector3 axis) {
    entity.addComponent(OrientationComponentType, makeUnique(Quaternion.createRotation(radianAngle, axis)));
}

void addScale(EntityId entity, const double scale) {
    entity.addScale(Vector3(scale));
}

void addScale(EntityId entity, const double xScale, const double yScale, const double zScale) {
    entity.addScale(Vector3(xScale, yScale, zScale));
}

void addScale(EntityId entity, const Vector3 scale) {
    entity.addComponent(ScaleComponentType, makeUnique(scale));
}

void addRotation(EntityId entity, double radianAngle, const Vector3 axis) {
    entity.addComponent(RotationComponentType, makeUnique(Quaternion.createRotation(radianAngle, axis)));
}
