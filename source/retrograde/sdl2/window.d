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

module retrograde.sdl2.window;

version(Have_derelict_sdl2) {

import retrograde.application;
import retrograde.game;

import poodinis;

import derelict.sdl2.sdl;

import std.string;

class Sdl2WindowCreator {

    @Autowire
    private Game game;

    public SDL_Window* createWindow(SDL_WindowFlags windowFlags = SDL_WINDOW_SHOWN) {
        auto creationContext = game.windowCreationContext;
        auto title = game.name;

        auto xPos = creationContext.xWindowPosition == WindowPosition.centered ? SDL_WINDOWPOS_CENTERED : creationContext.x;
        auto yPos = creationContext.yWindowPosition == WindowPosition.centered ? SDL_WINDOWPOS_CENTERED : creationContext.y;
        auto width = creationContext.width;
        auto height = creationContext.height;

        return SDL_CreateWindow(title.toStringz(), xPos, yPos, width, height, windowFlags);
    }

}

}
