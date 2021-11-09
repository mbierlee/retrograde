/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.components.rendering;

import retrograde.core.entity : EntityComponent, EntityComponentIdentity;

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
