/**
 * rgmodelconv - RGM model format writer.
 *
 * Builds an RGM file in memory from the intermediate `ModelData`. Meshes are
 * written in primitive order; materials are classified (unlit, PBR
 * metallic-roughness, vertex-colors or the invalid sentinel) and emitted in
 * first-referenced order, and the textures they reference are collected into a
 * shared, de-duplicated texture list.
 *
 * Textured materials keep their source shading model: `KHR_materials_unlit` ones
 * become `unlit`, the rest become `pbrMetallicRoughness`. Both carry the base color
 * (albedo) texture; the lit types additionally carry the normal map and its strength
 * when the source supplies one, and `pbrMetallicRoughness` carries the packed
 * metallic-roughness map alongside the metallic and roughness factors, plus the
 * occlusion map and its strength. The remaining PBR input (emissive) is dropped, as
 * the RGM format cannot express it yet.
 *
 * A material can name the type it wants directly in its glTF `extras.rg_mat`, which
 * overrides that classification. This is the only way to assign a type that no glTF
 * material maps onto, such as `lambert`.
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
import std.stdio : stderr;
import std.string : icmp;
import std.typecons : Nullable;

import retrograde.assets.rgm : rgmMagicNumber;
import retrograde.assets.model : hasMetallicRoughness, hasOcclusion, MaterialType, MaterialFlags,
    maxUvChannels, MeshAttributeFlags, noMaterial, referencesTexture, referencesNormalTexture,
    TextureType, TextureMagFilter, TextureMinFilter, TextureWrap;

import model : Primitive, MaterialInfo, ModelData, TextureRef;

enum ushort rgmVersion = 1;

/**
 * Resolve a material's `extras.rg_mat` override against the type that was classified
 * automatically.
 *
 * The override picks the RGM material type by name, which is how a type with no glTF
 * counterpart - `lambert` - gets assigned at all. It cannot conjure up data the glTF
 * material does not have, so an override asking for a type this material cannot supply
 * the payload for is reported and ignored rather than written out as a malformed entry.
 *
 * Params:
 *   material        = the source material, carrying the raw override string.
 *   automaticType   = the type classified from the material's own data.
 *   hasVertexColors = whether the primitives using this material carry vertex colors.
 * Returns: the type to write.
 */
private MaterialType applyMaterialTypeOverride(ref MaterialInfo material,
    MaterialType automaticType, bool hasVertexColors) {
    if (material.materialTypeOverride.length == 0) {
        return automaticType;
    }

    MaterialType requested;
    bool recognized = false;
    static foreach (member; __traits(allMembers, MaterialType)) {
        if (icmp(material.materialTypeOverride, member) == 0) {
            requested = __traits(getMember, MaterialType, member);
            recognized = true;
        }
    }

    if (!recognized) {
        stderr.writefln("Warning: material has an unknown rg_mat value '%s'; " ~
                "keeping the automatically classified %s. Valid values: %s",
            material.materialTypeOverride, automaticType, [__traits(allMembers, MaterialType)]);
        return automaticType;
    }

    if (requested == MaterialType.vertexColors && !hasVertexColors) {
        stderr.writefln("Warning: material asks for rg_mat '%s', but no primitive using it " ~
                "carries vertex colors; keeping %s.", material.materialTypeOverride, automaticType);
        return automaticType;
    }

    return requested;
}

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
 * Resolve one texture slot of a material into a 1-based RGM texture index, appending
 * to the shared texture list when the resolved entry is new.
 *
 * Renaming, prefixing and the filter overrides are all applied before de-duplication,
 * so two slots that end up at the same path and sampler — a base color and a normal
 * map pointing at the same image, or two materials sharing one — collapse onto a
 * single texture entry.
 */
private uint resolveTextureIndex(in TextureRef textureRef, bool renameImages,
    string texturePathPrefix, Nullable!TextureMagFilter magFilterOverride,
    Nullable!TextureMinFilter minFilterOverride, ref OutTexture[] textures,
    ref uint[OutTexture] textureToIndex) {
    string path = renameImages ? setExtension(textureRef.path, "rgi") : textureRef.path;
    if (texturePathPrefix.length > 0) {
        path = buildPath(texturePathPrefix, path);
    }

    TextureMagFilter magFilter = magFilterOverride.isNull
        ? textureRef.magFilter : magFilterOverride.get;
    TextureMinFilter minFilter = minFilterOverride.isNull
        ? textureRef.minFilter : minFilterOverride.get;

    OutTexture texture = OutTexture(path, magFilter, minFilter, textureRef.wrapS, textureRef.wrapT);
    uint* existing = texture in textureToIndex;
    if (existing !is null) {
        return *existing;
    }

    uint textureIndex = cast(uint)(textures.length + 1);
    textureToIndex[texture] = textureIndex;
    textures ~= texture;
    return textureIndex;
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
 *   magFilterOverride = When set, every texture is written with this magnification
 *                       filter instead of the one from its glTF sampler.
 *   minFilterOverride = When set, every texture is written with this minification
 *                       filter instead of the one from its glTF sampler.
 * Throws: Exception if the model exceeds an RGM format limit (too many UV
 *   channels, or a texture path longer than a ushort can address).
 */
ubyte[] encodeRgm(in ModelData data, bool renameImages, string texturePathPrefix,
    bool forceBackfaceCulling = false,
    Nullable!TextureMagFilter magFilterOverride = Nullable!TextureMagFilter.init,
    Nullable!TextureMinFilter minFilterOverride = Nullable!TextureMinFilter.init) {
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

    // Pre-pass: classify every used material and, for textured materials, resolve their
    // texture paths into a shared Textures list. Identical paths are deduplicated, so
    // several materials can reference the same texture by its 1-based index. The
    // classification is recorded here so the material write pass below does not have to
    // re-run it.
    MaterialType[] materialTypes = new MaterialType[materialCount];
    uint[] materialTextureIndices = new uint[materialCount];
    uint[] materialNormalTextureIndices = new uint[materialCount];
    uint[] materialMetallicRoughnessTextureIndices = new uint[materialCount];
    uint[] materialOcclusionTextureIndices = new uint[materialCount];
    OutTexture[] textures; // Texture at position p has the 1-based index (p + 1).
    uint[OutTexture] textureToIndex;
    for (uint i = 0; i < materialCount; i++) {
        if (materialIndexMap[i] == 0) {
            continue;
        }

        MaterialInfo material = data.materials[i];
        bool hasVertexColors = materialHasVertexColors(data.primitives, i);

        MaterialType materialType;
        if (!material.hasAnyTexture && hasVertexColors) {
            // Checked ahead of the base color so a mesh painted with vertex colors keeps
            // being drawn from them rather than being flattened to a single factor.
            materialType = MaterialType.vertexColors;
        } else {
            // The shading model decides the type: only a material that declares
            // KHR_materials_unlit is written as `unlit`; a regular glTF material is a
            // metallic-roughness one. Neither needs a base color texture, since the base
            // color factor colors the material on its own when there is none — so this is
            // also where a plain-colored material lands. `invalid` is left for a material
            // that carries nothing convertible at all.
            materialType = material.unlit
                ? MaterialType.unlit : MaterialType.pbrMetallicRoughness;
        }

        materialType = applyMaterialTypeOverride(material, materialType, hasVertexColors);
        materialTypes[i] = materialType;

        // The albedo reference is optional in the same way the normal map is: a material
        // without one keeps the 0 sentinel and is colored by its base color factor alone,
        // and no texture entry is emitted for it.
        if (materialType.referencesTexture && material.baseColorTexture.path.length > 0) {
            materialTextureIndices[i] = resolveTextureIndex(material.baseColorTexture,
                renameImages, texturePathPrefix, magFilterOverride, minFilterOverride,
                textures, textureToIndex);
        }

        // The normal map is optional where the albedo is not: a material without one
        // keeps the 0 sentinel, and no texture entry is emitted for it.
        if (materialType.referencesNormalTexture && material.normalTexture.path.length > 0) {
            materialNormalTextureIndices[i] = resolveTextureIndex(material.normalTexture,
                renameImages, texturePathPrefix, magFilterOverride, minFilterOverride,
                textures, textureToIndex);
        }

        // Optional in the same way, and kept packed as glTF supplies it: one entry, not a
        // pair of single-channel ones.
        if (materialType.hasMetallicRoughness
            && material.metallicRoughnessTexture.path.length > 0) {
            materialMetallicRoughnessTextureIndices[i] = resolveTextureIndex(
                material.metallicRoughnessTexture, renameImages, texturePathPrefix,
                magFilterOverride, minFilterOverride, textures, textureToIndex);
        }

        // Optional in the same way. Resolved through the same de-duplication as every
        // other slot, which is what makes glTF's packing free: an occlusion map sharing
        // its image with the metallic-roughness one above resolves to that same index
        // rather than a second entry.
        if (materialType.hasOcclusion && material.occlusionTexture.path.length > 0) {
            materialOcclusionTextureIndices[i] = resolveTextureIndex(material.occlusionTexture,
                renameImages, texturePathPrefix, magFilterOverride, minFilterOverride,
                textures, textureToIndex);
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
    // referenced. A textureless material drawn with per-vertex colors maps to
    // `vertexColors`; everything else maps to `unlit` or `pbrMetallicRoughness` depending
    // on its shading model, carrying an albedo texture index that is 0 when it has none.
    // The lit types carry a further texture index for their normal map, likewise 0 when
    // they have none, and the PBR type closes with its metallic-roughness map — 0 again
    // when absent — and the two factors over it.
    // Only an explicit `rg_mat` override still produces the `invalid` sentinel.
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

        if (type.referencesTexture) {
            writeUint(buf, materialTextureIndices[i]); // Referenced albedo texture index (0 = none)

            // Multiplies the albedo texture, and is the material's color outright without one.
            foreach (component; data.materials[i].baseColorFactor) {
                writeFloat(buf, component); // Base color factor (R, G, B, A)
            }
        }

        if (type.referencesNormalTexture) {
            writeUint(buf, materialNormalTextureIndices[i]); // Referenced normal map index (0 = none)

            // Written even without a map, where it goes unused: it keeps the payload a
            // fixed size, and a material that has no map has nothing to scale anyway.
            writeFloat(buf, data.materials[i].normalTextureScale); // Normal map strength
        }

        if (type.hasMetallicRoughness) {
            // Referenced metallic-roughness map index (0 = none), packing roughness in
            // green and metalness in blue.
            writeUint(buf, materialMetallicRoughnessTextureIndices[i]);

            // Written whether or not there is a map: with one they scale it, without one
            // they describe the whole surface.
            writeFloat(buf, data.materials[i].metallicFactor); // Metallic factor
            writeFloat(buf, data.materials[i].roughnessFactor); // Roughness factor
        }

        if (type.hasOcclusion) {
            // Referenced occlusion map index (0 = none), read from its red channel. Equal
            // to the index above where the source packs both into one image.
            writeUint(buf, materialOcclusionTextureIndices[i]);

            // Written without a map for the same reason the normal map's strength is: a
            // fixed-size payload, and nothing to scale where there is no map.
            writeFloat(buf, data.materials[i].occlusionStrength); // Occlusion strength
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

    // The reader already dropped tangents that have no normals or no UV channel to
    // go with them, so array presence is enough to derive the flags.
    ubyte attributeFlags = MeshAttributeFlags.none;
    if (prim.normals.length > 0) {
        attributeFlags |= MeshAttributeFlags.normals;
    }

    if (prim.tangents.length > 0) {
        attributeFlags |= MeshAttributeFlags.tangents;
    }

    // Mesh header
    writeUint(buf, prim.vertexCount);
    writeUint(buf, triangleCount);
    writeUbyte(buf, cast(ubyte) uvChannelCount);
    writeUbyte(buf, attributeFlags);
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

    // Normal data (12 bytes per vertex: x, y, z)
    if ((attributeFlags & MeshAttributeFlags.normals) != 0) {
        for (uint i = 0; i < prim.vertexCount; i++) {
            writeFloat(buf, prim.normals[i * 3 + 0]);
            writeFloat(buf, prim.normals[i * 3 + 1]);
            writeFloat(buf, prim.normals[i * 3 + 2]);
        }
    }

    // Tangent data (16 bytes per vertex: x, y, z, handedness)
    if ((attributeFlags & MeshAttributeFlags.tangents) != 0) {
        for (uint i = 0; i < prim.vertexCount; i++) {
            writeFloat(buf, prim.tangents[i * 4 + 0]);
            writeFloat(buf, prim.tangents[i * 4 + 1]);
            writeFloat(buf, prim.tangents[i * 4 + 2]);
            writeFloat(buf, prim.tangents[i * 4 + 3]);
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
