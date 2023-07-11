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

alias InitFunction = void function();
alias UpdateFunction = void function();

InitFunction initFunction = null;
UpdateFunction updateFunction = null;

double targetTickTimeMs = (1.0 / 60.0) * 1000;
long lagTickLimit = 100;
bool terminateEngineLoop = false;

private double lastTimeMs = 0.0;
private double lagTimeMs = 0.0;

version (Native) {
    import retrograde.std.time : StopWatch;

    void runLoop() {
        StopWatch sw;
        sw.start();
        while (!terminateEngineLoop) {
            auto elapsedTimeMs = sw.peek();
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

    // TODO: Call render function.
    lastTimeMs = elapsedTimeMs;
}

export extern (C) void initEngine() {
    assert(initFunction != null, "initFunction cannot be null. Set it before engine initialization.");
    assert(updateFunction != null, "updateFunction cannot be null. Set it before engine initialization.");

    version (WebAssembly) {
        import retrograde.wasm.memory : initializeHeapMemory;
        import retrograde.std.stdio : writeErrLnStr;

        auto res = initializeHeapMemory();
        if (res.isFailure) {
            writeErrLnStr(res.errorMessage);
        }
    }

    initFunction();
}

template DefaultEntryPoint() {
    void setupHooks() {
        mixin("
            import retrograde.engine.runtime : initFunction, updateFunction;
            initFunction = &init;
            updateFunction = &update;
        ");
    }

    version (WebAssembly) {
        export extern (C) void _start() {
            setupHooks();

            // We do not run the internal engine loop in WebAssembly,
            // the browser is in charge of that.
            // Also initEngine is called by the web runtime.
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
