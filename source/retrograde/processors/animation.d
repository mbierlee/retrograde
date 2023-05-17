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

module retrograde.processors.animation;

import retrograde.core.entity : Entity, EntityProcessor, StandardEntityProcessorPriority;
import retrograde.core.math : QuaternionD, Vector3D, toTranslationMatrix, toTranslationVector;

import retrograde.components.animation : RotationComponent, TranslationComponent, AxisRotationComponent;
import retrograde.components.geometry : Orientation3DComponent, Position3DComponent;

class RotationEntityProcessor : EntityProcessor {
    this() {
        priority = StandardEntityProcessorPriority.rotation;
    }

    public override bool acceptsEntity(Entity entity) {
        return (entity.hasComponent!RotationComponent || entity.hasComponent!AxisRotationComponent)
            && entity.hasComponent!Orientation3DComponent;
    }

    public override void update() {
        foreach (entity; entities) {
            entity.maybeWithComponent!Orientation3DComponent((c) {
                auto rotation = QuaternionD();
                entity.maybeWithComponent!RotationComponent((cr) {
                    rotation = cr.rotation;
                });

                entity.maybeWithComponent!AxisRotationComponent((cr) {
                    rotation = QuaternionD.createRotation(cr.radianAngle, cr.axis);
                });

                c.orientation = c.orientation * rotation;
            });
        }
    }
}

class TranslationEntityProcessor : EntityProcessor {
    this() {
        priority = StandardEntityProcessorPriority.translation;
    }

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
