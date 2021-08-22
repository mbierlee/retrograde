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

    import std.experimental.logger : Logger;

    import poodinis;

    import bindbc.opengl;

    class OpenGlRenderer : Renderer {
        private @Autowire Logger logger;

        override public int getContextHintMayor() {
            return 4;
        }

        override public int getContextHintMinor() {
            return 6;
        }

        override public bool acceptsEntity(Entity entity) {
            return false;
        }

        override public void initialize() {
            GLSupport support = loadOpenGL();
            if (support == GLSupport.badLibrary || support == GLSupport.noLibrary) {
                logger.error("Failed to load OpenGL Library.");
                return;
            }

            if (support == GLSupport.noContext) {
                logger.error("No window context was created by the platform. Create it first.");
                return;
            }

            if (support.gl46) {
                logger.info("OpenGL 4.6 renderer initialized.");
            }
        }

        override public void draw() {
        }

    }
}
