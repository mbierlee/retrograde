/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.factory.entity.drone;

import retrograde.core.entity : Entity, EntityFactory, EntityFactoryParameters, ofType;
import retrograde.core.math : scalar;

import retrograde.components.drone : DroneControllableComponent;
import retrograde.components.geometry : Position3DComponent, Orientation3DComponent;
import retrograde.components.animation : RotationComponent, TranslationComponent;

import std.typecons : No;

class DroneEntityFactoryParameters : EntityFactoryParameters {
    scalar translationSpeedModifier = 1;
    scalar rotationSpeedModifier = 1;
}

/** 
 * Creates entities that are controllable by DroneControllerProcessors
 */
class DroneEntityFactory : EntityFactory {
    override void addComponents(Entity entity, const EntityFactoryParameters parameters = new DroneEntityFactoryParameters()) {
        auto p = parameters.ofType!DroneEntityFactoryParameters;

        entity.maybeAddComponent(new DroneControllableComponent(
                p.translationSpeedModifier,
                p.rotationSpeedModifier
        ));

        entity.maybeAddComponent!RotationComponent;
        entity.maybeAddComponent!TranslationComponent;
        entity.maybeAddComponent!Orientation3DComponent;
        entity.maybeAddComponent!Position3DComponent;
    }
}
