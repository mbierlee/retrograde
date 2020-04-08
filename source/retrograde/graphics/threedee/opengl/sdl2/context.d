/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2020 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.graphics.threedee.opengl.sdl2.context;

version(Have_derelict_sdl2) {
version(Have_derelict_gl3) {

import retrograde.sdl2.opengl.viewport;
import retrograde.viewport;
import retrograde.entity;
import retrograde.graphics.threedee.opengl.renderer;

import poodinis;

class Sdl2OpenGlRendererContext : ApplicationContext {
    public override void registerDependencies(shared(DependencyContainer) container) {
        container.register!(EntityProcessor, OpenGlRenderSystem);
        container.register!(ViewportFactory, SdlOpenglViewportFactory);
    }
}

} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict OpenGL 3. Please add it as dependency to your project.");    
    }
}
} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict SDL2. Please add it as dependency to your project.");    
    }
}