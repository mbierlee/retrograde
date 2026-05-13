# Retrograde Image File Format (.rgi)

An RGI file contains data for a single raster image used by the Retrograde Game Engine. It is a binary format used for textures (albedo maps, normal maps, depth maps, PBR channels, and so on). This document describes the file format in detail.

The offsets and sizes shown are in bytes. Types correspond to [native types in the D programming language](https://dlang.org/spec/type.html#basic-data-types) or types specified further in the document. All integer values are stored in little-endian format, and floating-point values follow the IEEE 754 standard.

The magic number is stored as raw bytes in the order listed (i.e., `0x52` first, then `0x47`, `0x49`, `0x20`) and is not subject to endian conversion.

Pixel data uses a top-left origin: row 0 is the top of the image, and within each row pixels run left to right. For RGBA images the channel order within a pixel is R, G, B, A.

The file holds exactly one image. Multi-image use cases (mipmaps, cubemap faces, texture arrays) are deferred to a future version of this format and are not supported in version 1.

This document describes `version 1` of the RGI file format.

> **Note:** Version 1 is currently in development and has not been publicly released. The format may change without notice.

## Changelog

| Version | Description     |
| ------- | --------------- |
| 1       | Initial version |

## File Structure

An RGI file consists of:

1. A 9-byte file header.
2. A 10-byte image header.
3. (Indexed mode only) a palette section: a 4-byte palette entry count followed by the palette entries.
4. The pixel data — direct samples in `Direct` color mode, palette indices in `Indexed` color mode.

The total file size is fully determined by the header fields, so any extra trailing bytes indicate a malformed file and the loader rejects them.

Total file size:

- **Direct mode**: `9 + 10 + width × height × channelCount × bytesPerChannel(channelFormat)`
- **Indexed mode**: `9 + 10 + 4 + paletteEntryCount × channelCount × bytesPerChannel(channelFormat) + width × height × bytesPerIndex(indexFormat)`

## File Header (9 bytes)

| Offset | Size | Type   | Description                                |
| ------ | ---- | ------ | ------------------------------------------ |
| 0x00   | 4    | uint   | Magic number (0x52474920 - "RGI ")         |
| 0x04   | 2    | ushort | Version number                             |
| 0x06   | 1    | ubyte  | Compression type (see "Compression types") |
| 0x07   | 1    | ubyte  | Color mode (see "Color modes")             |
| 0x08   | 1    | ubyte  | Index format (see "Index formats")         |

The version number is a `ushort` that is incremented with every released change to the format — both layout-breaking changes and additive ones (new channel formats, new compression IDs, new color modes, new index formats). The current version is `1`. See "Versioning" below for the rationale.

The index format byte is only meaningful when the color mode is `Indexed`. In `Direct` color mode it must be `0`; any non-zero value is rejected.

## Image Header (10 bytes)

The image header immediately follows the file header.

| Offset | Size | Type  | Description                                |
| ------ | ---- | ----- | ------------------------------------------ |
| 0x00   | 4    | uint  | Width (in pixels). Must be greater than 0. |
| 0x04   | 4    | uint  | Height (in pixels). Must be greater than 0.|
| 0x08   | 1    | ubyte | Channel count (1..4, see below)            |
| 0x09   | 1    | ubyte | Channel format (see "Channel formats")     |

A width or height of 0 is invalid and the loader will reject the file.

In both color modes, `channelCount` and `channelFormat` describe the **expanded** pixel — that is, the colour channels of the final image. In `Indexed` mode they describe the colour channels of each *palette entry*; the pixel section itself stores indices, not channels.

## Palette Section (Indexed mode only)

In `Indexed` color mode, the palette section follows the image header.

| Offset | Size                              | Type  | Description                              |
| ------ | --------------------------------- | ----- | ---------------------------------------- |
| 0x00   | 4                                 | uint  | Palette entry count (1..maxIndex+1)      |
| 0x04   | count × channelCount × bytesPerChannel | ubyte[] | Palette entries, packed back-to-back |

The palette entry count must be greater than 0 and must not exceed the maximum allowed for the chosen index format: 256 for `u8`, 65 536 for `u16`, or 4 294 967 295 for `u32`. See "Index Formats" below for the per-format caps and how they are derived.

Each palette entry has the same byte layout as a single direct pixel: `channelCount × bytesPerChannel(channelFormat)` bytes, in the same channel order (R, G, B, A) as a direct image.

In `Direct` color mode the palette section is absent.

## Pixel Data

Pixel data immediately follows the image header (in `Direct` mode) or the palette section (in `Indexed` mode). Pixels are tightly packed in row-major order with a top-left origin. There is no padding between rows or between pixels.

In **Direct** color mode each pixel is a sequence of channel samples. Within each pixel, channels appear in the order described under "Channel count semantics", and within each channel samples are encoded according to `channelFormat`. The pixel data section is `width × height × channelCount × bytesPerChannel(channelFormat)` bytes.

In **Indexed** color mode each pixel is a single palette index encoded according to `indexFormat`. The pixel data section is `width × height × bytesPerIndex(indexFormat)` bytes. Every index must be less than the palette entry count; out-of-range indices are rejected.

The loader expands indexed pixel data into direct samples before returning the image, so consumers always see the same byte layout as a direct image of the same dimensions.

For a 2×2 RGBA image laid out in `Direct` mode, pixels appear as:

```
+----+----+----+----+   row 0 = top
| R0 | G0 | B0 | A0 |   pixel (0, 0)
+----+----+----+----+
| R1 | G1 | B1 | A1 |   pixel (1, 0)
+----+----+----+----+
| R2 | G2 | B2 | A2 |   pixel (0, 1)
+----+----+----+----+
| R3 | G3 | B3 | A3 |   pixel (1, 1)
+----+----+----+----+   row 1 = bottom
```

## Channel Count Semantics

Channel count maps to image meaning by convention (matching PNG, STB image, and glTF):

| Channel count | Layout per pixel | Conventional meaning |
| ------------- | ---------------- | -------------------- |
| 1             | Y                | Grayscale            |
| 2             | Y, A             | Grayscale + alpha    |
| 3             | R, G, B          | RGB                  |
| 4             | R, G, B, A       | RGBA                 |

The semantic role of the image (albedo, normal map, depth map, PBR mask, ...) is decided by the consumer of the file. The format does not tag images with a material role.

## Channel Formats

| ID   | Name | Bytes per channel | Description                         |
| ---- | ---- | ----------------- | ----------------------------------- |
| 0x00 | u8   | 1                 | 8-bit unsigned integer per channel  |
| 0x01 | u16  | 2                 | 16-bit unsigned integer per channel |
| 0x02 | u32  | 4                 | 32-bit unsigned integer per channel |

Other IDs are reserved for future formats and are not yet defined.

Multi-byte channel samples (`u16`, `u32`) are stored in **little-endian** byte order in the pixel data section, matching the rest of the format. The loader does not byte-swap on read: the in-memory pixel data buffer contains the same bytes in the same order they appeared on disk. Consumers that read samples as `ushort` / `uint` are responsible for any endian conversion they may need (a no-op on the engine's currently supported little-endian targets).

In `Indexed` color mode the same rule applies to palette entries: a palette entry for a `u16` channel format is `channelCount × 2` little-endian bytes, expanded into the pixel data buffer verbatim during the index-to-sample resolution.

## Color Modes

| ID   | Name    | Description                                                                                  |
| ---- | ------- | -------------------------------------------------------------------------------------------- |
| 0x00 | Direct  | Pixel data is stored as direct channel samples. No palette section is present.               |
| 0x01 | Indexed | Pixel data is stored as palette indices. A palette section follows the image header.         |

Other IDs are reserved for future modes and are not yet defined.

## Index Formats

The index format determines how each palette index in the pixel data section is encoded. It also bounds the maximum palette size — for `u8` and `u16` the format itself is the binding limit, while for `u32` the limit is the size of the palette entry count field (a `uint`, max 4 294 967 295 entries).

| ID   | Name | Bytes per index | Maximum palette entries           |
| ---- | ---- | --------------- | --------------------------------- |
| 0x00 | u8   | 1               | 256                               |
| 0x01 | u16  | 2               | 65 536                            |
| 0x02 | u32  | 4               | 4 294 967 295 (palette-count cap) |

In `Direct` color mode this field must be `0` and is otherwise unused. Other IDs are reserved for future index sizes.

Indices are stored little-endian, the same way as every other multi-byte integer in the format.

## Compression Types

Compression applies to the pixel data section only; the file header, image header, and palette section are always uncompressed.

| ID   | Name | Description                       |
| ---- | ---- | --------------------------------- |
| 0x00 | None | Pixel data is stored uncompressed |

Other IDs are reserved for future codecs and are not yet defined.

## Versioning

Once a version of the format is published, **any** further change bumps the version field — both layout-breaking changes and additive ones such as new channel formats, color modes, index formats, or compression IDs.

This avoids confusing forward-compatibility behaviour: a loader built against version *N* knows it understands every byte of a version-*N* file, and rejects any other version up front rather than rejecting individual unrecognised IDs partway through parsing. Tools and converters can decide which version to emit based on which features they need, and consumers can pin to a known-good version with confidence.

While version 1 is still in development (see the note at the top of this document), the format may change in place without bumping the version. After release, the rule above applies.

## Examples

### Direct 2×2 RGBA

The bytes below describe a 2×2 RGBA image in `Direct` mode: red, green, blue, and translucent white.

```
Offset  Bytes                                      Field
------  -----------------------------------------  ----------------------------
0x00    52 47 49 20                                Magic ("RGI ")
0x04    01 00                                      Version (1)
0x06    00                                         Compression type (None)
0x07    00                                         Color mode (Direct)
0x08    00                                         Index format (unused / 0)
0x09    02 00 00 00                                Width (2)
0x0D    02 00 00 00                                Height (2)
0x11    04                                         Channel count (4 — RGBA)
0x12    00                                         Channel format (u8)
0x13    FF 00 00 FF                                Pixel (0, 0): red
0x17    00 FF 00 FF                                Pixel (1, 0): green
0x1B    00 00 FF FF                                Pixel (0, 1): blue
0x1F    FF FF FF 80                                Pixel (1, 1): translucent white
```

Total file size: `9 + 10 + 2 × 2 × 4 × 1 = 35` bytes.

### Indexed 2×2 RGB with a 4-entry u8 palette

The bytes below describe the same 2×2 image — red, green, blue, white — but stored with a 4-colour RGB palette and `u8` indices.

```
Offset  Bytes                       Field
------  --------------------------  ----------------------------
0x00    52 47 49 20                 Magic ("RGI ")
0x04    01 00                       Version (1)
0x06    00                          Compression type (None)
0x07    01                          Color mode (Indexed)
0x08    00                          Index format (u8)
0x09    02 00 00 00                 Width (2)
0x0D    02 00 00 00                 Height (2)
0x11    03                          Channel count (3 — RGB)
0x12    00                          Channel format (u8)
0x13    04 00 00 00                 Palette entry count (4)
0x17    FF 00 00                    Palette entry 0: red
0x1A    00 FF 00                    Palette entry 1: green
0x1D    00 00 FF                    Palette entry 2: blue
0x20    FF FF FF                    Palette entry 3: white
0x23    00 01 02 03                 Pixel indices: red, green, blue, white
```

Total file size: `9 + 10 + 4 + 4 × 3 × 1 + 2 × 2 × 1 = 39` bytes.

After loading, the engine pre-expands the indexed pixel data into direct RGB samples, so consumers see the same in-memory layout as a `Direct`-mode image of the same dimensions and channel count.
