/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.runtime;

import retrograde.core.game : Game;
import retrograde.core.platform : Platform, PlatformSettings, NullPlatform;
import retrograde.core.versioning : Version;

import poodinis : Inject, Value;

import std.datetime.stopwatch : StopWatch, Duration, dur;
import std.experimental.logger : Logger;

enum EngineVersion = Version(0, 0, 0, "alpha");

/**
 * The Engine Runtime kick-starts the game and runs the game's core loop.
 */
interface EngineRuntime {
    /**
     * Whether the engine is currently terminatable.
     * In the StandardEngineRuntime it is set when terminate() is called.
     */
    bool isTerminatable();

    /**
     * The targeted time in milliseconds an update cycle has.
     * In the StandardEngineRuntime, when exceeded, the engine tries to catch up in the next cycle.
     * Some systems, such as a render system, might use this to dynamically optimize performance.
     */
    long targetTickTimeMs();

    /**
     * A limit imposed on the engine for the amount of ticks it is allowed to catch up to.
     * In the StandardEngineRuntime, when the engine goes over the amount of lagged ticks, it will take a break to 
     * render and resume catching up during the next cycle.
     * Some systems, such as a render system, might use this to dynamically optimize performance.
     */
    long lagTickLimit();

    /**
     * Starts the game.
     * The StandardEngineRuntime starts by initializing it, running its update and render cycles and cleaning it up
     * after termination.
     *
     * Params:
     *  platformSettings = Settings used to initialize the platform
     */
    void startGame(const PlatformSettings platformSettings);

    /**
     * Terminates the runtime.
     * In the StandardEngineRuntime termination may be delayed until the start of the next loop cycle.
     */
    void terminate();
}

/**
 * Standard implementation of an EngineRuntime.
 * This implementation has a gameloop with a fixed-step update time and variable render rate.
 */
class StandardEngineRuntime : EngineRuntime {
    private @Inject Game game;
    private @Inject Platform platform;
    private @Inject Logger logger;

    private @Value("logging.logEngineInfo") bool logEngineInfo;

    private bool _isTerminatable = false;

    override bool isTerminatable() {
        return _isTerminatable;
    }

    override long targetTickTimeMs() {
        return 10L;
    }

    override long lagTickLimit() {
        return 100L;
    }

    override void startGame(const PlatformSettings platformSettings) {
        assert(this.game !is null, "No Game instance is assigned to this runtime.");

        if (logEngineInfo) {
            logger.infof("Retrograde Engine v%s", EngineVersion);
        }

        this.platform.initialize(platformSettings);
        this.game.initialize();
        loopWithFixedTimeStepVariableRenderRate();
        this.game.terminate();
        this.platform.terminate();
    }

    private void loopWithFixedTimeStepVariableRenderRate() {
        auto tickTimeStopWatch = new StopWatch();
        auto lagDuration = Duration.zero;
        const auto targetTickTimeDuration = dur!"msecs"(this.targetTickTimeMs);
        tickTimeStopWatch.start();

        while (!this.isTerminatable) {
            const auto elapsedTickTime = tickTimeStopWatch.peek();
            tickTimeStopWatch.reset();
            lagDuration += elapsedTickTime;

            auto lagCompensationTicks = 0L;
            while (lagDuration >= targetTickTimeDuration) {
                lagCompensationTicks++;
                if (lagCompensationTicks > this.lagTickLimit || this.isTerminatable) {
                    break;
                }

                this.platform.update();
                this.game.update();
                lagDuration -= targetTickTimeDuration;
            }

            auto extraPolation = lagDuration / targetTickTimeDuration;
            this.platform.render(extraPolation);
            this.game.render(extraPolation);
        }
    }

    override void terminate() {
        _isTerminatable = true;
    }
}

version (customizeableGc) {
} else {
    extern (C) __gshared bool rt_cmdline_enabled = false;
    extern (C) __gshared bool rt_envvars_enabled = false;
}

version (unittest) {
    import poodinis.valueinjector.mirage : parseIniConfig;

    class TestGame : Game {
        bool isInitialized;
        bool isUpdated;
        bool isRendered;
        bool isCleanedUp;

        private @Inject EngineRuntime runtime;

        override void initialize() {
            isInitialized = true;
        }

        override void update() {
            isUpdated = true;
            runtime.terminate();
        }

        override void render(double extraPolation) {
            isRendered = true;
        }

        override void terminate() {
            isCleanedUp = true;
        }
    }

    @("StandardEngineRuntime lifecycle")
    unittest {
        import retrograde.core.platform : NullPlatform;
        import std.experimental.logger : NullLogger;
        import poodinis : DependencyContainer, initializedBy;

        auto dependencies = new shared DependencyContainer();

        dependencies.parseIniConfig(import("./engine.ini"));

        dependencies.register!(Game, TestGame);
        dependencies.register!(EngineRuntime, StandardEngineRuntime);
        dependencies.register!(Platform, NullPlatform);
        dependencies.register!(Logger, NullLogger).initializedBy({
            return new NullLogger();
        });

        auto runtime = dependencies.resolve!StandardEngineRuntime;
        runtime.startGame(new PlatformSettings());
        const auto game = dependencies.resolve!TestGame;

        assert(game.isInitialized);
        assert(game.isUpdated);
        assert(game.isRendered);
        assert(game.isCleanedUp);
    }
}
