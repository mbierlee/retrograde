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

import retrograde.core.runtime;
import retrograde.core.game;
import retrograde.core.entity;
import retrograde.core.communication;
import retrograde.core.platform;
import retrograde.platform.glfw;

import poodinis;

version (Have_glfw_d)
{
    alias DefaultPlatform = GlfwPlatform;
    alias DefaultPlatformSettings = GlfwPlatformSettings;
}
else
{
    alias DefaultPlatform = NullPlatform;
    alias DefaultPlatformSettings = PlatformSettings;
}

/**
 * Bootstrap function for quickly setting up the DI framework with all required and typically used components.
 * After set-up, the game is started.
 */
public void startGame(GameType : Game, EngineRuntimeType:
        EngineRuntime = StandardEngineRuntime, PlatformType:
        Platform = DefaultPlatform)(const PlatformSettings platformSettings = new DefaultPlatformSettings(),
        shared DependencyContainer dependencies = new shared DependencyContainer())
{

    dependencies.register!(EngineRuntime, EngineRuntimeType);
    dependencies.register!(Game, GameType);
    dependencies.register!(Platform, PlatformType);
    dependencies.register!EntityManager;
    dependencies.register!MessageHandler;

    auto runtime = dependencies.resolve!EngineRuntime;
    runtime.startGame(platformSettings);
}

version (unittest)
{
    class TestGame : Game
    {
        public bool isInitialized;

        @Autowire private EngineRuntime runtime;
        @Autowire EntityManager entityManager;
        @Autowire MessageHandler messageHandler;

        public override void initialize()
        {
            isInitialized = true;
        }

        public override void update()
        {
            runtime.terminate();
        }

        public override void render(double extraPolation)
        {
        }

        public override void terminate()
        {
        }
    }

    @("Bootstrap of testgame")
    unittest
    {
        auto dependencies = new shared DependencyContainer();
        startGame!TestGame(new PlatformSettings(), dependencies);
        const game = dependencies.resolve!TestGame;
        assert(game.isInitialized);
    }
}
