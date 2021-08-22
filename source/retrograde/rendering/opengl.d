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

module retrograde.rendering.opengl;

version (Have_bindbc_opengl) {
    import retrograde.core.rendering;
    import retrograde.core.entity : Entity;

    class OpenGlRenderer : Renderer {
        override public int getContextHintMayor() {
            return 4;
        }

        override public int getContextHintMinor() {
            return 6;
        }

        override public bool acceptsEntity(Entity entity) {
            return false;
        }
    }
}
