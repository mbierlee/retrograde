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

module retrograde.core.platform;

/**
 * API for interfacing with the underlying platform.
 * E.g. a PC desktop OS or a game console platform.
 */
interface Platform {
    void initialize(const PlatformSettings platformSettings);
    void update();
    void render(double extraPolation);
    void terminate();
    Viewport getViewport();
}

/**
 * Platform for interacting with the API when there is no underlying platform.
 */
class NullPlatform : Platform {
    void initialize(const PlatformSettings platformSettings) {
    }

    void update() {
    }

    void render(double extraPolation) {
    }

    void terminate() {
    }

    Viewport getViewport() {
        return Viewport();
    }
}

/**
 * Base for platform-dependent initialization settings.
 */
class PlatformSettings {
}

/**
 * Viewport dimensions, typically used by a renderer to determine
 * render buffer size.
 */
struct Viewport {
    int x;
    int y;
    int width;
    int height;
}
