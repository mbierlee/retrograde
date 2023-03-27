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

module retrograde.entityfactory.firstperson;

import retrograde.core.entity : Entity, EntityFactory, EntityFactoryParameters, ofType;
import retrograde.core.math : scalar;

import retrograde.components.firstperson : FirstPersonMovementComponent;
import retrograde.components.geometry : Position3DComponent, Orientation3DComponent;
import retrograde.components.animation : RotationComponent, TranslationComponent;

class FirstPersonMovementFactoryParameters : EntityFactoryParameters {
    public scalar translationSpeedModifier = 1;
    public scalar rotationSpeedModifier = 1;
}

class FirstPersonMovementFactory : EntityFactory {
    public override void addComponents(Entity entity, const EntityFactoryParameters parameters = new FirstPersonMovementFactoryParameters()) {
        auto p = parameters.ofType!FirstPersonMovementFactoryParameters;

        entity.maybeAddComponent(new FirstPersonMovementComponent(
                p.translationSpeedModifier,
                p.rotationSpeedModifier
        ));

        entity.maybeAddComponent!RotationComponent;
        entity.maybeAddComponent!TranslationComponent;
        entity.maybeAddComponent!Orientation3DComponent;
        entity.maybeAddComponent!Position3DComponent;
    }
}
