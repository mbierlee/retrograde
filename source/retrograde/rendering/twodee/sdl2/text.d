/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2017 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.rendering.twodee.sdl2.text;

version(Have_derelict_sdl2) {

import retrograde.entity;
import retrograde.font;
import retrograde.rendering.twodee.sdl2.renderer;
import retrograde.file;
import retrograde.graphics;
import retrograde.stringid;

import derelict.sdl2.ttf;
import derelict.sdl2.sdl;

import poodinis;

import std.typecons;
import std.string;
import std.conv;
import std.exception;

class Sdl2TextProcessor : EntityProcessor {

	@Autowire
	private Sdl2RenderSystem renderer;

	public override bool acceptsEntity(Entity entity) {
		return entity.hasComponent!RenderableTextComponent
			&& entity.hasComponent!FontComponent
			&& entity.hasComponent!TextComponent
			&& entity.hasComponent!TextureComponent;
	}

	public override void update() {
		foreach(entity; _entities.getAll()) {
			renderEntityText(entity);
		}
	}

	private void renderEntityText(Entity entity) {
		entity.withComponent!TextComponent((component) {
			if (component.isChanged()) {
				auto fontComponent = entity.getComponent!FontComponent;
				auto font = cast(Sdl2Font) fontComponent.font;
				if (font is null) {
					return;
				}

				TTF_Font* ttfFont = font.ttfFont;
				SDL_Surface* surface = TTF_RenderUTF8_Blended(ttfFont, component.text.toStringz(), SDL_Color(255, 255, 255, 255));
				SDL_Texture* texture = renderer.createTextureFromSurface(surface);
				SDL_FreeSurface(surface);
				auto textureComponent = entity.getComponent!TextureComponent;
				// TODO: Free old texture?
				textureComponent.texture = new Sdl2Texture(texture, font.fontName);
				component.clearChanged();
			}
		});
	}

}

class Sdl2Font : Font {
	private TTF_Font* _ttfFont;

	public TTF_Font* ttfFont() {
		return _ttfFont;
	}

	this(TTF_Font* ttfFont, string fontName, uint pointSize, ulong index) {
		super(fontName, pointSize, index);
		this._ttfFont = ttfFont;
	}
}

class FontLoadException : Exception {
	mixin basicExceptionCtors;
}

class Sdl2FontComponentFactory : FontComponentFactory {
	private FontComponent[Tuple!(string, uint, ulong)] fontComponentCache;

	public override FontComponent create(File fontFile, uint pointSize, ulong index = 0) {
		auto key = tuple(fontFile.fileName, pointSize, index);
		auto cachedComponent = key in fontComponentCache;
		if (cachedComponent) {
			return *cachedComponent;
		}

		auto loadedFont = TTF_OpenFontIndex(fontFile.fileName.toStringz(), cast(int) pointSize, cast(int) index);
		if (!loadedFont) {
			throw new FontLoadException(format("Cannot load %s: %s", fontFile.fileName, to!string(TTF_GetError())));
		}

		auto newComponent = new FontComponent(new Sdl2Font(loadedFont, fontFile.fileName, pointSize, index));
		fontComponentCache[key] = newComponent;
		return newComponent;
	}
}

}
