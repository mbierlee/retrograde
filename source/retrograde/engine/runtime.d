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

uint targetTickTimeMs = cast(uint)((1.0 / 60.0) * 1000);
long lagTickLimit = 100;
bool terminateEngineLoop = false;

private double lastTimeMs = 0.0;
private double lagTimeMs = 0.0;

export extern (C) void executeEngineLoopCycle(double elapsedTimeMs) {
    assert(updateFunction != null, "updateFunction cannot be null. Set it before starting the engine loop.");

    double deltaTimeMs = elapsedTimeMs - lastTimeMs;
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
    initFunction();
}

template DefaultEntryPoint() {
    version (WebAssembly) {
        export extern (C) void _start() {
            mixin("
                import retrograde.engine.runtime : initFunction, updateFunction;
                initFunction = &init;
                updateFunction = &update;
            ");

            // We do not run the internal engine loop in WebAssembly,
            // the browser is in charge of that.
        }
    } else {
        void main() {
            //TODO: initialize game
            //TODO: run game loop
            assert(false, "Native update loop not yet implemented");
        }
    }
}
