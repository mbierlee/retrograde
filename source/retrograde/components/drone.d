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

module retrograde.components.drone;

import retrograde.core.entity : EntityComponent, EntityComponentIdentity;
import retrograde.core.math : scalar;

/**
 * Entities with a DroneControllableComponent will be controllable via drone controls.
 *
 * Use the DroneControllerProcessor to control these entities.
 */
class DroneControllableComponent : EntityComponent {
    mixin EntityComponentIdentity!"DroneControllableComponent";

    scalar translationSpeedModifier = 1;
    scalar rotationSpeedModifier = 1;

    scalar pitchUp = 0;
    scalar pitchDown = 0;
    scalar yawLeft = 0;
    scalar yawRight = 0;
    scalar bankLeft = 0;
    scalar bankRight = 0;

    scalar moveForwards = 0;
    scalar moveBackwards = 0;
    scalar moveLeft = 0;
    scalar moveRight = 0;
    scalar moveUp = 0;
    scalar moveDown = 0;

    this() {
    }

    this(scalar translationSpeedModifier, scalar rotationSpeedModifier) {
        this.translationSpeedModifier = translationSpeedModifier;
        this.rotationSpeedModifier = rotationSpeedModifier;
    }
}
