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

module retrograde.pipeline.tiled;

import std.json;
import std.exception;
import std.math;
import std.algorithm;

import retrograde.tiles;
import retrograde.file;
import retrograde.math;

class TiledTilemapReadException : Exception {
    mixin basicExceptionCtors;
}

enum ReadMode {
    LENIENT,
    STRICT
}

class TiledTilemapReader {
    private ReadMode readMode;

    private Tile[ulong] tileCache;

    this() {
        this(ReadMode.STRICT);
    }

    this(ReadMode readMode) {
        this.readMode = readMode;
    }

    public Tilemap readTilemap(File file) {
        tileCache.destroy();
        tileCache[0] = createEmptyTile();
        auto jsonText = file.readAsText();
        auto tilemapJson = parseJSON(jsonText);
        auto tilemap = composeTilemap(tilemapJson);
        tileCache.destroy();
        return tilemap;
    }

    private Tile createEmptyTile() {
        auto tile = new Tile();
        tile.empty = true;
        return tile;
    }

    private TilemapOrientation getOrientation(string orientation) {
        switch(orientation) {
            case "orthogonal":
                return TilemapOrientation.orthogonal;
            case "isometric":
                return TilemapOrientation.isometric;
            default:
                throw new TiledTilemapReadException("Unsupported tilemap orientation: " ~ orientation);
        }
    }

    private Tilemap composeTilemap(ref const JSONValue tilemapJson) {
        if (readMode == ReadMode.STRICT) {
            enforceTilemapOptionSupport(tilemapJson);
        }

        auto tilemap = new Tilemap();

        tilemap.width = tilemapJson["width"].integer;
        tilemap.height = tilemapJson["height"].integer;
        tilemap.tileWidth = tilemapJson["tilewidth"].integer;
        tilemap.tileHeight = tilemapJson["tileheight"].integer;
        tilemap.orientation = getOrientation(tilemapJson["orientation"].str);

        tilemap.tilesets = composeTilesets(tilemapJson["tilesets"].array);
        tilemap.layers = composeLayerData(tilemapJson["layers"].array);

        if (readMode == ReadMode.STRICT) {
            enforce!TiledTilemapReadException(tilemap.tilesets.length > 0, "Tilemap has no tilesets.");
        }

        return tilemap;
    }

    private Tileset[] composeTilesets(ref const JSONValue[] tilesetsJsons) {
        Tileset[] tilesets;

        foreach (tilesetJson; tilesetsJsons) {
            if (readMode == ReadMode.STRICT) {
                enforceTilesetOptionSupport(tilesetJson);
            }

            auto tileset = new Tileset();

            tileset.name = tilesetJson["name"].str;
            tileset.imageName = tilesetJson["image"].str;
            tileset.imageWidth = tilesetJson["imagewidth"].integer;
            tileset.imageHeight = tilesetJson["imageheight"].integer;
            tileset.tileWidth = tilesetJson["tilewidth"].integer;
            tileset.tileHeight = tilesetJson["tileheight"].integer;
            tileset.firstGlobalId = tilesetJson["firstgid"].integer;

            tileset.tiles = composeTileData(tileset);

            tilesets ~= tileset;
        }

        return tilesets;
    }

    private Tile[] composeTileData(ref const Tileset tileset) {
        Tile[] tiles;
        auto tileCount = (tileset.imageHeight / tileset.tileHeight) * (tileset.imageWidth / tileset.tileWidth);

        for (ulong id = 1; id <= tileCount; id++) {
            auto tile = new Tile();
            tile.parentTileset = cast(Tileset) tileset;
            tile.tilesetTileId = id;
            tile.globalTileId = tileset.firstGlobalId + (id - 1);
            tile.empty = false;
            tile.positionInTileset = calculateTilePositionInTileset(tileset, id);
            tiles ~= tile;
            tileCache[tile.globalTileId] = tile;
        }

        return tiles;
    }

    private Vector2UL calculateTilePositionInTileset(ref const Tileset tileset, ulong tileNumber) {
        Vector2UL tilePositionInTileset;

        ulong columns = tileset.imageWidth / tileset.tileWidth;
        ulong row = cast(uint) ceil(cast(double) tileNumber / columns);
        ulong column = tileNumber - ((row - 1) * columns);

        tilePositionInTileset.x = (column - 1) * tileset.tileWidth;
        tilePositionInTileset.y = (row - 1) * tileset.tileHeight;
        return tilePositionInTileset;
    }

    private TileLayer[] composeLayerData(ref const JSONValue[] layersJsons) {
        TileLayer[] layers;

        foreach(layerJson ; layersJsons) {
            if (readMode == ReadMode.STRICT) {
                enforceLayerOptionSupport(layerJson);
            }

            auto layer = new TileLayer();
            layer.name = layerJson["name"].str;

            layer.tileData = composeTileLayerData(layerJson);

            layers ~= layer;
        }

        return layers;
    }

    private Tile[] composeTileLayerData(ref const JSONValue layerJson) {
        Tile[] tiles;

        auto tilesJsonList = layerJson["data"].array;
        foreach (tilesJsonItem; tilesJsonList) {
            auto globalTileId = tilesJsonItem.integer;
            tiles ~= tileCache[globalTileId];
        }

        return tiles;
    }

    private void enforceLayerOptionSupport(ref const JSONValue layerJson) {
        auto name = layerJson["name"].str;
        enforce!TiledTilemapReadException(layerJson["type"].str == "tilelayer", "Only tilelayers layer types are supported in layer " ~ name);
        enforce!TiledTilemapReadException(layerJson["visible"].type == JSON_TYPE.TRUE, "Only visible layers are supported in layer " ~ name);
        enforce!TiledTilemapReadException(layerJson["opacity"].integer == 1, "Only layers with opacity of 1 are supported in layer " ~ name);
    }

    private void enforceTilemapOptionSupport(ref const JSONValue tilemapJson) {
        enforce!TiledTilemapReadException(tilemapJson["version"].integer == 1, "Only Tiled tilemap version 1 is supported by this reader.");
        enforce!TiledTilemapReadException(tilemapJson["renderorder"].str == "right-down", "Only right-down render order is supported.");
    }

    private void enforceTilesetOptionSupport(ref const JSONValue tilesetJson) {
        auto name = tilesetJson["name"].str;
        enforce!TiledTilemapReadException(tilesetJson["spacing"].integer == 0, "Only tileset spacing of 0 is supported in tileset " ~ name);
        enforce!TiledTilemapReadException(tilesetJson["margin"].integer == 0, "Only tileset margin of 0 is supported in tileset " ~ name);
    }

}
