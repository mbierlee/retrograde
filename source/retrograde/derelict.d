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

version(Have_derelict_assimp3) {
    import derelict.assimp3.assimp;
}

version(Have_derelict_sdl2) {
    import derelict.sdl2.sdl;
    import derelict.sdl2.image;
    import derelict.sdl2.ttf;
}

version(Have_derelict_gl3) {
    import derelict.opengl3.gl3;
}

struct DllLoadContext {
    version(Have_derelict_sdl2) {
        bool loadSdl2Image = true;
        bool loadSdl2Ttf = true;
    }

    version(Have_derelict_gl3) {
        bool loadOpenGl3 = true;
    }

    version(Have_derelict_assimp3) {
        bool loadAssimp3 = true;
    }
}

version(Have_derelict_sdl2) {
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
        version(Have_derelict_sdl2) {
            DerelictSDL2.load();
            loadContext.loadSdl2Image && DerelictSDL2Image.load();
            loadContext.loadSdl2Ttf && DerelictSDL2ttf.load();
            loadedTtfLib = loadContext.loadSdl2Ttf;
        }

        version(Have_derelict_gl3) {
            loadContext.loadOpenGl3 && DerelictGL3.load();
        }

        version(Have_derelict_assimp3) {
            loadContext.loadAssimp3 && DerelictASSIMP3.load();
        }

        loadedDlls = true;
    }

    version(Have_derelict_sdl2) {
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
