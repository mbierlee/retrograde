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

import retrograde.option;
import dunit;

import std.exception;

class OptionTest {
    mixin UnitTest;

    class SandraBullock {}

    struct GeorgeClooney {}

    @Test
    public void testSome() {
        auto bullock = new SandraBullock();
        auto option = Some!SandraBullock(bullock);

        assertFalse(option.isEmpty());
        assertEquals(bullock, option.get());
    }

    @Test
    public void testSomeWithNull() {
        assertThrown!Exception(Some!SandraBullock(null));
    }

    @Test
    public void testNone() {
        auto option = None!SandraBullock();

        assertTrue(option.isEmpty());
        assertThrown!Exception(option.get());
    }

    @Test
    public void testGetOrElseWithSome() {
        bool triggeredDelegate = false;
        auto expectedBullock = new SandraBullock();
        auto option = Some!SandraBullock(expectedBullock);

        auto actualBullock = option.getOrElse({
            triggeredDelegate = true;
            return new SandraBullock();
        });

        assertFalse(triggeredDelegate);
        assertEquals(expectedBullock, actualBullock);
    }

    @Test
    public void testGetOrElseWithNone() {
        bool triggeredDelegate = false;
        auto option = None!SandraBullock();

        auto actualBullock = option.getOrElse({
            triggeredDelegate = true;
            return new SandraBullock();
        });

        assertTrue(triggeredDelegate);
    }

    @Test
    public void testForEachWithSome() {
        bool triggeredDelegate = false;
        auto expectedBullock = new SandraBullock();
        auto option = Some!SandraBullock(expectedBullock);

        option.ifNotEmpty((sandra) {
            triggeredDelegate = true;
        });

        assertTrue(triggeredDelegate);
    }

    @Test
    public void testForEachWithNone() {
        bool triggeredDelegate = false;
        auto option = None!SandraBullock();

        option.ifNotEmpty((sandra) {
            triggeredDelegate = true;
        });

        assertFalse(triggeredDelegate);
    }

    @Test
    public void testOptionWithStruct() {
        auto some = Some!GeorgeClooney(GeorgeClooney());
        auto none = None!GeorgeClooney();
    }

    @Test
    public void testSomeWithNumbers() {
        auto someOne = Some!int(5);
        auto someTwo = Some!int(0);
        auto someThree = Some!double(5.8);
        auto someFour = Some!double(0.0);
    }
}
