# Retrograde Model File Format (.rgm)

An RGM file contains data for 3D models used in the Retrograde Game Engine. It is a binary format designed to efficiently store model data. This document describes the file format in detail.

The offsets and sizes shown are in bytes. Types correspond to [native types in the D programming language](https://dlang.org/spec/type.html#basic-data-types) or types specified further in the document. All integer values are stored in little-endian format, and floating-point values follow the IEEE 754 standard.

The magic number is stored as raw bytes in the order listed (i.e., `0x52` first, then `0x47`, `0x4D`, `0x20`) and is not subject to endian conversion.

The coordinate system is right-handed, Y-up, with negative-Z forward.

This document describes `version 1` of the RGM file format.

> **Note:** Version 1 is currently in development and has not been publicly released. The format may change without notice.

For an example file, see `examples/cube.rgm`

## Changelog

| Version | Description     |
| ------- | --------------- |
| 1       | Initial version |

## File Structure

The binary file format consists of a header followed by data sections. Each section contains information about the meshes (with their vertices and faces) and the materials that make up the 3D model.

Total file size = 14 + sum_meshes(13 + vertexCount × 24 + faceCount × 12 + uvChannelCount × vertexCount × 8) + sum_materials(materialEntrySize).

## Header (14 bytes)

| Offset | Size | Type   | Description                        |
| ------ | ---- | ------ | ---------------------------------- |
| 0x00   | 4    | uint   | Magic number (0x52474D20 - "RGM ") |
| 0x04   | 2    | ushort | Version number                     |
| 0x06   | 4    | uint   | Amount of meshes                   |
| 0x0A   | 4    | uint   | Amount of materials                |

The version number is a `ushort` that is incremented with every change to the format. The current version is `1`.

## Mesh (variable size)

After the header a variable amount of sections of individual mesh data is present.
The amount of sections should be equal to the amount of meshes specified in the header.
Meshes are identified by their 0-based index in the file.

| Offset | Size                            | Type    | Description                       |
| ------ | ------------------------------- | ------- | --------------------------------- |
| 0x00   | 4                               | uint    | Vertex count                      |
| 0x04   | 4                               | uint    | Face count                        |
| 0x08   | 1                               | ubyte   | UV channel count                  |
| 0x09   | 4                               | uint    | Material index (0 = no material)  |
| 0x0D   | vertexCount × 24                | Vertex  | Vertex data                       |
| ...    | faceCount × 12                  | Face    | Face data                         |
| ...    | uvChannelCount × vertexCount × 8 | UvCoord | UV channel data                  |

The material index references a material by its declared `index` field in the materials section, not by array position. A value of `0` is reserved as the sentinel meaning "no material assigned".

### Vertex (24 bytes per vertex)

Each vertex is represented by three 32-bit floating point numbers for position (x, y, z) and three 32-bit floating point numbers for RGB color (r, g, b). Color component values are expected to be in the range `[0.0, 1.0]`.

Note: Only position and color are stored in the file. When loaded into the engine, vertices are extended with a W coordinate (set to 1.0) and an alpha component (set to 1.0).

| Offset | Size | Type  | Description  |
| ------ | ---- | ----- | ------------ |
| 0x00   | 4    | float | X coordinate |
| 0x04   | 4    | float | Y coordinate |
| 0x08   | 4    | float | Z coordinate |
| 0x0C   | 4    | float | R color      |
| 0x10   | 4    | float | G color      |
| 0x14   | 4    | float | B color      |

### Face (12 bytes per face)

Each face is a triangle polygon represented by three 0-based vertex indices. The face section is variable in size because the number of faces in a mesh can vary; the total size of the face section is `faceCount × 12`.

Vertex indices are wound in **counter-clockwise (CCW)** order when viewed from the front face. The engine enables back-face culling using the OpenGL ES 3 default front-face convention (CCW).

| Offset | Size | Type | Description    |
| ------ | ---- | ---- | -------------- |
| 0x00   | 4    | uint | Vertex index 1 |
| 0x04   | 4    | uint | Vertex index 2 |
| 0x08   | 4    | uint | Vertex index 3 |

### UV Channel Data (uvChannelCount × vertexCount × 8 bytes)

When `uvChannelCount` is greater than zero, UV texture coordinates follow the face data. The data is laid out **channel-major**: all UV pairs for channel 0 first (one pair per vertex, in vertex order), then all UV pairs for channel 1, and so on through channel `uvChannelCount - 1`. Channels must be contiguous starting at 0 (matching the glTF `TEXCOORD_0`, `TEXCOORD_1`, ... convention). Each pair is two 32-bit little-endian IEEE 754 floats.

The maximum number of UV channels is 8.

| Offset | Size | Type  | Description  |
| ------ | ---- | ----- | ------------ |
| 0x00   | 4    | float | U coordinate |
| 0x04   | 4    | float | V coordinate |

## Materials (variable size)

After all mesh sections the materials section follows. The number of material entries is equal to the material count specified in the header.

Materials are referenced by meshes via their declared `index` field. Material indices must satisfy:

- `index >= 1` (0 is reserved as the "no material" sentinel)
- All indices within a single file are unique (no two materials share the same index)
- Indices may otherwise be arbitrary — gaps and non-sequential order are allowed

### Material Entry (variable size)

| Offset | Size | Type  | Description                              |
| ------ | ---- | ----- | ---------------------------------------- |
| 0x00   | 4    | uint  | Material index (≥ 1, unique within file) |
| 0x04   | 1    | ubyte | Material type                            |
| 0x05   | ...  | ...   | Type-specific payload                    |

### Material Types

| Value | Name          | Description                                                  |
| ----- | ------------- | ------------------------------------------------------------ |
| 1     | Vertex Colors | Renders using only the per-vertex RGB colors. No payload.    |
| 2     | Unlit         | Passthrough material — references a single texture by name.  |

### Vertex Colors Payload (type = 1)

No payload bytes. The material entry ends after the type byte.

### Unlit Payload (type = 2)

| Offset | Size       | Type    | Description                          |
| ------ | ---------- | ------- | ------------------------------------ |
| 0x00   | 2          | ushort  | Texture name length in bytes         |
| 0x02   | nameLength | ubyte[] | Texture name (UTF-8, no terminator)  |

The name length is the byte length of the UTF-8 encoded name, not the codepoint count. The name has no null terminator.
