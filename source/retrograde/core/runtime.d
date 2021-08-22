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

module retrograde.core.runtime;

import retrograde.core.game;
import retrograde.core.platform;

import poodinis;

import std.datetime.stopwatch : StopWatch, Duration, dur;
import std.experimental.logger : Logger, NullLogger;

enum EngineVersionMajor = 0;
enum EngineVersionMinor = 0;
enum EngineVersionPatch = 0;
enum EngineVersionDescriptor = "-alpha";

/**
 * The Engine Runtime kick-starts the game and runs the game's core loop.
 */
interface EngineRuntime {
    /**
     * Whether the engine is currently terminatable.
     * In the StandardEngineRuntime it is set when terminate() is called.
     */
    @property bool isTerminatable();

    /**
     * The targeted time a frame has for updating and rendering.
     * In the StandardEngineRuntime, when exceeded, the engine tries to catch up in the next loop cycle.
     * Some systems, such as a renderer, might use this to dynamically optimize performance.
     */
    @property long targetFrameTime();

    /**
     * A limit imposed on the engine for the amount of frames it is allowed to catch up to.
     * In the StandardEngineRuntime, when the engine goes over the amount of lagged frames, it will take a break to 
     * render and resume catching up during the next loop cycle.
     * Some systems, such as a renderer, might use this to dynamically optimize performance.
     */
    @property long lagFrameLimit();

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
    @Autowire private Game game;
    @Autowire private Platform platform;
    @Autowire private Logger logger;

    private @Value("logging.logEngineInfo") bool logEngineInfo;

    private bool _isTerminatable = false;

    public override @property bool isTerminatable() {
        return _isTerminatable;
    }

    public override @property long targetFrameTime() {
        return 10L;
    }

    public override @property long lagFrameLimit() {
        return 100L;
    }

    public override void startGame(const PlatformSettings platformSettings) {
        assert(this.game !is null, "No Game instance is assigned to this runtime.");

        if (logEngineInfo) {
            logger.infof("Retrograde Engine v%s.%s.%s%s", EngineVersionMajor,
                    EngineVersionMinor, EngineVersionPatch, EngineVersionDescriptor);
        }

        this.platform.initialize(platformSettings);
        this.game.initialize();
        loopWithFixedTimeStepVariableRenderRate();
        this.game.terminate();
        this.platform.terminate();
    }

    private void loopWithFixedTimeStepVariableRenderRate() {
        auto frameTimeStopWatch = new StopWatch();
        auto lagDuration = Duration.zero;
        frameTimeStopWatch.start();

        while (!this.isTerminatable) {
            const auto elapsedFrameTime = frameTimeStopWatch.peek();
            frameTimeStopWatch.reset();
            lagDuration += elapsedFrameTime;

            auto targetFrameTimeDuration = dur!"msecs"(this.targetFrameTime);
            auto lagCompensationFrames = 0L;
            while (lagDuration >= targetFrameTimeDuration) {
                lagCompensationFrames++;
                if (lagCompensationFrames > this.lagFrameLimit || this.isTerminatable) {
                    break;
                }

                this.platform.update();
                this.game.update();
                lagDuration -= targetFrameTimeDuration;
            }

            this.game.render(lagDuration / targetFrameTimeDuration);
        }
    }

    public override void terminate() {
        _isTerminatable = true;
    }
}

version (unittest) {
    class TestGame : Game {
        public bool isInitialized;
        public bool isUpdated;
        public bool isRendered;
        public bool isCleanedUp;

        @Autowire private EngineRuntime runtime;

        public override void initialize() {
            isInitialized = true;
        }

        public override void update() {
            isUpdated = true;
            runtime.terminate();
        }

        public override void render(double extraPolation) {
            isRendered = true;
        }

        public override void terminate() {
            isCleanedUp = true;
        }
    }

    @("StandardEngineRuntime lifecycle")
    unittest {
        import poodinis.valueinjector.properd;
        import properd;

        auto dependencies = new shared DependencyContainer();

        dependencies.registerProperdProperties(parseProperties(""));

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
