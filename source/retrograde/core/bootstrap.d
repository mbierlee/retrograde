module retrograde.core.bootstrap;

import retrograde.core.runtime;
import retrograde.core.game;

import poodinis;

/**
 * Bootstrap function for quickly setting up the DI framework with all required and typically used components.
 * After set-up, the game is started.
 */
public void startGame(GameType : Game, EngineRuntimeType:
        EngineRuntime = StandardEngineRuntime)(
        shared DependencyContainer dependencies = new shared DependencyContainer())
{

    dependencies.register!(EngineRuntime, EngineRuntimeType);
    dependencies.register!(Game, GameType);
    auto runtime = dependencies.resolve!EngineRuntime;
    runtime.startGame();
}

version (unittest)
{
    class TestGame : Game
    {
        public bool isInitialized;

        @Autowire private EngineRuntime runtime;

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

        public override void cleanup()
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
