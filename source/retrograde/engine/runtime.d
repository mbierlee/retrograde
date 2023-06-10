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

version (WebAssembly) {
} else {
    import core.stdc.time : clock, CLOCKS_PER_SEC;

    void runLoop() {
        while (!terminateEngineLoop) {
            auto elapsedTimeMs = clock() / CLOCKS_PER_SEC * 1000;
            executeEngineLoopCycle(elapsedTimeMs);
        }
    }
}

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

        // These function pointers somehow end up on the heap, so we need to offset them.
        // and for some reason there's an extra one, no idea where it comes from!
        // Find a more reliable way to determine the true start of the free heap.
        auto res = initializeHeapMemory(
            initFunction.sizeof + updateFunction.sizeof + updateFunction.sizeof
        );

        if (res.isFailure) {
            import retrograde.std.stdio : writeErrLnStr;

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
        void main() {
            import retrograde.engine.runtime : initEngine, runLoop;

            setupHooks();
            initEngine();
            runLoop();
        }
    }
}
