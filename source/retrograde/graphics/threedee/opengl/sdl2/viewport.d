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

module retrograde.graphics.threedee.opengl.sdl2.viewport;

version(Have_derelict_sdl2) {
version(Have_derelict_gl3) {

import retrograde.viewport;
import retrograde.sdl2.window;
import retrograde.math;

import derelict.sdl2.sdl;
import derelict.opengl3.gl3;

import poodinis;

class SdlOpenglViewport : Viewport {
    private SDL_Window* window;
    private SDL_GLContext glContext;

    this(SDL_Window* window, SDL_GLContext glContext) {
        this.window = window;
        this.glContext = glContext;
    }

    public @property RectangleI dimensions() {
        int windowXPosition, windowYPosition, windowWidth, windowHeight;
        SDL_GetWindowPosition(window, &windowXPosition, &windowYPosition);
        SDL_GetWindowSize(window, &windowWidth, &windowHeight);
        return RectangleI(windowXPosition, windowYPosition, windowWidth, windowHeight);
    }

    public void swapBuffers() {
        SDL_GL_SwapWindow(window);
    }

    public void cleanup() {
        if (glContext) {
            SDL_GL_DeleteContext(glContext);
        }

        if (window) {
            SDL_DestroyWindow(window);
        }
    }
}

class SdlOpenglViewportFactory : ViewportFactory {

    @Autowire
    private Sdl2WindowCreator windowCreator;

    public Viewport create() {
        auto window = windowCreator.createWindow(SDL_WINDOW_SHOWN | SDL_WINDOW_OPENGL);
        if (!window) {
            throw new Exception("Could not create SDL2 window");
        }

        auto glContext = SDL_GL_CreateContext(window);
        if (!glContext) {
            throw new Exception("Could not create OpenGL context");
        }

        return new SdlOpenglViewport(window, glContext);
    }
}

} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict OpenGL3. Please add it as dependency to your project.");    
    }
}
} else {
    debug(assertDependencies) {
        static assert(0 , "This module requires Derelict SDL2. Please add it as dependency to your project.");    
    }
}