/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2022 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.processors.animation;

import retrograde.core.entity : Entity, EntityProcessor;
import retrograde.core.math : QuaternionD, Vector3D;

import retrograde.components.animation : RotationComponent, TranslationComponent;
import retrograde.components.geometry : Orientation3DComponent, Position3DComponent;

class RotationEntityProcessor : EntityProcessor {
    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!RotationComponent && entity.hasComponent!Orientation3DComponent;
    }

    public override void update() {
        foreach (entity; entities) {
            entity.maybeWithComponent!Orientation3DComponent((c) {
                auto rotation = entity.getFromComponent!RotationComponent(c => c.rotation, QuaternionD());
                c.orientation = c.orientation * rotation;
            });
        }
    }
}

class TranslationEntityProcessor : EntityProcessor {
    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!TranslationComponent && entity.hasComponent!Position3DComponent;
    }

    public override void update() {
        foreach (entity; entities) {
            entity.maybeWithComponent!Position3DComponent((c) {
                auto translation = entity.getFromComponent!TranslationComponent(c => c.translation, Vector3D());
                c.position = c.position + translation;
            });
        }
    }
}
