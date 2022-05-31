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

    public scalar translationSpeedModifier = 1;
    public scalar rotationSpeedModifier = 1;

    public scalar pitchUp = 0;
    public scalar pitchDown = 0;
    public scalar yawLeft = 0;
    public scalar yawRight = 0;
    public scalar bankLeft = 0;
    public scalar bankRight = 0;

    this() {
    }

    this(scalar translationSpeedModifier, scalar rotationSpeedModifier) {
        this.translationSpeedModifier = translationSpeedModifier;
        this.rotationSpeedModifier = rotationSpeedModifier;
    }
}
