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

module retrograde.engine.entityfactory;

import retrograde.std.memory : makeUniqueVoid;
import retrograde.std.stringid : StringId;
import retrograde.std.math : Vector3D, QuaternionD;
import retrograde.std.geometry : PositionComponentType, OrientationComponentType, ScaleComponentType;

import retrograde.engine.entity : EntityId, addComponent;
import retrograde.engine.animation.kinetic : RotationComponentType;

void addPosition(EntityId entity, const double x, const double y, const double z) {
    entity.addPosition(Vector3D(x, y, z));
}

void addPosition(EntityId entity, const Vector3D position) {
    entity.addComponent(PositionComponentType, makeUniqueVoid(position));
}

void addOrientation(EntityId entity, double radianAngle, const Vector3D axis) {
    entity.addComponent(OrientationComponentType, makeUniqueVoid(QuaternionD.createRotation(radianAngle, axis)));
}

void addScale(EntityId entity, const double scale) {
    entity.addScale(Vector3D(scale));
}

void addScale(EntityId entity, const double xScale, const double yScale, const double zScale) {
    entity.addScale(Vector3D(xScale, yScale, zScale));
}

void addScale(EntityId entity, const Vector3D scale) {
    entity.addComponent(ScaleComponentType, makeUniqueVoid(scale));
}

void addRotation(EntityId entity, double radianAngle, const Vector3D axis) {
    entity.addComponent(RotationComponentType, makeUniqueVoid(QuaternionD.createRotation(radianAngle, axis)));
}
