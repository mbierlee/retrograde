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

module retrograde.sdl2.context;

version(Have_derelict_sdl2) {

import poodinis;

import retrograde.sdl2.renderer;
import retrograde.sdl2.window;
import retrograde.sdl2.event;
import retrograde.sdl2.input;
import retrograde.sdl2.text;
import retrograde.entity;
import retrograde.messaging;
import retrograde.graphics;
import retrograde.font;

class Sdl2RendererContext : ApplicationContext {
	public override void registerDependencies(shared(DependencyContainer) container) {
		container.register!Sdl2WindowCreator;
		container.register!(EntityProcessor, Sdl2RenderSystem);
		container.register!(EntityProcessor, Sdl2TextProcessor);
		container.register!(SubRenderer, SpriteSubRenderer);
		container.register!(EventHandler, Sdl2EventHandler);
		container.register!Sdl2InputDeviceManager;
		container.register!(TextureComponentFactory, Sdl2TextureComponentFactory);
		container.register!(FontComponentFactory, Sdl2FontComponentFactory);
	}
}

}
