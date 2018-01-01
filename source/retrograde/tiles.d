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

module retrograde.tiles;

import retrograde.entity;
import retrograde.math;

import std.exception;

class TileCompositionException : Exception {
    mixin basicExceptionCtors;
}

enum TilemapOrientation {
    orthogonal,
    isometric
}

class Tilemap {
    public ulong width;
    public ulong height;
    public ulong tileWidth;
    public ulong tileHeight;
    public TilemapOrientation orientation;

    public Tileset[] tilesets;
    public TileLayer[] layers;
}

class Tileset {
    public string name;
    public string imageName;
    public ulong imageWidth;
    public ulong imageHeight;
    public ulong tileWidth;
    public ulong tileHeight;
    public ulong firstGlobalId;

    public Tile[] tiles;
}

class Tile {
    public Tileset parentTileset;
    public ulong globalTileId;
    public ulong tilesetTileId;
    public bool empty;
    public Vector2UL positionInTileset;
}

class TileLayer {
    public Tile[] tileData;
    public string name;
}

class TilemapComponent : EntityComponent {
    mixin EntityComponentIdentity!"TilemapComponent";

    private Tilemap _tilemap;

    public this(Tilemap tilemap) {
        this._tilemap = tilemap;
    }

    public @property tilemap() {
        return _tilemap;
    }
}

class RenderableTilemapComponent {
    mixin EntityComponentIdentity!"RenderableTilemapComponent";
}

interface CompositionStrategy {
    public RectangleUL getDimensions(Tilemap tilemap);
    public RectangleUL getTileDestination(Tilemap tilemap, ulong row, ulong column);
}

class OrthogonalCompositionStrategy : CompositionStrategy {
    public RectangleUL getDimensions(Tilemap tilemap) {
        return RectangleUL(0, 0, tilemap.width * tilemap.tileWidth, tilemap.height * tilemap.tileHeight);
    }

    public RectangleUL getTileDestination(Tilemap tilemap, ulong row, ulong column) {
        return RectangleUL((column - 1) * tilemap.tileWidth, (row - 1) * tilemap.tileHeight, 0, 0);
    }
}

class IsometricCompositionStrategy : CompositionStrategy {
    public RectangleUL getDimensions(Tilemap tilemap) {
        return RectangleUL(0, 0, tilemap.tileWidth * (tilemap.width + tilemap.height) / 2, tilemap.tileHeight * (tilemap.width + tilemap.height) / 2);
    }

    public RectangleUL getTileDestination(Tilemap tilemap, ulong row, ulong column) {
        auto c = column - 1;
        auto r = row - 1;
        auto originShift = cast(int) ((tilemap.height * tilemap.tileWidth) / 2) - (tilemap.tileWidth / 2);
        auto xPosition = cast(int) (tilemap.tileWidth * (c * 0.5)) - cast(int) (tilemap.tileWidth * (r * 0.5)) + originShift;
        auto yPosition = cast(int) (tilemap.tileHeight * (r * 0.5)) + cast(int) (tilemap.tileHeight * (c * 0.5));
        return RectangleUL(xPosition, yPosition, 0, 0);
    }
}

class CompositionStrategyFactory {
    public CompositionStrategy createStrategy(Tilemap tilemap) {
        switch(tilemap.orientation) {
            case TilemapOrientation.orthogonal:
                return new OrthogonalCompositionStrategy();
            case TilemapOrientation.isometric:
                return new IsometricCompositionStrategy();
            default:
                throw new TileCompositionException("No composition strategy available for orientation " ~ tilemap.orientation.stringof);
        }
    }
}
