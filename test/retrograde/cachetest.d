/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2018 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

import retrograde.cache;
import dunit;

import std.exception;

class CacheTest {
    mixin UnitTest;

    class TestThing {}

    @Test
    public void testGet() {
        auto cache = new Cache!(string, TestThing)();
        auto thing = new TestThing();

        cache.add("le thing", thing);
        auto cachedThing = cache.get("le thing").getOrElse({
            fail();
            return new TestThing();
        });

        assertSame(thing, cachedThing);
    }

    @Test
    public void testGetNotInCache() {
        auto cache = new Cache!(string, TestThing)();
        auto cachedThing = cache.get("lez materie");
        assertTrue(cachedThing.isEmpty);
    }

    @Test
    public void testGetOrAddNotInCache() {
        bool createdFromFetchFunction = false;

        auto cache = new Cache!(string, TestThing)();
        auto thing = cache.getOrAdd("le thing", {
            createdFromFetchFunction = true;
            return new TestThing();
        });

        assertTrue(createdFromFetchFunction);
        assertNotNull(thing);
    }

    @Test
    public void testGetOrAddReturnNull() {
        auto cache = new Cache!(string, TestThing)();
        assertThrown!Exception(cache.getOrAdd("de textuur", {
            return null;
        }));
    }

    @Test
    public void testGetOrAddFromCache() {
        auto cache = new Cache!(string, TestThing)();
        auto thingOne = cache.getOrAdd("la picuture", {
            return new TestThing();
        });

        auto thingTwo = cache.getOrAdd("la picuture", {
            return new TestThing();
        });

        assertSame(thingOne, thingTwo);
    }

    @Test
    public void testAdd() {
        auto cache = new Cache!(string, TestThing)();
        auto thing = new TestThing();

        cache.add("lez materie", thing);

        auto cachedThing = cache.getOrAdd("lez materie", {
            fail();
            return new TestThing();
        });

        assertSame(thing, cachedThing);
    }

        @Test
    public void testAddNull() {
        auto cache = new Cache!(string, TestThing)();
        assertThrown!Exception(cache.add("lu turture", null));
    }

    @Test
    public void testRemove() {
        auto cache = new Cache!(string, TestThing)();
        auto thing = new TestThing();

        cache.add("die farbepapieren", thing);
        cache.remove("die farbepapieren");

        auto cachedThing = cache.getOrAdd("die farbepapieren", {
            return new TestThing();
        });

        assertNotSame(thing, cachedThing);
    }

    @Test
    public void testRemoveNonexistingTexture() {
        auto cache = new Cache!(string, TestThing)();
        cache.remove("il textia");
    }

    @Test
    public void testHas() {
        auto cache = new Cache!(string, TestThing)();
        auto thing = new TestThing();
        cache.add("dun tubuiebu", thing);

        assertTrue(cache.has("dun tubuiebu"));
        assertFalse(cache.has("not a thing"));
    }

    @Test
    public void testClear() {
        auto cache = new Cache!(string, TestThing)();
        auto thing = new TestThing();
        cache.add("dun tubuiebu", thing);

        cache.clear();

        assertFalse(cache.has("dun tubuiebu"));
    }
}
