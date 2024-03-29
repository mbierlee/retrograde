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

module retrograde.components.firstperson;

import retrograde.core.entity : EntityComponent, EntityComponentIdentity;
import retrograde.core.math : scalar;

/**
 * A component that allows an entity to move in a first person manner.
 *
 * Use the FirstPersonControllableProcessor to allow entities with this component to
 * move and look around in first-person.
 */
class FirstPersonControllableComponent : EntityComponent {
    mixin EntityComponentIdentity!"FirstPersonControllableComponent";

    scalar translationSpeedModifier = 1;
    scalar rotationSpeedModifier = 1;

    scalar moveForwards = 0;
    scalar moveBackwards = 0;
    scalar strafeLeft = 0;
    scalar strafeRight = 0;

    scalar lookUp = 0;
    scalar lookDown = 0;
    scalar lookLeft = 0;
    scalar lookRight = 0;

    this() {
    }

    this(scalar translationSpeedModifier, scalar rotationSpeedModifier) {
        this.translationSpeedModifier = translationSpeedModifier;
        this.rotationSpeedModifier = rotationSpeedModifier;
    }
}
