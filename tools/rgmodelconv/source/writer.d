/**
 * rgmodelconv - RGM model format writer.
 *
 * Builds an RGM file in memory from the intermediate `ModelData`. Meshes are
 * written in primitive order; materials are classified (unlit, vertex-colors or
 * the invalid sentinel) and emitted in first-referenced order, and the textures
 * they reference are collected into a shared, de-duplicated texture list.
 *
 * Lit (PBR) source materials are written as `unlit` ones: only their base color
 * (albedo) texture is carried over, as the RGM format cannot express the
 * metallic-roughness inputs yet.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module writer;

import std.array : Appender, appender;
import std.bitmanip : nativeToLittleEndian;
import std.path : buildPath, setExtension;

import retrograde.assets.rgm : rgmMagicNumber;
import retrograde.assets.model : MaterialType, MaterialFlags, maxUvChannels, noMaterial,
    TextureType, TextureMagFilter, TextureMinFilter, TextureWrap;

import model : Primitive, MaterialInfo, ModelData;

enum ushort rgmVersion = 1;

/// A resolved texture entry as it will be written: the final (renamed/prefixed)
/// path and its sampling filters and wrap modes. Used as the de-duplication key
/// so two materials sharing an image *and* sampler collapse to a single texture
/// entry.
private struct OutTexture {
    string path;
    TextureMagFilter magFilter;
    TextureMinFilter minFilter;
    TextureWrap wrapS;
    TextureWrap wrapT;
}

/**
 * Encode a model into RGM bytes.
 *
 * Params:
 *   data              = The intermediate model to encode.
 *   renameImages      = When true, referenced texture paths get their extension
 *                       rewritten to `.rgi`; otherwise the original path is kept.
 *   texturePathPrefix = Optional prefix prepended to every texture path.
 *   forceBackfaceCulling = When true, every material is written as single-sided,
 *                       ignoring the source model's double-sided flag.
 * Throws: Exception if the model exceeds an RGM format limit (too many UV
 *   channels, or a texture path longer than a ushort can address).
 */
ubyte[] encodeRgm(in ModelData data, bool renameImages, string texturePathPrefix,
    bool forceBackfaceCulling = false) {
    // Map glTF material index -> RGM material index. Materials get a sequential
    // 1-based RGM index the first time a primitive references them (in primitive
    // order); materials no primitive references are never emitted. Primitives
    // without a material fall through to the `noMaterial` sentinel.
    uint materialCount = cast(uint) data.materials.length;
    uint[] materialIndexMap = new uint[materialCount];
    uint nextRgmIndex = 1;
    foreach (ref prim; data.primitives) {
        int mi = prim.materialIndex;
        if (mi >= 0 && mi < materialCount && materialIndexMap[mi] == 0) {
            materialIndexMap[mi] = nextRgmIndex++;
        }
    }
    uint usedMaterialCount = nextRgmIndex - 1;

    // Pre-pass: classify every used material and, for unlit materials, resolve the
    // base color texture path into a shared Textures list. Identical paths are
    // deduplicated, so several materials can reference the same texture by its 1-based
    // index. The classification is recorded here so the material write pass below does
    // not have to re-run it.
    MaterialType[] materialTypes = new MaterialType[materialCount];
    uint[] materialTextureIndices = new uint[materialCount];
    OutTexture[] textures; // Texture at position p has the 1-based index (p + 1).
    uint[OutTexture] textureToIndex;
    for (uint i = 0; i < materialCount; i++) {
        if (materialIndexMap[i] == 0) {
            continue;
        }

        MaterialInfo material = data.materials[i];
        if (material.baseColorTexture.path.length > 0) {
            materialTypes[i] = MaterialType.unlit;
            string path = renameImages
                ? setExtension(material.baseColorTexture.path, "rgi") : material.baseColorTexture.path;
            if (texturePathPrefix.length > 0) {
                path = buildPath(texturePathPrefix, path);
            }

            OutTexture texture = OutTexture(path, material.baseColorTexture.magFilter,
                material.baseColorTexture.minFilter, material.baseColorTexture.wrapS,
                material.baseColorTexture.wrapT);
            uint* existing = texture in textureToIndex;
            if (existing !is null) {
                materialTextureIndices[i] = *existing;
            } else {
                uint textureIndex = cast(uint)(textures.length + 1);
                textureToIndex[texture] = textureIndex;
                textures ~= texture;
                materialTextureIndices[i] = textureIndex;
            }
        } else if (!material.hasAnyTexture && materialHasVertexColors(data.primitives, i)) {
            materialTypes[i] = MaterialType.vertexColors;
        } else {
            materialTypes[i] = MaterialType.invalid;
        }
    }

    auto buf = appender!(ubyte[])();

    // Header (18 bytes)
    buf.put(cast(const(ubyte)[]) rgmMagicNumber); // Magic "RGM "
    writeUshort(buf, rgmVersion); // Version
    writeUint(buf, cast(uint) data.primitives.length); // Mesh count
    writeUint(buf, usedMaterialCount); // Material count
    writeUint(buf, cast(uint) textures.length); // Texture count

    foreach (ref prim; data.primitives) {
        writeMeshData(buf, prim, materialIndexMap);
    }

    // Emit one material entry per used material, in the order they were first
    // referenced. A material maps to `unlit` when it references an external base
    // color texture, or to `vertexColors` when it is textureless and drawn with
    // per-vertex colors; anything else falls back to the `invalid` sentinel.
    for (uint i = 0; i < materialCount; i++) {
        if (materialIndexMap[i] == 0) {
            continue;
        }

        MaterialType type = materialTypes[i];

        writeUint(buf, materialIndexMap[i]); // Material index
        writeUbyte(buf, cast(ubyte) type); // Material type

        // The `invalid` sentinel carries no common-flags byte and no payload.
        if (type == MaterialType.invalid) {
            continue;
        }

        bool doubleSided = !forceBackfaceCulling && data.materials[i].doubleSided;
        ubyte flags = doubleSided ? cast(ubyte) MaterialFlags.doubleSided : 0;
        writeUbyte(buf, flags); // Common flags (bit 0 = double-sided)

        if (type == MaterialType.unlit) {
            writeUint(buf, materialTextureIndices[i]); // Referenced texture index
        }
    }

    // Emit the Textures list. Every texture produced here is a `reference`: its payload
    // is the (optionally renamed) texture path. The `embedded` texture type is not yet
    // implemented and is never written. Sampler filters and wrap modes come from the glTF
    // sampler, falling back to `unspecified` when the source left them unset.
    foreach (idx, texture; textures) {
        writeUint(buf, cast(uint)(idx + 1)); // Texture index (1-based)
        writeUbyte(buf, cast(ubyte) TextureType.reference); // Texture type
        writeUbyte(buf, cast(ubyte) texture.magFilter); // magFilter
        writeUbyte(buf, cast(ubyte) texture.minFilter); // minFilter
        writeUbyte(buf, cast(ubyte) texture.wrapS); // wrapS
        writeUbyte(buf, cast(ubyte) texture.wrapT); // wrapT
        writeString(buf, texture.path); // Path payload
    }

    return buf.data;
}

/**
 * Returns true if any primitive that references the material at `materialIndex`
 * carries per-vertex colors (vertex colors are a mesh attribute, not a material one).
 */
private bool materialHasVertexColors(in Primitive[] primitives, uint materialIndex) {
    foreach (ref prim; primitives) {
        if (prim.materialIndex >= 0 && cast(uint) prim.materialIndex == materialIndex
            && prim.hasColors) {
            return true;
        }
    }

    return false;
}

private void writeMeshData(ref Appender!(ubyte[]) buf, in Primitive prim, const uint[] materialIndexMap) {
    uint triangleCount = cast(uint)(prim.indices.length / 3);
    uint uvChannelCount = cast(uint) prim.uvChannels.length;

    if (uvChannelCount > maxUvChannels) {
        throw new Exception(
            "Mesh has more UV channels than the RGM format supports (max " ~
                maxUvChannels.stringof ~ ").");
    }

    uint materialIndex = (prim.materialIndex >= 0 && prim.materialIndex < materialIndexMap.length)
        ? materialIndexMap[prim.materialIndex] : noMaterial;

    // Mesh header
    writeUint(buf, prim.vertexCount);
    writeUint(buf, triangleCount);
    writeUbyte(buf, cast(ubyte) uvChannelCount);
    writeUint(buf, materialIndex);

    // Vertex data (24 bytes per vertex: x, y, z, r, g, b)
    for (uint i = 0; i < prim.vertexCount; i++) {
        writeFloat(buf, prim.positions[i * 3 + 0]);
        writeFloat(buf, prim.positions[i * 3 + 1]);
        writeFloat(buf, prim.positions[i * 3 + 2]);

        if (prim.hasColors) {
            writeFloat(buf, prim.colors[i * 3 + 0]);
            writeFloat(buf, prim.colors[i * 3 + 1]);
            writeFloat(buf, prim.colors[i * 3 + 2]);
        } else {
            // Default to white when no vertex colors are present.
            writeFloat(buf, 1.0f);
            writeFloat(buf, 1.0f);
            writeFloat(buf, 1.0f);
        }
    }

    // Face data (12 bytes per face: 3 vertex indices)
    for (uint i = 0; i < triangleCount; i++) {
        writeUint(buf, prim.indices[i * 3 + 0]);
        writeUint(buf, prim.indices[i * 3 + 1]);
        writeUint(buf, prim.indices[i * 3 + 2]);
    }

    // UV channel data (channel-major: all UVs for channel 0, then channel 1, ...)
    for (uint c = 0; c < uvChannelCount; c++) {
        const(float)[] uv = prim.uvChannels[c];
        for (uint i = 0; i < prim.vertexCount; i++) {
            writeFloat(buf, uv[i * 2 + 0]);
            writeFloat(buf, uv[i * 2 + 1]);
        }
    }
}

private void writeUint(ref Appender!(ubyte[]) buf, uint value) {
    ubyte[4] bytes = nativeToLittleEndian(value);
    buf.put(bytes[]);
}

private void writeUbyte(ref Appender!(ubyte[]) buf, ubyte value) {
    buf.put(value);
}

private void writeUshort(ref Appender!(ubyte[]) buf, ushort value) {
    ubyte[2] bytes = nativeToLittleEndian(value);
    buf.put(bytes[]);
}

private void writeFloat(ref Appender!(ubyte[]) buf, float value) {
    ubyte[4] bytes = nativeToLittleEndian(value);
    buf.put(bytes[]);
}

/// Writes a length-prefixed string: a ushort byte length followed by the raw
/// UTF-8 bytes (no null terminator).
private void writeString(ref Appender!(ubyte[]) buf, string value) {
    if (value.length > ushort.max) {
        throw new Exception(
            "String is too long for the RGM format (max " ~ ushort.max.stringof ~ " bytes).");
    }

    writeUshort(buf, cast(ushort) value.length);
    buf.put(cast(const(ubyte)[]) value);
}
