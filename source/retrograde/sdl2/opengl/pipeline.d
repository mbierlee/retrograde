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

module retrograde.sdl2.opengl.pipeline;

version(Have_derelict_sdl2) {
version(Have_derelict_gl3) {

import retrograde.rendering.threedee.opengl.renderer;
import retrograde.file;
import retrograde.math;

import derelict.sdl2.sdl;
import derelict.sdl2.image;

import std.array;
import std.string;

class SdlOpenGlTextureLoader {
    public OpenGlTexture load(File textureFile) {
        // TODO: Optimize! Maybe make OpenGL texture subclass which simply accepts SDL surfaces?

        SDL_Surface* textureSurface = IMG_Load(textureFile.fileName.toStringz());
        if (!textureSurface) {
            //TODO: Throw fuzz
            return null;
        }

        SDL_Surface* convertedTextureSurface = SDL_ConvertSurfaceFormat(textureSurface, SDL_PIXELFORMAT_ABGR8888, 0);
        SDL_FreeSurface(textureSurface);
        if (!convertedTextureSurface) {
            //TODO: Throw fuzz
            return null;
        }

        auto dimensions = RectangleU(0, 0, convertedTextureSurface.w, convertedTextureSurface.h);
        auto dataLength = convertedTextureSurface.w * convertedTextureSurface.h * 4;
        auto texture = new OpenGlTexture(array(cast(ubyte[]) convertedTextureSurface.pixels[0 .. dataLength]), dimensions, true, textureFile.fileName);
        SDL_FreeSurface(convertedTextureSurface);

        return texture;
    }
}

}
}
