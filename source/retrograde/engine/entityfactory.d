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
import retrograde.std.string : s;
import retrograde.std.stringid : StringId;
import retrograde.std.math : Vector3D, QuaternionD;
import retrograde.std.geometry : PositionComponentType, OrientationComponentType, ScaleComponentType;

import retrograde.engine.entity : Entity, Component;
import retrograde.engine.animation.kinetic : RotationComponentType;

SharedPtr!Entity makeEntity(string name) {
    return makeShared(Entity(name.s));
}

void addComponent(T)(SharedPtr!Entity entity, StringId type, SharedPtr!T data) {
    auto component = Component(type, data.as!void);
    entity.addComponent(component);
}

void addPosition(SharedPtr!Entity entity, const double x, const double y, const double z) {
    entity.addPosition(Vector3D(x, y, z));
}

void addPosition(SharedPtr!Entity entity, const Vector3D position) {
    auto positionPtr = makeShared(position);
    auto positionComponent = Component(PositionComponentType, positionPtr.as!void);
    entity.addComponent(positionComponent);
}

void addOrientation(SharedPtr!Entity entity, double radianAngle, const Vector3D axis) {
    auto orientationPtr = makeShared(QuaternionD.createRotation(radianAngle, axis));
    auto orientationComponent = Component(OrientationComponentType, orientationPtr.as!void);
    entity.addComponent(orientationComponent);
}

void addScale(SharedPtr!Entity entity, const double scale) {
    entity.addScale(Vector3D(scale));
}

void addScale(SharedPtr!Entity entity, const double xScale, const double yScale, const double zScale) {
    entity.addScale(Vector3D(xScale, yScale, zScale));
}

void addScale(SharedPtr!Entity entity, const Vector3D scale) {
    auto scalePtr = makeShared(scale);
    auto scaleComponent = Component(ScaleComponentType, scalePtr.as!void);
    entity.addComponent(scaleComponent);
}

void addRotation(SharedPtr!Entity entity, double radianAngle, const Vector3D axis) {
    auto rotationPtr = makeShared(QuaternionD.createRotation(radianAngle, axis));
    auto rotationComponent = Component(RotationComponentType, rotationPtr.as!void);
    entity.addComponent(rotationComponent);
}
