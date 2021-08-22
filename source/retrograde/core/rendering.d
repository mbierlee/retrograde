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
}

class NullRenderer : Renderer {
    override public bool acceptsEntity(Entity entity) {
        return false;
    }
}
