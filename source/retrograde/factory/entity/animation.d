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

module retrograde.factory.entity.animation;

import retrograde.core.entity : Entity, EntityFactory, EntityFactoryParameters, ofType;
import retrograde.core.math : QuaternionD, Vector3D;

import retrograde.components.geometry : Orientation3DComponent, Position3DComponent;
import retrograde.components.animation : RotationComponent, TranslationComponent;

import std.typecons : No;

class RotationEntityFactoryParameters : EntityFactoryParameters {
    QuaternionD rotation;
}

/** 
 * Creates an entity that rotates via a RotationEntityProcessor.
 */
class RotationEntityFactory : EntityFactory {
    override void addComponents(Entity entity, const EntityFactoryParameters parameters = new RotationEntityFactoryParameters()) {
        auto p = parameters.ofType!RotationEntityFactoryParameters;

        entity.maybeAddComponent(new RotationComponent(p.rotation));
        entity.maybeAddComponent!Orientation3DComponent;
    }
}

class TranslationEntityFactoryParameters : EntityFactoryParameters {
    Vector3D translation;
}

/** 
 * Creates an entity that translates via a TranslationEntityProcessor.
 */
class TranslationEntityFactory : EntityFactory {
    override void addComponents(Entity entity, const EntityFactoryParameters parameters = new RotationEntityFactoryParameters()) {
        auto p = parameters.ofType!TranslationEntityFactoryParameters;

        entity.maybeAddComponent(new TranslationComponent(p.translation));
        entity.maybeAddComponent!Position3DComponent;
    }
}
