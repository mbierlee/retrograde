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

import retrograde.pipeline.rsa;

import dunit;

import retrograde.graphics;
import retrograde.file;

class TiledTilemapReaderTest {
    mixin UnitTest;

    private const string TEST_RSA = `
        {
            "framesPerSecond": 1,
            "spritesheets": [
                {
                    "id": 1,
                    "fileName": "littledude.png",
                    "columns": 4,
                    "rows": 4
                }
            ],
            "initialAnimation" : "walkDown",
            "animations": [
                {
                    "name": "idleDown",
                    "spritesheet": 1,
                    "begin": 1,
                    "end": 1
                },
                {
                    "name": "walkDown",
                    "spritesheet": 1,
                    "begin": 1,
                    "end": 4
                }
            ]
        }
    `;

    private SpritesheetAnimation spritesheetAnimation;

    @BeforeEach
    private void createTestSpritesheetAnimation() {
        auto file = new VirtualTextFile("jhonny.json", TEST_RSA);
        auto reader = new RetrogradeSpritesheetAnimationReader();
        spritesheetAnimation = reader.readSpritesheetAnimation(file);
    }

    @Test
    private void testReadSpritesheetAnimation() {
        assertNotNull(spritesheetAnimation);
    }

    @Test
    private void testReadSpritesheetAnimationMetadata() {
        assertEquals(1, spritesheetAnimation.framesPerSecond);
    }

    @Test
    private void testReadSpritesheetAnimationSpritesheets() {
        auto spritesheet = spritesheetAnimation.spritesheets[1];
        assertEquals(1, spritesheet.id);
        assertEquals(4, spritesheet.rows);
        assertEquals(4, spritesheet.columns);
        assertEquals("littledude.png", spritesheet.fileName);
    }

    @Test
    private void testReadSpritesheetAnimationAnimations() {
        auto firstAnimation = spritesheetAnimation.animations["idleDown"];
        assertEquals("idleDown", firstAnimation.name);
        assertEquals(1, firstAnimation.beginFrame);
        assertEquals(1, firstAnimation.endFrame);
        assertSame(spritesheetAnimation.spritesheets[1], firstAnimation.spritesheet);

        auto secondAnimation = spritesheetAnimation.animations["walkDown"];
        assertEquals("walkDown", secondAnimation.name);
        assertEquals(1, secondAnimation.beginFrame);
        assertEquals(4, secondAnimation.endFrame);
        assertSame(spritesheetAnimation.spritesheets[1], secondAnimation.spritesheet);
    }

    @Test
    private void testReadSpritesheetAnimationInitialAnimation() {
        assertEquals("walkDown", spritesheetAnimation.initialAnimation.name);
    }
}
