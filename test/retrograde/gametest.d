/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2020 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

import retrograde.game;
import dunit;

class TestGame : BaseGame {
    this(string copyright = "") {
        super("Test Game", copyright);
    }

    void initialize() {}
    void update() {}
    void render(double extraPolation) {}
    void cleanup() {}
}


class GameTest {
    mixin UnitTest;

    @Test
    public void testGameName() {
        auto testGame = new TestGame();
        assertEquals("Test Game", testGame.name);
    }

    @Test
    public void testGameCopyright() {
        const string copyrightText = "Copyright 2045 Test Corp";
        auto testGame = new TestGame(copyrightText);
        assertEquals("Copyright 2045 Test Corp", testGame.copyright);
    }

    @Test
    public void testRequestTermination() {
        auto testGame = new TestGame();
        testGame.requestTermination();
        assertTrue(testGame.terminatable);
    }
}
