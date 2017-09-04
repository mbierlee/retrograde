/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2017 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

import retrograde.stringid;
import dunit;

import std.string;
import std.stdio;

class StringIdTest {
	mixin UnitTest;

	@Test
	public void testCreateStringId() {
		auto stringId = sid("Jamaica");
		assertEquals(3446218645, stringId);
	}

	@Test
	public void testCreateStringIdCaseSensitive() {
		auto stringId1 = sid("camelSuitcases");
		auto stringId2 = sid("CamelSuitcases");
		assertTrue(stringId1 != stringId2);
	}

	@Test
	public void testCreateStringIdViaCtfe() {
		enum stringId = sid("bla?");
		assertEquals(9491023, stringId);
	}

	@Test
	public void testAnagramCollisionDoesNotOccur() {
		auto stringId1 = sid("ABBA");
		auto stringId2 = sid("BAAB");
		assertTrue(stringId1 != stringId2);
	}

	@Test
	public void testIdCollisionRate() {
		enum printDebugInfo = false;
		enum acceptableCollisionRate = 0.26; // Percent

		auto words = splitLines(import("words.txt"));
		string[][StringId] stringIdMap;

		foreach(word; words) {
			auto stringId = sid(word);
			stringIdMap[stringId] ~= word;
		}

		auto collidedWords = 0;
		foreach(stringIdOccurences; stringIdMap.byKeyValue()) {
			auto collisionsForStringId = stringIdOccurences.value.length;
			if (collisionsForStringId > 1) {
				static if (printDebugInfo) {
					writeln(format("SID: %s - Collisions: %s",stringIdOccurences.key, stringIdOccurences.value));
				}

				collidedWords += collisionsForStringId;
			}
		}

		auto collisionRate = (cast(double)collidedWords / words.length) * 100;
		static if (printDebugInfo) {
			writeln(format("Collision rate: %s%% (%s out of %s words)", collisionRate, collidedWords, words.length));
		}

		assertTrue(collisionRate <= acceptableCollisionRate);
	}
}

class SidMapTest {
	mixin UnitTest;

	@Test
	public void testAddingSids() {
		auto map = new SidMap();
		map.add("test_sid_string");
		assertTrue(map.contains(sid("test_sid_string")));
		assertEquals("test_sid_string", map.get(sid("test_sid_string")));
		assertEquals("test_sid_string", map[sid("test_sid_string")]);
	}
}