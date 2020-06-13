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

module retrograde.graphics.core;

import retrograde.entity;
import retrograde.math;
import retrograde.file;
import retrograde.game;
import retrograde.stringid;
import retrograde.cache;

import poodinis;

import std.string;
import std.math;
import std.exception;
import std.conv;

enum TextureFilterMode {
    nearestNeighbor,
    linear,
    trilinear
}

abstract class Texture {
    public abstract RectangleU getTextureSize();
    public abstract string getName();
}

class TextureComponent : EntityComponent, Snapshotable {
    mixin EntityComponentIdentity!"TextureComponent";

    public Texture texture;

    this(Texture texture) {
        this.texture = texture;
    }

    public string[string] getSnapshotData() {
        auto textureName = texture !is null ? texture.getName : "";
        return ["textureName": textureName];
    }
}

class RenderableSpriteComponent : EntityComponent {
    mixin EntityComponentIdentity!"RenderableSpriteComponent";
}

class RenderableTextComponent : EntityComponent {
    mixin EntityComponentIdentity!"RenderableTextComponent";
}

class HideableComponent : EntityComponent, Snapshotable {
    mixin EntityComponentIdentity!"HideableComponent";

    public bool isHidden;

    this() {
        this(false);
    }

    this(bool isHidden) {
        this.isHidden = isHidden;
    }

    public string[string] getSnapshotData() {
        return ["isHidden": isHidden ? "true": "false"];
    }
}

class SpriteAnimationComponent : EntityComponent, Snapshotable {
    mixin EntityComponentIdentity!"SpriteAnimationComponent";

    public long msecsInProgress;

    private ulong _currentFrame;
    private ulong _msecsPerFrame;
    private SpritesheetAnimation _spritesheetAnimation;
    private Animation _currentAnimation;

    public @property SpritesheetAnimation spritesheetAnimation() {
        return _spritesheetAnimation;
    }

    public @property Animation currentAnimation() {
        return _currentAnimation;
    }

    public @property void currentAnimation(Animation animation) {
        _currentAnimation = animation;
        currentFrame = animation.beginFrame;
        msecsInProgress = 0;
    }

    public @property long msecsPerFrame() {
        return this._msecsPerFrame;
    }

    public @property void currentFrame(ulong currentFrame) {
        enforce(currentFrame >= _currentAnimation.beginFrame && currentFrame <= _currentAnimation.endFrame,
                format("Set frame is not within the range of the start and end frame. Frame: %s, Start: %s, End: %s",
                    currentFrame, _currentAnimation.beginFrame, _currentAnimation.endFrame));
        this._currentFrame = currentFrame;
    }

    public @property ulong currentFrame() {
        return this._currentFrame;
    }

    private long getMsecsPerFrame(ulong framesPerSecond) {
        return framesPerSecond == 0 ? 0 : cast(long) round(1000 / framesPerSecond);
    }

    public this(SpritesheetAnimation spritesheetAnimation) {
        _spritesheetAnimation = spritesheetAnimation;
        currentAnimation = spritesheetAnimation.initialAnimation;
        _msecsPerFrame = getMsecsPerFrame(spritesheetAnimation.framesPerSecond);
    }

    public void setAnimation(string animationName) {
        currentAnimation = _spritesheetAnimation.animations[animationName];
    }

    public string[string] getSnapshotData() {
        return [
            "currentFrame": to!string(_currentFrame),
            "msecsInProgress": to!string(msecsInProgress),
            "msecsPerFrame": to!string(_msecsPerFrame),
            "currentAnimation": to!string(_currentAnimation.name)
        ];
    }
}

class SpriteSheetComponent : EntityComponent, Snapshotable {
    mixin EntityComponentIdentity!"SpriteSheetComponent";

    public RectangleUL size;
    public Spritesheet spritesheet;

    public this(Spritesheet spritesheet, RectangleUL size) {
        this.size = size;
        this.spritesheet = spritesheet;
    }

    public RectangleUL getSprite(ulong row, ulong column) {
        enforce(row <= spritesheet.rows,
                format("Row %s illegal, sprite has %s rows", row, spritesheet.rows));
        enforce(column <= spritesheet.columns,
                format("Column %s illegal, sprite has %s columns", column, spritesheet.columns));
        enforce(row != 0, "Invalid row number 0, rows are 1-indexed");
        enforce(column != 0, "Invalid column number 0, columns are 1-indexed");

        auto spriteWidth = size.width / spritesheet.columns;
        auto spriteHeight = size.height / spritesheet.rows;
        auto spriteX = spriteWidth * (column - 1);
        auto spriteY = spriteHeight * (row - 1);

        return RectangleUL(spriteX, spriteY, spriteWidth, spriteHeight);
    }

    public RectangleUL getNthSprite(ulong n) {
        enforce(n <= spritesheet.spriteCount,
                format("Sprite number %s invalid, the spritesheet only has %s sprites",
                    n, spritesheet.spriteCount));
        enforce(n != 0, "Invalid sprite number 0, sprite count is 1-indexed");

        ulong row = cast(uint) ceil(cast(double) n / spritesheet.columns);
        ulong column = n - ((row - 1) * spritesheet.columns);

        return getSprite(row, column);
    }

    public string[string] getSnapshotData() {
        return ["filename": spritesheet.fileName];
    }
}

interface TextureComponentFactory {
    TextureComponent loadTexture(File textureFile);
    TextureComponent createNullComponent();
}

class RenderableSpriteEntityCreationParameters : CreationParameters {
    public File textureFile;
    public Vector2D position;
    public scalar orientation;

    this(File textureFile, Vector2D position = Vector2D(0), scalar orientation = 0) {
        this.textureFile = textureFile;
        this.position = position;
        this.orientation = orientation;
    }
}

class RenderableSpriteEntityFactory : EntityFactory {
    @Autowire private TextureComponentFactory textureComponentFactory;

    this() {
        super("ent_sprite");
    }

    public override Entity createEntity(CreationParameters parameters) {
        auto textureCreationParameters = cast(RenderableSpriteEntityCreationParameters) parameters;
        auto entity = createBlankEntity();

        auto textureComponent = textureComponentFactory.loadTexture(
                textureCreationParameters.textureFile);
        entity.addComponent(textureComponent);
        entity.addComponent(new Position2DComponent(textureCreationParameters.position));
        entity.addComponent(new OrientationR2Component(textureCreationParameters.orientation));
        entity.addComponent!RenderableSpriteComponent;

        return entity;
    }

    public Entity createEntity(File textureFile, Vector2D position = Vector2D(0),
            scalar orientation = 0) {
        auto parameters = new RenderableSpriteEntityCreationParameters(textureFile,
                position, orientation);
        return createEntity(parameters);
    }
}

alias TextureCache = Cache!(string, Texture);

class SpriteAnimationProcessor : EntityProcessor {

    @Autowire private Game game;

    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!SpriteAnimationComponent;
    }

    public override void update() {
        foreach (entity; entities) {
            animateEntitySprite(entity);
        }
    }

    private void animateEntitySprite(Entity entity) {
        enforce(game.targetFrameTime > 0, "SpriteAnimationProcessor cannot operate with a framerate of 0. Remove the SpriteAnimationComponent from the entity or specify a non-zero framerate in your game.");

        entity.withComponent!SpriteAnimationComponent((c) {
            if (c.msecsPerFrame == 0) {
                return;
            }

            c.msecsInProgress += game.targetFrameTime;
            if (c.msecsInProgress >= c.msecsPerFrame) {
                auto frames = floor(cast(double) c.msecsInProgress / c.msecsPerFrame);
                c.msecsInProgress %= c.msecsPerFrame;

                while (frames--) {
                    if (c.currentFrame == c.currentAnimation.endFrame) {
                        c.currentFrame = c.currentAnimation.beginFrame;
                    } else {
                        c.currentFrame = c.currentFrame + 1;
                    }
                }
            }
        });
    }

    public override void draw() {
    }
}

class HorizontalSpriteFlipComponent : EntityComponent {
    mixin EntityComponentIdentity!"HorizontalSpriteFlipComponent";
}

class VerticalSpriteFlipComponent : EntityComponent {
    mixin EntityComponentIdentity!"VerticalSpriteFlipComponent";
}

class SpritesheetAnimation {
    public ulong framesPerSecond;
    public Animation initialAnimation;
    public Spritesheet[ulong] spritesheets;
    public Animation[string] animations;
}

class Spritesheet {
    public ulong id;
    public ulong columns;
    public ulong rows;
    public string fileName;

    this(ulong rows = 1, ulong columns = 1, string fileName = "", ulong id = 0) {
        this.rows = rows;
        this.columns = columns;
        this.fileName = fileName;
        this.id = id;
    }

    public @property ulong spriteCount() {
        return columns * rows;
    }
}

class Animation {
    public string name;
    public ulong beginFrame;
    public ulong endFrame;
    public Spritesheet spritesheet;

    this(ulong beginFrame = 1, ulong endFrame = 1, string name = "", Spritesheet spritesheet = null) {
        this.beginFrame = beginFrame;
        this.endFrame = endFrame;
        this.name = name;
        this.spritesheet = spritesheet;
    }
}

class RenderOrderComponent : EntityComponent, Snapshotable {
    mixin EntityComponentIdentity!"RenderOrderComponent";

    private int _order;

    public @property int order() {
        return _order;
    }

    this(int order = 0) {
        this._order = order;
    }

    public string[string] getSnapshotData() {
        return ["order": to!string(_order)];
    }
}

class DrawingOffset2DComponent : EntityComponent, Snapshotable {
    mixin EntityComponentIdentity!"DrawingOffset2DComponent";

    public Vector2D offset;

    this() {
        this(0, 0);
    }

    this(double x, double y) {
        offset = Vector2D(x, y);
    }

    this(Vector2D offset) {
        this.offset = offset;
    }

    public string[string] getSnapshotData() {
        return ["offset": to!string(offset)];
    }
}

class TextureCenteredDrawingOffset2DComponent : EntityComponent {
    mixin EntityComponentIdentity!"TextureCenteredDrawingOffset2DComponent";
}

class TextureCenteredDrawingOffsetProcessor : EntityProcessor {
    public override bool acceptsEntity(Entity entity) {
        return entity.hasComponent!DrawingOffset2DComponent
            && entity.hasComponent!TextureCenteredDrawingOffset2DComponent
            && entity.hasComponent!TextureComponent;
    }

    public override void update() {
        foreach (entity; entities) {
            auto textureSize = entity.getFromComponent!TextureComponent(
                    c => c.texture.getTextureSize());
            double xOffset = (cast(double) textureSize.width / 2) * -1;
            double yOffset = (cast(double) textureSize.height / 2) * -1;
            entity.withComponent!DrawingOffset2DComponent((c) {
                c.offset = Vector2D(xOffset, yOffset);
            });
        }
    }
}

class Shader {
    private File _shaderFile;
    private ShaderType _type;

    public @property File shaderFile() {
        return _shaderFile;
    }

    public @property ShaderType type() {
        return _type;
    }

    this(File shaderFile, ShaderType type) {
        this._shaderFile = shaderFile;
        this._type = type;
    }

    public abstract void compile();
    public abstract void destroy();
}

class ShaderProgram {
    protected Shader[] shaders;
    protected bool _isCompiled = false;

    public @property bool isCompiled() {
        return _isCompiled;
    }

    this(Shader[] shaders) {
        this.shaders = shaders;
    }

    public void compile() {
        foreach (shader; shaders) {
            shader.compile();
        }
        _isCompiled = true;
    }

    public abstract void use();

    public void destroy() {
    }
}

enum ShaderType {
    vertexShader,
    fragmentShader,
    geometryShader,
    tesselationControlShader,
    tesselationEvaluationShader,
    computeShader,
}

interface ShaderProgramFactory {
    ShaderProgram createShaderProgram();
}

class CachedShaderProgramFactory : ShaderProgramFactory {
    private ShaderProgram shaderProgram;

    protected abstract ShaderProgram create();

    public override ShaderProgram createShaderProgram() {
        if (!shaderProgram) {
            shaderProgram = create();
        }
        return shaderProgram;
    }
}

class ShaderProgramComponent : EntityComponent {
    mixin EntityComponentIdentity!"ShaderProgramComponent";

    private ShaderProgram _shaderProgram;

    public @property ShaderProgram shaderProgram() {
        return _shaderProgram;
    }

    this(ShaderProgram shaderProgram) {
        this._shaderProgram = shaderProgram;
    }
}

class UnsupportedShaderTypeException : Exception {
    this(ShaderType type) {
        super("Unsupported shader type: " ~ to!string(type));
    }
}

class ShaderCompilationException : Exception {
    mixin basicExceptionCtors;
}

struct ColorRgba {
    ubyte r, g, b, a;
}

struct ColorRgb {
    ubyte r, g, b;
}

class TextureColorComponent : EntityComponent, Snapshotable {
    mixin EntityComponentIdentity!"TextureColorComponent";

    public ColorRgb color;

    this(ColorRgb color) {
        this.color = color;
    }

    public string[string] getSnapshotData() {
        return [
            "r": to!string(color.r),
            "g": to!string(color.g),
            "b": to!string(color.b)
        ];
    }
}
