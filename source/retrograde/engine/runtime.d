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

module retrograde.engine.runtime;

/** 
 * An alias for a function that is called once when the engine is initialized.
 */
alias InitFunction = void function();

/** 
 * An alias for a function that is called once per engine loop cycle.
 */
alias UpdateFunction = void function();

/** 
 * An alias for a function that is called once per render cycle.
 */
alias RenderFunction = void function();

/** 
 * The function that is called once when the engine is initialized.
 * Should be set before calling initEngine.
 *
 * See_Also: DefaultEntryPoint
 */
InitFunction initFunction = null;

/** 
 * The function that is called once per engine loop cycle.
 * Should be set before calling initEngine.
 *
 * See_Also: DefaultEntryPoint
 */
UpdateFunction updateFunction = null;

/** 
 * The function that is called once per render cycle.
 * Should be set before calling initEngine.
 *
 * See_Also: DefaultEntryPoint
 */
RenderFunction renderFunction = null;

/** 
 * The target time in milliseconds for a single engine loop cycle.
 * The engine's update loop will try to run at this speed, but will not go faster than this.
 * The default value is 16.666666666666668 (1/60th of a second).
 */
double targetTickTimeMs = (1.0 / 60.0) * 1000;

/** 
 * The maximum number of ticks that can be lagged behind before the engine loop is terminated.
 * The default value is 100.
 */
long lagTickLimit = 100;

/** 
 * A flag that indicates whether the engine loop should be terminated.
 * This flag is set to true when the engine loop is terminated.
 */
bool terminateEngineLoop = false;

private double lastTimeMs = 0.0;
private double lagTimeMs = 0.0;

version (Native) {
    import retrograde.std.time : StopWatch;
    import retrograde.std.stdio : writeErrLn;

    /** 
     * Runs the engine loop until terminateEngineLoop is set to true.
     * This function is only available in the native build.
     */
    void runLoop() {
        StopWatch sw;
        auto res = sw.start();
        if (res.isFailure) {
            writeErrLn(res.errorMessage);
            return;
        }

        while (!terminateEngineLoop) {
            auto elapsedTimeMs = sw.peek();
            if (elapsedTimeMs < 0) {
                writeErrLn("Elapsed time is negative, this should not happen. Stopwatch is broken.");
                return;
            }

            executeEngineLoopCycle(elapsedTimeMs);
        }
    }
}

/** 
 * Executes a single cycle of the engine loop. 
 *
 * Params:
 *   elapsedTimeMs = The elapsed time in milliseconds since the start of running the engine loop / application.
 */
export extern (C) void executeEngineLoopCycle(double elapsedTimeMs) {
    assert(updateFunction != null, "updateFunction cannot be null. Set it before starting the engine loop.");
    assert(renderFunction != null, "renderFunction cannot be null. Set it before starting the engine loop.");

    double deltaTimeMs = elapsedTimeMs - lastTimeMs;
    if (deltaTimeMs < 0.0) {
        deltaTimeMs = 0.0;
    }

    lagTimeMs += deltaTimeMs;
    long lagCompensationTicks = 0;

    while (lagTimeMs >= targetTickTimeMs) {
        lagCompensationTicks++;
        if (lagCompensationTicks > lagTickLimit || terminateEngineLoop) {
            lagTimeMs = 0.0;
            break;
        }

        updateFunction();
        lagTimeMs -= targetTickTimeMs;
    }

    renderFunction();
    lastTimeMs = elapsedTimeMs;
}

/** 
 * Initializes the engine.
 * This function should be called before calling runLoop.
 * initFunction and updateFunction should be set before calling this function.
 */
export extern (C) void initEngine() {
    assert(initFunction != null, "initFunction cannot be null. Set it before engine initialization.");
    assert(updateFunction != null, "updateFunction cannot be null. Set it before engine initialization.");
    assert(renderFunction != null, "renderFunction cannot be null. Set it before engine initialization.");

    version (WebAssembly) {
        import retrograde.wasm.memory : initializeHeapMemory;
        import retrograde.std.stdio : writeErrLn;

        auto res = initializeHeapMemory();
        if (res.isFailure) {
            writeErrLn(res.errorMessage);
        }
    }

    initFunction();
}

/** 
 * A template for setting up the required hooks for the engine,
 * initializing the engine and running the engine loop.
 *
 * Make sure that a function name init and update are defined in the module
 * where this template is used.
 *
 * See_Also: InitFunction, UpdateFunction
 */
template DefaultEntryPoint() {
    void setupHooks() {
        mixin("
            import retrograde.engine.runtime : initFunction, updateFunction, renderFunction;
            initFunction = &init;
            updateFunction = &update;
            renderFunction = &render;
        ");
    }

    version (WebAssembly) {
        export extern (C) void _start() {
            setupHooks();

            // We do not run the internal engine loop in WebAssembly,
            // the browser is in charge of that.
            // Also, initEngine is called by the web runtime.
        }
    } else {
        extern (C) void main() {
            import retrograde.engine.runtime : initEngine, runLoop;

            setupHooks();
            initEngine();
            runLoop();
        }
    }
}
