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

import retrograde.std.memory : SharedPtr, makeShared;
import retrograde.std.stringid : StringId;
import retrograde.std.math : Vector3D, QuaternionD;
import retrograde.std.geometry : PositionComponentType, OrientationComponentType, ScaleComponentType;

import retrograde.engine.entity : EntityId, EntityManager, Component;
import retrograde.engine.animation.kinetic : RotationComponentType;


void addPosition(ref EntityManager entityManager, EntityId entityId, const double x, const double y, const double z) {
    addPosition(entityManager, entityId, Vector3D(x, y, z));
}

void addPosition(ref EntityManager entityManager, EntityId entityId, const Vector3D position) {
    auto positionPtr = makeShared(position);
    auto positionComponent = Component(PositionComponentType, positionPtr.as!void);
    entityManager.addComponent(entityId, positionComponent);
}

void addOrientation(ref EntityManager entityManager, EntityId entityId, double radianAngle, const Vector3D axis) {
    auto orientationPtr = makeShared(QuaternionD.createRotation(radianAngle, axis));
    auto orientationComponent = Component(OrientationComponentType, orientationPtr.as!void);
    entityManager.addComponent(entityId, orientationComponent);
}

void addScale(ref EntityManager entityManager, EntityId entityId, const double scale) {
    addScale(entityManager, entityId, Vector3D(scale));
}

void addScale(ref EntityManager entityManager, EntityId entityId, const double xScale, const double yScale, const double zScale) {
    addScale(entityManager, entityId, Vector3D(xScale, yScale, zScale));
}

void addScale(ref EntityManager entityManager, EntityId entityId, const Vector3D scale) {
    auto scalePtr = makeShared(scale);
    auto scaleComponent = Component(ScaleComponentType, scalePtr.as!void);
    entityManager.addComponent(entityId, scaleComponent);
}

void addRotation(ref EntityManager entityManager, EntityId entityId, double radianAngle, const Vector3D axis) {
    auto rotationPtr = makeShared(QuaternionD.createRotation(radianAngle, axis));
    auto rotationComponent = Component(RotationComponentType, rotationPtr.as!void);
    entityManager.addComponent(entityId, rotationComponent);
}
