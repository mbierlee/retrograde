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

module retrograde.sdl2.tilemap;

version(Have_derelict_sdl2) {

import retrograde.tiles;
import retrograde.rendering.twodee.sdl2.renderer;
import retrograde.math;

import poodinis;

import derelict.sdl2.sdl;
import derelict.sdl2.image;

import std.string;
import std.experimental.logger;

class Sdl2TilemapComposer {
	private SDL_Surface*[const(Tileset)] tilesetSurfaces;

	@Autowire
	private Sdl2RenderSystem renderer;

	@Autowire
	private Logger logger;

	@Autowire
	private CompositionStrategyFactory compositionStrategyFactory;

	public SDL_Texture* composeTilemapTexture(Tilemap tilemap) {
		cleanState();
		loadTilesetSurfaces(tilemap.tilesets);
		SDL_Surface* composedSurface = blitLayers(tilemap);
		if (!composedSurface) {
			throw new TileCompositionException("Unable to compose composite surface of tilemap.");
		}
		SDL_Texture* composedTexture = renderer.createTextureFromSurface(composedSurface);
		SDL_FreeSurface(composedSurface);
		freeTilesetSurfaces();
		return composedTexture;
	}

	private SDL_Surface* blitLayers(Tilemap tilemap) {
		auto compositionStrategy = compositionStrategyFactory.createStrategy(tilemap);
		auto tilemapDimensions = compositionStrategy.getDimensions(tilemap);

		SDL_Surface* composedSurface = SDL_CreateRGBSurface(0, cast(int) tilemapDimensions.width, cast(int) tilemapDimensions.height, 32, 0, 0, 0, 0);
		SDL_Rect destinationRectangle;
		SDL_Rect sourceRectangle;
		foreach (layer; tilemap.layers) {
			ulong currentRow = 1;
			ulong currentColumn = 1;

			foreach (tile; layer.tileData) {
				if (!tile.empty) {
					SDL_Surface* tilesetSurface = tilesetSurfaces[cast(const(Tileset)) tile.parentTileset];
					sourceRectangle.x = cast(int) tile.positionInTileset.x;
					sourceRectangle.y = cast(int) tile.positionInTileset.y;
					sourceRectangle.w = cast(int) tile.parentTileset.tileWidth;
					sourceRectangle.h = cast(int) tile.parentTileset.tileHeight;

					auto tileDestination = compositionStrategy.getTileDestination(tilemap, currentRow, currentColumn);
					destinationRectangle.x = cast(int) tileDestination.x;
					destinationRectangle.y = cast(int) tileDestination.y;

					SDL_BlitSurface(tilesetSurface, &sourceRectangle, composedSurface, &destinationRectangle);
				}

				currentColumn += 1;
				if (currentColumn > tilemap.width) {
					currentRow += 1;
					currentColumn = 1;
				}
			}
		}

		return composedSurface;
	}

	private void cleanState() {
		tilesetSurfaces.destroy();
	}

	private void loadTilesetSurfaces(Tileset[] tilesets) {
		foreach (tileset; tilesets) {
			SDL_Surface* surface = IMG_Load(tileset.imageName.toStringz());
			if (!surface) {
				logger.errorf("Could not load tileset image %s", tileset.imageName);
				continue;
			}

			tilesetSurfaces[tileset] = surface;
		}
	}

	private void freeTilesetSurfaces() {
		foreach (surface; tilesetSurfaces) {
			SDL_FreeSurface(surface);
		}
	}
}

}
