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

import retrograde.core.storage : StorageApi, GenericStorageApi;

/**
 * API for interfacing with the underlying platform.
 * E.g. a PC desktop OS or a game console platform.
 */
interface Platform {
    /**
     * Initialize a platform with the given platform settings.
     * Params:
     *  platformSettings = Platform-dependent settings. Platforms might accept subtypes of this class only.
     */
    void initialize(const PlatformSettings platformSettings);

    /**
     * Called by the engine's runtime during the update loop.
     */
    void update();

    /**
     * Called by the engine's runtime during the render loop.
     */
    void render(double extraPolation);

    /**
     * Terminates the application gracefully via the platform.
     */
    void terminate();

    /**
     * Return the platform's viewport definitions.
     * For some platform this makes no sense and might return a Viewport where all values are 0.
     */
    Viewport getViewport();

    /**
     * Returns the platform's default storage API. 
     * This might be different from the one available through dependency injection.
     */
    StorageApi storage();
}

/**
 * Platform for interacting with the API when there is no underlying platform.
 */
class NullPlatform : Platform {
    private StorageApi _storage = new GenericStorageApi();

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

    StorageApi storage() {
        return _storage;
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
