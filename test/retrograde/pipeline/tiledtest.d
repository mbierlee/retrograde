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

import retrograde.pipeline.tiled;
import retrograde.file;
import retrograde.tiles;
import retrograde.math;

import dunit;

import std.exception;

class TiledTilemapReaderTest {
    mixin UnitTest;

    private static string UNSUPPORTED_TEST_TILESET =
    `{
        "version": 666,
        "height":1,
        "width":1,
        "tilewidth":1,
        "tileheight":1,
        "orientation": "isometric",
        "tilesets": [],
        "layers": []
    }`;

    private static string TEST_TILESET =
    `{
        "height":1,
        "layers": [
            {
                "data":[0, 4],
                "height":1,
                "name":"Tile Layer 1",
                "opacity":1,
                "type":"tilelayer",
                "visible":true,
                "width":2,
                "x":0,
                "y":0
            }
        ],
        "nextobjectid":1,
        "orientation":"orthogonal",
        "properties": {},
        "renderorder":"right-down",
        "tileheight":32,
        "tilesets": [
            {
                "firstgid":1,
                "image":"pinkelephantland.png",
                "imageheight":64,
                "imagewidth":160,
                "margin":0,
                "name":"pinkelephantland",
                "properties": {},
                "spacing":0,
                "tileheight":32,
                "tilewidth":32
            }
        ],
        "tilewidth":32,
        "version":1,
        "width":2
    }`;

    private Tilemap tilemap;

    @BeforeEach
    private void createTestTilemap() {
        auto reader = new TiledTilemapReader();
        auto mapFile = new VirtualTextFile("supermap.json", TEST_TILESET);
        tilemap = reader.readTilemap(mapFile);
    }

    @Test
    public void testReadTilemap() {
        assertNotNull(tilemap);
    }

    @Test
    public void testReadTilemapWidthHeight() {
        assertEquals(1, tilemap.height);
        assertEquals(2, tilemap.width);
    }

    @Test
    public void testReadTilemapTileWidthHeight() {
        assertEquals(32, tilemap.tileHeight);
        assertEquals(32, tilemap.tileWidth);
    }

    @Test
    public void testReadTilemapOrientation() {
        assertEquals(TilemapOrientation.orthogonal, tilemap.orientation);
    }

    @Test
    public void testLenientMode() {
        auto reader = new TiledTilemapReader(ReadMode.LENIENT);
        auto mapFile = new VirtualTextFile("supermap.json", UNSUPPORTED_TEST_TILESET);
        reader.readTilemap(mapFile);
    }

    @Test
    public void testStrictMode() {
        auto reader = new TiledTilemapReader(ReadMode.STRICT);
        auto mapFile = new VirtualTextFile("supermap.json", UNSUPPORTED_TEST_TILESET);
        assertThrown!TiledTilemapReadException(reader.readTilemap(mapFile));
    }

    @Test
    public void testReadTilemapTilesets() {
        auto tileset = tilemap.tilesets[0];

        assertEquals("pinkelephantland", tileset.name);
        assertEquals("pinkelephantland.png", tileset.imageName);
        assertEquals(160, tileset.imageWidth);
        assertEquals(64, tileset.imageHeight);
        assertEquals(32, tileset.tileWidth);
        assertEquals(32, tileset.tileHeight);
        assertEquals(10, tileset.tiles.length);
    }

    @Test
    public void testReadTilemapTilesetData() {
        auto tileset = tilemap.tilesets[0];

        auto firstTile = tileset.tiles[0];
        assertEquals(1, firstTile.tilesetTileId);
        assertEquals(1, firstTile.globalTileId);
        assertEquals(Vector2UL(0, 0), firstTile.positionInTileset);
        assertSame(tileset, firstTile.parentTileset);

        auto lastTile = tileset.tiles[9];
        assertEquals(10, lastTile.tilesetTileId);
        assertEquals(10, lastTile.globalTileId);
        assertEquals(Vector2UL(128, 32), lastTile.positionInTileset);
        assertSame(tileset, lastTile.parentTileset);
    }

    @Test
    public void testReadTilemapTileLayers() {
        auto layer = tilemap.layers[0];

        assertEquals("Tile Layer 1", layer.name);
        assertEquals(2, layer.tileData.length);
    }

    @Test
    public void testReadTilemapTileLayerData() {
        auto layer = tilemap.layers[0];

        auto firstTile = layer.tileData[0];
        assertTrue(firstTile.empty);

        auto lastTile = layer.tileData[1];
        assertEquals(4, lastTile.globalTileId);
        assertFalse(lastTile.empty);
    }
}
