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

module retrograde.derelict;

import derelict.assimp3.assimp;

version (sdl2) {
	import derelict.sdl2.sdl;
	import derelict.sdl2.image;
	import derelict.sdl2.ttf;
}

version (opengl) {
	import derelict.opengl3.gl3;
}

struct DllLoadContext {
	version (sdl2) {
		bool loadSdl2Image = true;
		bool loadSdl2Ttf = true;
	}

	version (opengl) {
		bool loadOpenGl3 = true;
	}

	bool loadAssimp3 = true;
}

version (sdl2) {
	struct InitializationContext {
		bool initializeVideo = true;
		bool initializeJoystick = false;
	}
}

class DerelictLibrary {
	private static bool loadedTtfLib = false;
	private static bool loadedDlls = false;
	private static bool _initializedSdl = false;

	public static bool dllsAreLoaded() {
		return loadedDlls;
	}

	public static bool sdlIsInitialized() {
		return _initializedSdl;
	}

	public static bool loadedAndInitialized() {
		return dllsAreLoaded() && sdlIsInitialized();
	}

	public static void loadDerelictDlls(DllLoadContext loadContext = DllLoadContext()) {
		version (sdl2) {
			DerelictSDL2.load();
			loadContext.loadSdl2Image && DerelictSDL2Image.load();
			loadContext.loadSdl2Ttf && DerelictSDL2ttf.load();
			loadedTtfLib = loadContext.loadSdl2Ttf;
		}

		version (opengl) {
			loadContext.loadOpenGl3 && DerelictGL3.load();
		}

		loadContext.loadAssimp3 && DerelictASSIMP3.load();

		loadedDlls = true;
	}

	version (sdl2) {
		public static bool initializeSdl(InitializationContext context = InitializationContext()) {
			Uint32 initFlags = 0;

			if (context.initializeVideo) initFlags |= SDL_INIT_VIDEO;
			if (context.initializeJoystick) initFlags |= SDL_INIT_JOYSTICK;

			if (SDL_Init(initFlags) < 0) {
				return false;
			}

			if (loadedTtfLib && (TTF_Init() < 0)) {
				return false;
			}

			_initializedSdl = true;
			return true;
		}

		public static void quitSdl() {
			if (loadedTtfLib) {
				TTF_Quit();
			}

			SDL_Quit();
		}
	}
}
