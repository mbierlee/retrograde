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

module retrograde.graphics.twodee.sdl2.rendering;

version(Have_derelict_sdl2) {

import retrograde.entity;
import retrograde.graphics.core;
import retrograde.math;
import retrograde.file;
import retrograde.sdl2.window;
import retrograde.derelict;
import retrograde.messaging;
import retrograde.stringid;

import poodinis;

import std.string;
import std.range;
import std.math;
import std.algorithm.sorting;
import std.algorithm.iteration;

import derelict.sdl2.sdl;
import derelict.sdl2.image;

class Sdl2RenderSystemInitException : Exception {
    this(string reason) {
        super("Could not initialize SDL2 render system: " ~ reason);
    }
}

public class Sdl2RenderSystem : EntityProcessor {
    private SDL_Renderer* renderer;
    private SDL_Window* window;

    public ColorRgba clearColor = ColorRgba(0, 0, 0, 255);

    @Autowire
    @OptionalDependency
    private SubRenderer[] subRenderers;

    @Autowire
    private Sdl2WindowCreator windowCreator;

    public override void initialize() {
        if (!DerelictLibrary.loadedAndInitialized()) {
            throw new Sdl2RenderSystemInitException("SDL2 is not initialized. See retrograde.derelict module and load and initialize SDL2 before the renderer.");
        }

        window = windowCreator.createWindow();
        if (!window) {
            throw new Sdl2RenderSystemInitException("Could not create window");
        }

        renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
        if (!renderer) {
            throw new Sdl2RenderSystemInitException("Could not create renderer");
        }

        initializeSubRenderers();
    }

    public void initializeSubRenderers() {
        if (subRenderers.length == 0) {
            throw new Sdl2RenderSystemInitException("No SDL2 subrenderers are registered in the dependency container.");
        }

        foreach (subRenderer; subRenderers) {
            subRenderer.renderer = renderer;
        }
    }

    public override void cleanup() {
        SDL_DestroyWindow(window);
        SDL_DestroyRenderer(renderer);
    }

    public override bool acceptsEntity(Entity entity) {
        foreach(subRenderer ; subRenderers) {
            if (subRenderer.acceptsEntity(entity)) {
                return true;
            }
        }
        return false;
    }

    protected override void processAcceptedEntity(Entity entity) {
        foreach(subRenderer ; subRenderers) {
            if (subRenderer.acceptsEntity(entity)) {
                subRenderer.addEntity(entity);
            }
        }
    }

    protected override void processRemovedEntity(Entity entity) {
        foreach(subRenderer ; subRenderers) {
            if (subRenderer.hasEntity(entity)) {
                subRenderer.removeEntity(entity.id);
            }
        }
    }

    public override void update() {
        foreach(subRenderer ; subRenderers) {
            subRenderer.update();
        }
    }

    public override void draw() {
        if (renderer) {
            SDL_SetRenderDrawColor(renderer, clearColor.r, clearColor.g, clearColor.b, clearColor.a);
            SDL_RenderClear(renderer);
            foreach(subRenderer ; subRenderers) {
                subRenderer.draw();
            }
            SDL_RenderPresent(renderer);
        }
    }

    public SDL_Texture* createTextureFromSurface(SDL_Surface* surface) {
        return SDL_CreateTextureFromSurface(renderer, surface);
    }
}

public class SubRenderer : EntityProcessor {
    public SDL_Renderer* renderer;
}

public class SpriteSubRenderer : SubRenderer {
    private bool reorderEntities = false;
    private Entity[][int] orderedEntities;
    private SortedRange!(int[]) renderOrderKeys;

    public override bool acceptsEntity(Entity entity) {
        return (entity.hasComponent!RenderableSpriteComponent
            || entity.hasComponent!RenderableTextComponent)
            && entity.hasComponent!TextureComponent;
    }

    public override void update() {
        if (reorderEntities) {
            orderedEntities.destroy();
            _entities.getAll().each!(e => addToOrderedMap(e));
            createRenderOrderKeys();
            reorderEntities = false;
        }
    }

    private void createRenderOrderKeys() {
        renderOrderKeys = orderedEntities.keys.sort();
    }

    private void addToOrderedMap(Entity entity) {
        int renderOrder = getEntityDrawOrder(entity);
        orderedEntities[renderOrder] ~= entity;
    }

    private int getEntityDrawOrder(Entity entity) {
        return entity.getFromComponent!RenderOrderComponent(component => component.order, 0);
    }

    private void removeFromOrderedMap(uint entityId) {
        auto entity = _entities[entityId];
        auto renderOrder = getEntityDrawOrder(entity);
        orderedEntities[renderOrder] = orderedEntities[renderOrder].filter!(ent => ent.id != entityId)().array();
    }

    public override void addEntity(Entity entity) {
        if (acceptsEntity(entity)) {
            addToOrderedMap(entity);
            createRenderOrderKeys();
            super.addEntity(entity);
        }
    }

    public override void removeEntity(uint entityId) {
        removeFromOrderedMap(entityId);
        super.removeEntity(entityId);
    }

    public override void draw() {
        foreach(orderIndex; renderOrderKeys) {
            foreach(entity; orderedEntities[orderIndex]) {
                auto isHidden = entity.getFromComponent!HideableComponent(component => component.isHidden, false);
                if (isHidden) {
                    continue;
                }

                drawEntitySprite(entity);
            }
        }
    }

    private void drawEntitySprite(Entity entity) {
        auto texture = cast(Sdl2Texture) entity.getFromComponent!TextureComponent(c => c.texture);
        if (!texture) return;
        auto sdlTexture = texture.getSdlTexture();
        if (!sdlTexture) return;

        RectangleU currentSpriteSize = entity.getFromComponent!SpriteSheetComponent((component) {
            auto currentFrame = entity.getFromComponent!SpriteAnimationComponent(component => component.currentFrame, 1L);
            return cast(RectangleU) component.getNthSprite(currentFrame);
        }, texture.getTextureSize());

        Vector2D position = entity.getFromComponent!Position2DComponent(component => component.position, Vector2D(0));

        entity.maybeWithComponent!DrawingOffset2DComponent((component) {
            position = position + component.offset;
        });

        int renderFlip = SDL_FLIP_NONE;
        if (entity.hasComponent!VerticalSpriteFlipComponent) {
            renderFlip = renderFlip | SDL_FLIP_VERTICAL;
        }

        if (entity.hasComponent!HorizontalSpriteFlipComponent) {
            renderFlip = renderFlip | SDL_FLIP_HORIZONTAL;
        }

        double rotation = radiansToDegrees(entity.getFromComponent!OrientationR2Component(component => component.angle, 0));

        Vector2D offset = entity.getFromComponent!DrawingOffset2DComponent(component => component.offset, Vector2D(0)) * -1;
        SDL_Point center = SDL_Point(cast(int) offset.x, cast(int) offset.y);

        auto textureColor = entity.getFromComponent!TextureColorComponent(c => c.color, ColorRgb(255, 255, 255));
        SDL_SetTextureColorMod(sdlTexture, textureColor.r, textureColor.g, textureColor.b);

        SDL_Rect source;
        source.x = currentSpriteSize.x;
        source.y = currentSpriteSize.y;
        source.w = currentSpriteSize.width;
        source.h = currentSpriteSize.height;
        SDL_Rect destination;
        destination.x = cast(int) round(position.x);
        destination.y = cast(int) round(position.y);
        destination.w = currentSpriteSize.width;
        destination.h = currentSpriteSize.height;

        SDL_RenderCopyEx(renderer, sdlTexture, &source, &destination, rotation, &center, renderFlip);
    }
}

class Sdl2Texture : Texture {
    private SDL_Texture* texture;
    private SDL_Rect textureSize;
    private string name;

    public this() {}

    public this(SDL_Texture* texture, string name) {
        this.texture = texture;
        this.name = name;
        setTextureSize(texture);
    }

    public override RectangleU getTextureSize() {
        return RectangleU(textureSize.x, textureSize.y, textureSize.w, textureSize.h);
    }

    public override string getName() {
        return name;
    }

    public SDL_Rect getSdlTextureSize() {
        return textureSize;
    }

    public SDL_Texture* getSdlTexture() {
        return texture;
    }

    public void setSdlTexture(SDL_Texture* texture) {
        this.texture = texture;
        setTextureSize(texture);
    }

    private void setTextureSize(SDL_Texture* texture) {
        textureSize.x = 0;
        textureSize.y = 0;
        SDL_QueryTexture(texture, null, null, &textureSize.w, &textureSize.h);
    }
}

class Sdl2TextureComponentFactory : TextureComponentFactory {

    @Autowire
    private Sdl2RenderSystem renderer;

    private TextureCache textures = new TextureCache();

    public TextureComponent loadTexture(File textureFile) {
        auto texture = textures.getOrAdd(textureFile.fileName, {
            SDL_Surface* textureSurface = IMG_Load(textureFile.fileName.toStringz());
            SDL_Texture* texture = renderer.createTextureFromSurface(textureSurface);
            SDL_FreeSurface(textureSurface);
            return new Sdl2Texture(texture, textureFile.fileName);
        });

        return new TextureComponent(texture);
    }

    public TextureComponent createNullComponent() {
        return new TextureComponent(null);
    }
}

}
