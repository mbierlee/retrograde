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

module retrograde.factory.entity.firstperson;

import retrograde.core.entity : Entity, EntityFactory, EntityFactoryParameters, ofType, EntityHierarchyFactory;
import retrograde.core.math : scalar, Vector3D;

import retrograde.components.firstperson : FirstPersonControllableComponent;
import retrograde.components.geometry : Position3DComponent, Orientation3DComponent;
import retrograde.components.animation : AxisRotationComponent, RotationComponent, TranslationComponent;

import poodinis : Inject;

class FirstPersonControllableFactoryParameters : EntityFactoryParameters {
    scalar translationSpeedModifier = 1;
    scalar rotationSpeedModifier = 1;
}

class FirstPersonControllableFactory : EntityHierarchyFactory {
    private @Inject FirstPersonControllableBodyFactory bodyFactory;
    private @Inject FirstPersonControllableHeadFactory headFactory;

    Entity[string] createEntities(const string entityName, const EntityFactoryParameters parameters) {
        auto bodyEntity = bodyFactory.createEntity(entityName ~ "_body", parameters);
        auto headEntity = headFactory.createEntity(entityName ~ "_head", parameters);
        headEntity.parent = bodyEntity;

        return [
            bodyEntity.name: bodyEntity,
            headEntity.name: headEntity
        ];
    }
}

class FirstPersonControllableBodyFactory : EntityFactory {
    override void addComponents(Entity entity, const EntityFactoryParameters parameters = new FirstPersonControllableFactoryParameters()) {
        auto p = parameters.ofType!FirstPersonControllableFactoryParameters;

        entity.maybeAddComponent(new FirstPersonControllableComponent(
                p.translationSpeedModifier,
                p.rotationSpeedModifier
        ));

        auto axisRotationComponent = new AxisRotationComponent(Vector3D.upVector, 0);
        entity.maybeAddComponent(axisRotationComponent);
        entity.maybeAddComponent!TranslationComponent;
        entity.maybeAddComponent!Orientation3DComponent;
        entity.maybeAddComponent!Position3DComponent;
    }
}

class FirstPersonControllableHeadFactory : EntityFactory {
    override void addComponents(Entity entity, const EntityFactoryParameters parameters = new FirstPersonControllableFactoryParameters()) {
        auto p = parameters.ofType!FirstPersonControllableFactoryParameters;

        entity.maybeAddComponent(new FirstPersonControllableComponent(
                p.translationSpeedModifier,
                p.rotationSpeedModifier
        ));

        entity.maybeAddComponent!RotationComponent;
        entity.maybeAddComponent!TranslationComponent;
        entity.maybeAddComponent!Orientation3DComponent;
        entity.maybeAddComponent!Position3DComponent;
    }
}
