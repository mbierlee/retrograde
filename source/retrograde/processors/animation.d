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

import retrograde.components.animation : SpinningComponent;
import retrograde.components.geometry : Orientation3DComponent;

class SpinningEntityProcessor : EntityProcessor {
    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!SpinningComponent && entity.hasComponent!Orientation3DComponent;
    }

    public override void update() {
        foreach (entity; entities) {
            entity.maybeWithComponent!Orientation3DComponent((c) {
                auto rotation = entity.getFromComponent!SpinningComponent(c => c.rotation, QuaternionD());
                c.orientation = c.orientation * rotation;
            });
        }
    }
}
