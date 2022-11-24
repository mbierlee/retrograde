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
import retrograde.core.math : QuaternionD, Vector3D, toTranslationMatrix, toTranslationVector;

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

//TODO: Find way to make sure TranslationEntityProcessor is always run after RotationEntityProcessor
class TranslationEntityProcessor : EntityProcessor {
    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!TranslationComponent && entity.hasComponent!Position3DComponent;
    }

    public override void update() {
        foreach (entity; entities) {
            entity.maybeWithComponent!Position3DComponent((c) {
                auto rotationMatrix =
                    entity
                    .getFromComponent!Orientation3DComponent(c => c.orientation, QuaternionD())
                    .toRotationMatrix;

                auto translationMatrix =
                    entity
                    .getFromComponent!TranslationComponent(c => c.translation, Vector3D())
                    .toTranslationMatrix;

                auto newTranslation =
                    (rotationMatrix * translationMatrix).toTranslationVector;

                c.position = c.position + newTranslation;
            });
        }
    }
}
