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

alias UpdateFunction = void function();

uint targetTickTimeMs = cast(uint)((1.0 / 60.0) * 1000);
long lagTickLimit = 100;
UpdateFunction updateFunction = null;
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
