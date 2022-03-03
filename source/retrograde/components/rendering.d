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

module retrograde.components.rendering;

import retrograde.core.entity : EntityComponent, EntityComponentIdentity;
import retrograde.core.rendering : CameraConfiguration;

/**
 * Entities with the RenderableComponent will be rendered by a render system.
 */
class RenderableComponent : EntityComponent {
    mixin EntityComponentIdentity!"RenderableComponent";
}

/**
 * Entities with the DefaultShaderProgramComponent will use the render system's default shader program if it is available.
 */
class DefaultShaderProgramComponent : EntityComponent {
    mixin EntityComponentIdentity!"DefaultShaderProgramComponent";
}

/**
 * Entities with the CameraComponent are considered cameras.
 *
 * Together with a Position3DComponent and Orientation3DComponent they will determine
 * what the user will see.
 */
class CameraComponent : EntityComponent {
    mixin EntityComponentIdentity!"CameraComponent";

    CameraConfiguration cameraConfiguration;

    this() {
    }

    this(CameraConfiguration cameraConfiguration) {
        this.cameraConfiguration = cameraConfiguration;
    }
}

/**
 * Entities with an ActiveCameraComponent are considered active and
 * will be the ones used to render the view.
 *
 * Typically there is only one camera active. Entities still need to have a CameraComponent 
 * as well or else they are not considered to be cameras.
 */
class ActiveCameraComponent : EntityComponent {
    mixin EntityComponentIdentity!"ActiveCameraComponent";
}
