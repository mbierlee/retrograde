/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2022 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.platform;

import retrograde.core.storage : StorageSystem, GenericStorageSystem;
import retrograde.core.stringid : StringId, sid;
import retrograde.core.messaging : Message;

/** 
 * Used by implementations of Platforms to message on platform-specific events,
 * such as window resized, system-wide pauses, etc.
 */
const auto platformEventChannel = sid("platform_event_channel");

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
     * Returns the platform's default storage system. 
     * This might be different from the one available through dependency injection.
     */
    StorageSystem storageSystem();
}

/**
 * Platform for interacting with the API when there is no underlying platform.
 */
class NullPlatform : Platform {
    private StorageSystem _storage = new GenericStorageSystem();

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

    StorageSystem storageSystem() {
        return _storage;
    }
}

/**
 * Base for platform-dependent initialization settings.
 */
class PlatformSettings {
}

/**
 * Viewport dimensions, typically used by a render system to determine
 * framebuffer size.
 */
struct Viewport {
    int x;
    int y;
    int width;
    int height;
}

/** 
 * An event emitted when the platform's viewport is resized.
 */
class ViewportResizeEventMessage : Message {
    static const StringId msgId = sid("ev_viewport_resize");

    Viewport newViewport;

    this(Viewport newViewport) {
        super(msgId);
        this.newViewport = newViewport;
    }

    static immutable(ViewportResizeEventMessage) create(const Viewport newViewport) {
        return cast(immutable(ViewportResizeEventMessage)) new ViewportResizeEventMessage(
            newViewport);
    }
}
