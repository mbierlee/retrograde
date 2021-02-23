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

module retrograde.core.game;

/**
 * Entry point for the actual game.
 */
interface Game
{
    /**
     * Called once upon initialization of the EngineRuntime.
     */
    void initialize();

    /**
     * The update loop for updating game logic.
     */
    void update();

    /**
     * The render loop for rendering.
     *
     * Params:
     *  extraPolation = Extrapolated amount of time between the previous and next update.
     *                  Is typically between 0 and 1.
     */
    void render(double extraPolation);

    /**
     * Typically called while the EngineRuntime is terminating.
     */
    void terminate();
}
