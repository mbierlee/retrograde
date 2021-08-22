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

module retrograde.core.rendering;

import retrograde.core.entity : EntityProcessor, Entity;

abstract class Renderer : EntityProcessor {
    /**
     * Desired mayor version of the rendering API to be used.
     *
     * Typically used by the platform to initialize the renderer.
     * E.g. "4" for OpenGL 4.6
     */
    public int getContextHintMayor();

    /**
     * Desired minor version of the rendering API to be used.
     *
     * Typically used by the platform to initialize the renderer.
     * E.g. "6" for OpenGL 4.6
     */
    public int getContextHintMinor();
}

class NullRenderer : Renderer {
    override public bool acceptsEntity(Entity entity) {
        return false;
    }

    override public int getContextHintMayor() {
        return 0;
    }

    override public int getContextHintMinor() {
        return 0;
    }
}
