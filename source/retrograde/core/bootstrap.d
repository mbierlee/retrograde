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

module retrograde.core.bootstrap;

import retrograde.core.runtime;
import retrograde.core.game;
import retrograde.core.entity;
import retrograde.core.communication;
import retrograde.platform.api;

import poodinis;

version (Windows)
{
    alias DefaultPlatform = NullPlatform; // TODO: Switch to Windows implementation
}
else
{
    alias DefaultPlatform = NullPlatform;
}

/**
 * Bootstrap function for quickly setting up the DI framework with all required and typically used components.
 * After set-up, the game is started.
 */
public void startGame(GameType : Game, EngineRuntimeType:
        EngineRuntime = StandardEngineRuntime, PlatformType:
        Platform = DefaultPlatform)(
        shared DependencyContainer dependencies = new shared DependencyContainer())
{

    dependencies.register!(EngineRuntime, EngineRuntimeType);
    dependencies.register!(Game, GameType);
    dependencies.register!(Platform, PlatformType);
    dependencies.register!EntityManager;
    dependencies.register!MessageHandler;

    auto runtime = dependencies.resolve!EngineRuntime;
    runtime.startGame();
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
        startGame!TestGame(dependencies);
        const game = dependencies.resolve!TestGame;
        assert(game.isInitialized);
    }
}
