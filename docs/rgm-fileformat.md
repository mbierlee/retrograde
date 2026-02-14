# Retrograde Model File Format (.rgm)

An RGM file contains data for 3D models used in the Retrograde Game Engine. It is a binary format designed to efficiently store model data. This document describes the file format in detail.

The offsets and sizes shown are in bytes. Types correspond to [native types in the D programming language](https://dlang.org/spec/type.html#basic-data-types) or types specified further in the document. All integer values are stored in little-endian format, and floating-point values follow the IEEE 754 standard.

The coordinate system is right-handed, Y-up, with negative-Z forward.

This document describes `version 1` of the RGM file format.

For an example file, see `examples/cube.rgm`

## File Structure

The binary file format consists of a header followed by data sections. Each section contains information about the meshes, vertices, and faces that make up the 3D model.

Total file size = 10 + sum of (8 + vertexCount × 24 + faceCount × 12) for each mesh.

## Header (10 bytes)
| Offset | Size | Type   | Description                        |
|--------|------|--------|------------------------------------|
| 0x00   | 4    | uint   | Magic number (0x52474D20 - "RGM ") |
| 0x04   | 2    | ushort | Version number                     |
| 0x06   | 4    | uint   | Amount of meshes                   |

The version number is a `ushort` that is incremented with every change to the format. The current version is `1`.

## Mesh (variable size)
After the header a variable amount of sections of individual mesh data is present. 
The amount of sections should be equal to the amount of meshes specified in the header.

| Offset | Size                | Type   | Description                        |
|--------|---------------------|--------|------------------------------------|
| 0x00   | 4                   | uint   | Vertex count                       |
| 0x04   | 4                   | uint   | Face count                         |
| 0x08   | vertexCount × 24    | Vertex | Vertex data                        |
| ...    | faceCount × 12      | Face   | Face data                          |

### Vertex (24 bytes per vertex)
Each vertex is represented by three 32-bit floating point numbers for position (x, y, z) and three 32-bit floating point numbers for RGB color (r, g, b).

Note: Only position and color are stored in the file. When loaded into the engine, vertices are extended with a W coordinate (set to 1.0) and an alpha component (set to 1.0).

| Offset | Size | Type   | Description                        |
|--------|------|--------|------------------------------------|
| 0x00   | 4    | float  | X coordinate                       |
| 0x04   | 4    | float  | Y coordinate                       |
| 0x08   | 4    | float  | Z coordinate                       |
| 0x0C   | 4    | float  | R color                            |
| 0x10   | 4    | float  | G color                            |
| 0x14   | 4    | float  | B color                            |

### Face (12 bytes per face)
Each face is a triangle polygon represented by three 0-based vertex indices. The face section is variable in size because the number of faces in a mesh can vary; the total size of the face section is `faceCount × 12`.

| Offset | Size | Type   | Description                        |
|--------|------|--------|------------------------------------|
| 0x00   | 4    | uint   | Vertex index 1                     |
| 0x04   | 4    | uint   | Vertex index 2                     |
| 0x08   | 4    | uint   | Vertex index 3                     |