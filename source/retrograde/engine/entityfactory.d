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
import retrograde.engine.animation.kinetic : RotationComponentType, TranslationComponentType,
    ScalingComponentType;
import retrograde.engine.rendering : Color, Light, LightComponentType, LightType;

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

void addTranslation(EntityId entity, const double x, const double y, const double z) {
    entity.addTranslation(Vector3(x, y, z));
}

void addTranslation(EntityId entity, const Vector3 translation) {
    entity.addComponent(TranslationComponentType, makeUnique(translation));
}

void addScaling(EntityId entity, const double scaling) {
    entity.addScaling(Vector3(scaling));
}

void addScaling(EntityId entity, const double xScaling, const double yScaling, const double zScaling) {
    entity.addScaling(Vector3(xScaling, yScaling, zScaling));
}

void addScaling(EntityId entity, const Vector3 scaling) {
    entity.addComponent(ScalingComponentType, makeUnique(scaling));
}

void addLight(EntityId entity, const Light light) {
    entity.addComponent(LightComponentType, makeUnique(light));
}

/**
 * Gives the entity a point light of the given color, which shines from wherever the entity
 * is positioned.
 *
 * Params:
 *  intensity = brightness modifier. Zero leaves the light dark.
 *  attenuationRadius = distance in world units beyond which the light has no effect at all.
 */
void addPointLight(EntityId entity, const Color color, const float intensity, const float attenuationRadius) {
    Light light;
    light.lightType = LightType.point;
    light.isEnabled = true;
    light.color = color;
    light.intensity = intensity;
    light.attenuationRadius = attenuationRadius;
    entity.addLight(light);
}
