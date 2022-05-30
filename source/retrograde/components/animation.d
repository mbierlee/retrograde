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

module retrograde.components.animation;

import retrograde.core.entity : EntityComponent, EntityComponentIdentity;
import retrograde.core.math : QuaternionD, Vector3D;

/**
 * An entity component that adds a rotational spin to an entity.
 *
 * Make sure to add the SpinningEntityProcessor to the entity system and that
 * the entity has a Orientation3DComponent.
 */
class SpinningComponent : EntityComponent {
    mixin EntityComponentIdentity!"SpinningComponent";

    /**
     * The direction and amount of rotation applied to the entity.
     *
     * The rotation will be applied per frame, so the speed depends on the update loop
     * framerate (not the renderer framerate.)
     */
    public QuaternionD rotation;

    this() {

    }

    this(QuaternionD rotation) {
        this.rotation = rotation;
    }
}

/** 
 * An entity component that adds a constant translation to an entity.
 *
 * Make sure to add the TranslatingEntityProcessor to the entity system and that
 * the entity has a Position3DComponent.
 */
class TranslatingComponent : EntityComponent {
    mixin EntityComponentIdentity!"TranslatingComponent";

    /** 
     * Direction and amount of translation applied to the entity.
     *
     * The translation will be applied per frame, so the speed depends on the update loop
     * framerate (not the renderer framerate.)
     */
    public Vector3D translation = Vector3D(0);

    this() {

    }

    this(Vector3D translation) {
        this.translation = translation;
    }
}
