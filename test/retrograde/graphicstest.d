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

import retrograde.graphics;
import retrograde.math;
import retrograde.entity;
import retrograde.file;
import retrograde.game;

import dunit;

import poodinis;

import std.exception;

class TestGame : BaseGame {
    this() {
        super("Graphics Test Game", "No copyright");
    }

    override @property long targetFrameTime() {
        return 1L;
    }

    public void initialize() {};
    public void update() {};
    public void render(double extraPolation) {};
    public void cleanup() {};

}

class SpriteSheetComponentTest {
    mixin UnitTest;

    @Test
    public void testCreateComponent() {
        auto spritesheet = new Spritesheet(10, 5);
        auto component = new SpriteSheetComponent(spritesheet, RectangleUL(0, 0, 20, 20));

        assertEquals(RectangleUL(0, 0, 20, 20), component.size);
        assertEquals(spritesheet.rows, component.spritesheet.rows);
        assertEquals(spritesheet.columns, component.spritesheet.columns);
        assertEquals(spritesheet.spriteCount, component.spritesheet.spriteCount);
    }

    @Test
    public void testGetSprite() {
        auto spritesheet = new Spritesheet(4, 5);
        auto component = new SpriteSheetComponent(spritesheet, RectangleUL(0, 0, 25, 20));

        auto actualSpriteSize = component.getSprite(3, 5);
        auto expectedSpriteSize = RectangleUL(20, 10, 5, 5);

        assertEquals(expectedSpriteSize, actualSpriteSize);
    }

    @Test
    public void testGetNthSprite() {
        auto spritesheet = new Spritesheet(3, 3);
        auto component = new SpriteSheetComponent(spritesheet, RectangleUL(0, 0, 30, 30));

        auto actualSpriteSize = component.getNthSprite(6);
        auto expectedSpriteSize = RectangleUL(20, 10, 10, 10);

        assertEquals(expectedSpriteSize, actualSpriteSize);
    }

}

class SpriteAnimationComponentTest {
    mixin UnitTest;

    @Test
    public void testGetAndSetCurrentFrameNumber() {
        auto spritesheetAnimation = new SpritesheetAnimation();
        auto animation = new Animation(1, 5);
        spritesheetAnimation.animations[animation.name] = animation;
        spritesheetAnimation.initialAnimation = animation;
        auto component = new SpriteAnimationComponent(spritesheetAnimation);
        assertEquals(1, component.currentFrame);
        component.currentFrame = 5;
        assertEquals(5, component.currentFrame);
    }

    @Test
    public void testInitialFrameIsSetToBeginFrame() {
        auto spritesheetAnimation = new SpritesheetAnimation();
        auto animation = new Animation(5, 15);
        spritesheetAnimation.animations[animation.name] = animation;
        spritesheetAnimation.initialAnimation = animation;
        auto component = new SpriteAnimationComponent(spritesheetAnimation);
        assertEquals(5, component.currentFrame);
    }

    @Test
    public void testCurrentFrameIsInitial() {
        auto spritesheetAnimation = new SpritesheetAnimation();
        auto animation1 = new Animation(5, 15);
        auto animation2 = new Animation(1, 4);
        spritesheetAnimation.initialAnimation = animation2;
        spritesheetAnimation.animations["a"] = animation1;
        spritesheetAnimation.animations["b"] = animation2;
        auto component = new SpriteAnimationComponent(spritesheetAnimation);
        assertSame(animation2, component.currentAnimation);
    }

    @Test
    public void testResetMsecsInProgress() {
        auto spritesheetAnimation = new SpritesheetAnimation();
        auto animation = new Animation(5, 15);
        spritesheetAnimation.animations[animation.name] = animation;
        spritesheetAnimation.initialAnimation = animation;

        auto component = new SpriteAnimationComponent(spritesheetAnimation);
        component.msecsInProgress = 100;
        component.currentAnimation = animation;
        assertEquals(0, component.msecsInProgress);
    }

    @Test
    public void testSetAnimation() {
        auto spritesheetAnimation = new SpritesheetAnimation();
        auto animation1 = new Animation(5, 15);
        auto animation2 = new Animation(1, 5);
        spritesheetAnimation.animations["donkey"] = animation1;
        spritesheetAnimation.animations["kong"] = animation2;
        spritesheetAnimation.initialAnimation = animation1;
        auto component = new SpriteAnimationComponent(spritesheetAnimation);

        component.setAnimation("kong");

        assertSame(animation2, component.currentAnimation);
    }

}

class SpriteAnimationProcessorTest {
    mixin UnitTest;

    private SpritesheetAnimation spritesheetAnimation;

    private shared(DependencyContainer) container;

    @BeforeEach
    public void setup() {
        spritesheetAnimation = new SpritesheetAnimation();
        spritesheetAnimation.framesPerSecond = 1000;
        auto animation = new Animation(1, 2, "durp");
        spritesheetAnimation.animations[animation.name] = animation;
        spritesheetAnimation.initialAnimation = animation;

        container = new DependencyContainer();
        container.register!(Game, TestGame);
        container.register!SpriteAnimationProcessor;
    }

    @Test
    public void testAnimateSpriteComponent() {
        auto processor = container.resolve!SpriteAnimationProcessor;
        auto entity = new Entity();
        entity.id = 1;
        auto component = new SpriteAnimationComponent(spritesheetAnimation);
        entity.addComponent(component);
        entity.finalize();
        processor.addEntity(entity);

        assertEquals(1, component.currentFrame);

        processor.update();

        assertEquals(2, component.currentFrame);
    }

    @Test
    public void testAnimateSpriteComponentWithZeroFrameRateDoesNotIncrement() {
        spritesheetAnimation.framesPerSecond = 0;
        auto processor = container.resolve!SpriteAnimationProcessor;
        auto entity = new Entity();
        entity.id = 1;
        auto component = new SpriteAnimationComponent(spritesheetAnimation);
        entity.addComponent(component);
        entity.finalize();
        processor.addEntity(entity);

        assertEquals(1, component.currentFrame);

        processor.update();

        assertEquals(1, component.currentFrame);
    }

    @Test
    public void testAnimateSpriteComponentClampsFrame() {
        auto processor = container.resolve!SpriteAnimationProcessor;
        auto entity = new Entity();
        entity.id = 1;
        auto component = new SpriteAnimationComponent(spritesheetAnimation);
        component.currentFrame = 2;
        entity.addComponent(component);
        entity.finalize();
        processor.addEntity(entity);

        assertEquals(2, component.currentFrame);

        processor.update();

        assertEquals(1, component.currentFrame);
    }
}

class TextureCacheTest {
    mixin UnitTest;

    class TestTexture : Texture {
        public override RectangleU getTextureSize() {
            return RectangleU();
        }

        public override string getName() {
            return "testu.png";
        }
    }

    @Test
    public void testGet() {
        auto cache = new TextureCache();
        auto texture = new TestTexture();

        cache.add("lez materie", texture);
        auto cachedTexure = cache.get("lez materie").getOrElse({
            fail();
            return new TestTexture();
        });

        assertSame(texture, cachedTexure);
    }

    @Test
    public void testGetNotInCache() {
        auto cache = new TextureCache();
        auto cachedTexure = cache.get("lez materie");
        assertTrue(cachedTexure.isEmpty);
    }

    @Test
    public void testGetOrAddNotInCache() {
        bool createdFromFetchFunction = false;

        auto cache = new TextureCache();
        auto texture = cache.getOrAdd("le texture", {
            createdFromFetchFunction = true;
            return new TestTexture();
        });

        assertTrue(createdFromFetchFunction);
        assertNotNull(texture);
    }

    @Test
    public void testGetOrAddReturnNull() {
        auto cache = new TextureCache();
        assertThrown!Exception(cache.getOrAdd("de textuur", {
            return null;
        }));
    }

    @Test
    public void testGetOrAddFromCache() {
        auto cache = new TextureCache();
        auto textureOne = cache.getOrAdd("la picuture", {
            return new TestTexture();
        });

        auto textureTwo = cache.getOrAdd("la picuture", {
            return new TestTexture();
        });

        assertSame(textureOne, textureTwo);
    }

    @Test
    public void testAdd() {
        auto cache = new TextureCache();
        auto texture = new TestTexture();

        cache.add("lez materie", texture);

        auto cachedTexure = cache.getOrAdd("lez materie", {
            fail();
            return new TestTexture();
        });

        assertSame(texture, cachedTexure);
    }

        @Test
    public void testAddNull() {
        auto cache = new TextureCache();
        assertThrown!Exception(cache.add("lu turture", null));
    }

    @Test
    public void testRemove() {
        auto cache = new TextureCache();
        auto texture = new TestTexture();

        cache.add("die farbepapieren", texture);
        cache.remove("die farbepapieren");

        auto cachedTexure = cache.getOrAdd("die farbepapieren", {
            return new TestTexture();
        });

        assertNotSame(texture, cachedTexure);
    }

    @Test
    public void testRemoveNonexistingTexture() {
        auto cache = new TextureCache();
        cache.remove("il textia");
    }

    @Test
    public void testHas() {
        auto cache = new TextureCache();
        auto texture = new TestTexture();
        cache.add("dun tubuiebu", texture);

        assertTrue(cache.has("dun tubuiebu"));
        assertFalse(cache.has("not a texture"));
    }

    @Test
    public void testClear() {
        auto cache = new TextureCache();
        auto texture = new TestTexture();
        cache.add("dun tubuiebu", texture);

        cache.clear();

        assertFalse(cache.has("dun tubuiebu"));
    }
}

class TextureCenteredDrawingOffsetProcessorTest {
    mixin UnitTest;

    class TestTexture : Texture {
        public override RectangleU getTextureSize() {
            return RectangleU(0, 0, 30, 30);
        }

        public override string getName() {
            return "pantsu.png";
        }
    }

    @Test
    public void testSetDrawingOffsetBasedOnTexture() {
        auto entity = new Entity();
        entity.id = 1;
        entity.addComponent(new TextureComponent(new TestTexture()));
        entity.addComponent!DrawingOffset2DComponent;
        entity.addComponent!TextureCenteredDrawingOffset2DComponent;
        entity.finalize();

        auto processor = new TextureCenteredDrawingOffsetProcessor();
        processor.addEntity(entity);

        processor.update();

        assertEquals(Vector2D(-15, -15), entity.getFromComponent!DrawingOffset2DComponent(c => c.offset));
    }
}
