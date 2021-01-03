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

module retrograde.engine;

import retrograde.game;
import retrograde.application;
import retrograde.stringid;
import retrograde.messaging;

import std.datetime.stopwatch;
import std.stdio;
import std.string;

const uint VERSION_MAYOR = 0;
const uint VERSION_MINOR = 0;
const uint VERSION_REVISION = 0;

const uint COPYRIGHT_YEAR = 2017;

public string getEngineName() {
    return "Retrograde Engine";
}

public string getEngineVersionText() {
    return format("v%s.%s.%s", VERSION_MAYOR, VERSION_MINOR, VERSION_REVISION);
}

public string getEngineCopyrightText() {
    return format("Copyright Mike Bierlee %s", COPYRIGHT_YEAR);
}

private void logStartupInfo(Game game) {
    auto defaultContext = new RetrogradeDefaultApplicationContext();
    auto logger = defaultContext.logger();
    logger.infof("%s (%s)", game.name, game.copyright);
    logger.infof("%s %s (%s)", getEngineName(), getEngineVersionText(), getEngineCopyrightText());
}

public void loopWithFixedTimeStepVariableDrawRate(Game game) {
    auto frameTimeStopWatch = new StopWatch();
    auto lag = Duration.zero;
    frameTimeStopWatch.start();

    while (!game.terminatable) {

        auto elapsedFrameTime = frameTimeStopWatch.peek();
        frameTimeStopWatch.reset();
        lag += elapsedFrameTime;

        auto targetFrameTime = dur!"msecs"(game.targetFrameTime);
        auto lagCompensationFrames = 0L;
        while (lag >= targetFrameTime) {
            lagCompensationFrames++;
            if (lagCompensationFrames > game.lagFrameLimit || game.terminatable) {
                break;
            }

            game.update();
            lag -= targetFrameTime;
        }

        game.render(lag / targetFrameTime);
    }
}

public void start(Game game, void function(Game game) gameLoopFunction = &loopWithFixedTimeStepVariableDrawRate) {
    alias executeGameLoop = gameLoopFunction;

    logStartupInfo(game);
    game.initialize();
    executeGameLoop(game);
    game.cleanup();
}

enum EngineCommand : StringId {
    quit = sid("cmd_quit")
}

public void registerEngineDebugSids(SidMap sidMap) {
    sidMap.add("cmd_quit");
}

class CoreEngineCommandChannel : CommandChannel {}
