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

module retrograde.bootstrap;

import retrograde.core.runtime : EngineRuntime, StandardEngineRuntime;
import retrograde.core.game : Game;
import retrograde.core.entity : EntityManager;
import retrograde.core.messaging : MessageHandler;
import retrograde.core.platform : Platform, PlatformSettings, NullPlatform;
import retrograde.core.logging : StdoutLogger;
import retrograde.core.input : InputMapper;
import retrograde.core.rendering : Renderer, NullRenderer;
import retrograde.core.storage : StorageApi, GenericStorageApi;

import poodinis;
import poodinis.valueinjector.properd;

import properd;

import std.experimental.logger : Logger, MultiLogger, sharedLog;
import std.file : exists;

version (Have_glfw_d) {
    import retrograde.platform.glfw : GlfwPlatform, GlfwPlatformSettings;

    alias DefaultPlatform = GlfwPlatform;
    alias DefaultPlatformSettings = GlfwPlatformSettings;
} else {
    alias DefaultPlatform = NullPlatform;
    alias DefaultPlatformSettings = PlatformSettings;
}

version (Have_bindbc_opengl) {
    import retrograde.rendering.opengl : OpenGlRenderer;

    alias DefaultRenderer = OpenGlRenderer;
} else {
    alias DefaultRenderer = NullRenderer;
}

/**
 * Bootstrap function for quickly setting up the DI framework with all required and typically used components.
 * After set-up, the game is started.
 */
public void startGame(GameType : Game, EngineRuntimeType:
        EngineRuntime = StandardEngineRuntime,
    PlatformType:
        Platform = DefaultPlatform, RendererType:
        Renderer = DefaultRenderer)(const PlatformSettings platformSettings = new DefaultPlatformSettings(),
        shared DependencyContainer dependencies = new shared DependencyContainer()) {

    dependencies.register!(EngineRuntime, EngineRuntimeType);
    dependencies.register!(Game, GameType);
    dependencies.register!(Renderer, RendererType);
    dependencies.register!(Platform, PlatformType);
    dependencies.register!EntityManager;
    dependencies.register!MessageHandler;
    dependencies.register!InputMapper;
    dependencies.register!(StorageApi, GenericStorageApi);

    const propertyFile = "./engine.cfg";
    string[string] engineProperties;
    if (exists(propertyFile)) {
        engineProperties = readProperties(propertyFile);
    } else {
        string defaultConfig = import(propertyFile);
        engineProperties = parseProperties(defaultConfig);
    }

    dependencies.registerProperdProperties(engineProperties);

    dependencies.register!Logger.initializedBy({
        auto logger = new MultiLogger();

        auto stdoutLogger = new StdoutLogger();
        if (stdoutLogger.stdoutIsAvailable()) {
            logger.insertLogger("stdoutLogger", stdoutLogger);
        }

        sharedLog = logger;
        return logger;
    });

    static if (!is(RendererType == NullRenderer)) {
        auto renderer = dependencies.resolve!Renderer;
        auto entityManager = dependencies.resolve!EntityManager;
        entityManager.addEntityProcessor(renderer);
    }

    auto runtime = dependencies.resolve!EngineRuntime;
    runtime.startGame(platformSettings);
}

version (unittest) {
    class TestGame : Game {
        public bool isInitialized;

        @Autowire private EngineRuntime runtime;
        @Autowire EntityManager entityManager;
        @Autowire MessageHandler messageHandler;

        public override void initialize() {
            isInitialized = true;
        }

        public override void update() {
            runtime.terminate();
        }

        public override void render(double extraPolation) {
        }

        public override void terminate() {
        }
    }

    @("Bootstrap of testgame")
    unittest {
        auto dependencies = new shared DependencyContainer();
        startGame!TestGame(new PlatformSettings(), dependencies);
        const game = dependencies.resolve!TestGame;
        assert(game.isInitialized);
    }
}
