module app;

/**
 * rgmodelconv - Convert 3D model files to Retrograde Model (.rgm) format.
 *
 * Uses Assimp (via derelict-assimp3) to import models in various formats
 * (OBJ, FBX, glTF, COLLADA, etc.) and writes them as Retrograde .rgm
 * binary files.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

import std.stdio;
import std.getopt;
import std.string : toStringz, fromStringz;
import std.bitmanip : nativeToLittleEndian;
import std.file : isDir, exists;
import std.path : baseName, stripExtension, buildPath, setExtension;

import bindbc.assimp;

import retrograde.assets.rgm : rgmMagicNumber;
import retrograde.assets.model : MaterialType, MaterialFlags, maxUvChannels, noMaterial, TextureType;

int main(string[] args) {
    string inputFile;
    string outputFile;
    bool showStats;
    bool noRenameImages;
    string texturePath;

    int argsResult = parseArgs(args, inputFile, outputFile, showStats, noRenameImages, texturePath);
    if (argsResult != -1) {
        return argsResult;
    }

    if (exists(outputFile) && isDir(outputFile)) {
        outputFile = buildPath(outputFile, stripExtension(baseName(inputFile)) ~ ".rgm");
    }

    {
        auto support = loadAssimp();
        if (support == AssimpSupport.noLibrary) {
            stderr.writeln("Error: Failed to load Assimp library.");
            stderr.writeln(
                "Ensure Assimp5.dll (Windows), libassimp.so.5 (Linux), or libassimp.dylib.5 (macOS) is available.");
            return 1;
        }

        if (support == AssimpSupport.badLibrary) {
            stderr.writeln(
                "Warning: Assimp library loaded but one or more symbols are missing. Results may be incorrect.");
        }
    }

    const(aiScene)* scene = aiImportFile(
        inputFile.toStringz(),
        aiPostProcessSteps.Triangulate | aiPostProcessSteps.JoinIdenticalVertices | aiPostProcessSteps
            .SortByPType | aiPostProcessSteps.FlipUVs
    );

    if (scene is null) {
        auto errStr = aiGetErrorString();
        stderr.writefln("Error: Failed to import '%s': %s",
            inputFile, errStr !is null ? fromStringz(errStr) : "Unknown error");
        return 1;
    }

    scope (exit) {
        aiReleaseImport(scene);
    }

    if (scene.mNumMeshes == 0) {
        stderr.writefln("Warning: '%s' contains no meshes.", inputFile);
    }

    try {
        auto output = File(outputFile, "wb");
        writeRgmFile(output, scene, !noRenameImages, texturePath);

        writefln("Converted '%s' -> '%s'", inputFile, outputFile);

        if (showStats) {
            uint totalVertices = 0;
            uint totalFaces = 0;
            uint totalUvChannels = 0;
            uint maxUvChannelsUsed = 0;
            for (uint i = 0; i < scene.mNumMeshes; i++) {
                auto mesh = scene.mMeshes[i];
                totalVertices += mesh.mNumVertices;
                totalFaces += countTriangles(mesh);
                uint uvChannels = countUvChannels(mesh);
                totalUvChannels += uvChannels;
                if (uvChannels > maxUvChannelsUsed) {
                    maxUvChannelsUsed = uvChannels;
                }
            }

            writefln("  Meshes:            %d", scene.mNumMeshes);
            writefln("  Total vertices:    %d", totalVertices);
            writefln("  Total faces:       %d", totalFaces);
            writefln("  Total UV chans:    %d", totalUvChannels);
            writefln("  Max UV chans/mesh: %d", maxUvChannelsUsed);
        }
    } catch (Exception e) {
        stderr.writefln("Error writing output file '%s': %s", outputFile, e.msg);
        return 1;
    }

    return 0;
}

/**
 * Returns:
 *   -1 if parsing succeeded and execution should continue,
 *   0  if the program should exit successfully (e.g. --help was shown),
 *   1  if there was a usage error.
 */
int parseArgs(ref string[] args, out string inputFile, out string outputFile, out bool showStats,
    out bool noRenameImages, out string texturePath) {
    try {
        auto opts = getopt(args,
            "input|i", "Input model file path", &inputFile,
            "output|o", "Output RGM file path", &outputFile,
            "stats", "Print mesh statistics after conversion", &showStats,
            "no-rename-images",
            "Keep original texture image names instead of rewriting their extension to .rgi",
            &noRenameImages,
            "texture-path",
            "Prefix all texture paths with the given path",
            &texturePath,
        );

        if (opts.helpWanted) {
            defaultGetoptPrinter(
                "rgmodelconv - Convert 3D model files to Retrograde Model (.rgm) format.\n\n" ~
                    "Usage: rgmodelconv -i <input> -o <output>\n\n" ~
                    "Supports any format recognized by Assimp (OBJ, FBX, glTF, COLLADA, etc.)\n",
                    opts.options
            );
            return 0;
        }

        if (inputFile.length == 0 || outputFile.length == 0) {
            stderr.writeln("Error: Both --input and --output are required.");
            stderr.writeln("Use --help for usage information.");
            return 1;
        }
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }

    return -1;
}

void writeRgmFile(ref File output, const(aiScene)* scene, bool renameImages, string texturePathPrefix) {
    // Map Assimp material index -> RGM material index. Assimp's glTF2 importer
    // always appends exactly one synthesized default material at the highest
    // index and points materialless primitives at it (see
    // isSyntheticDefaultMaterial). That one slot is treated as "no material":
    // it is never emitted, and meshes referencing it fall through to the
    // `noMaterial` sentinel. Every other material that is actually referenced by
    // a mesh gets a sequential 1-based RGM index assigned in Assimp order.
    uint[] materialIndexMap = new uint[scene.mNumMaterials];
    uint nextRgmIndex = 1;
    for (uint i = 0; i < scene.mNumMeshes; i++) {
        uint mi = scene.mMeshes[i].mMaterialIndex;
        if (mi < scene.mNumMaterials && materialIndexMap[mi] == 0
            && !isSyntheticDefaultMaterial(scene, mi)) {
            materialIndexMap[mi] = nextRgmIndex++;
        }
    }
    uint usedMaterialCount = nextRgmIndex - 1;

    // Pre-pass: classify every used material and, for unlit materials, resolve the
    // texture path into a shared Textures list. Identical paths are deduplicated, so
    // several materials can reference the same texture by its 1-based index. The
    // classification is recorded here so the material write pass below does not have
    // to re-run it.
    MaterialType[] materialTypes = new MaterialType[scene.mNumMaterials];
    uint[] materialTextureIndices = new uint[scene.mNumMaterials];
    string[] texturePaths; // Texture at position p has the 1-based index (p + 1).
    uint[string] texturePathToIndex;
    for (uint i = 0; i < scene.mNumMaterials; i++) {
        if (materialIndexMap[i] == 0) {
            continue;
        }

        string unlitTextureName;
        if (isUnlitMaterial(scene, i, unlitTextureName)) {
            materialTypes[i] = MaterialType.unlit;
            string texturePath = renameImages
                ? setExtension(unlitTextureName, "rgi") : unlitTextureName;
            if (texturePathPrefix.length > 0) {
                texturePath = buildPath(texturePathPrefix, texturePath);
            }
            uint* existing = texturePath in texturePathToIndex;
            if (existing !is null) {
                materialTextureIndices[i] = *existing;
            } else {
                uint textureIndex = cast(uint)(texturePaths.length + 1);
                texturePathToIndex[texturePath] = textureIndex;
                texturePaths ~= texturePath;
                materialTextureIndices[i] = textureIndex;
            }
        } else if (isVertexColorMaterial(scene, i)) {
            materialTypes[i] = MaterialType.vertexColors;
        } else {
            materialTypes[i] = MaterialType.invalid;
        }
    }

    // Header (18 bytes)
    output.rawWrite(rgmMagicNumber); // Magic "RGM "
    writeUshort(output, 1); // Version 1
    writeUint(output, scene.mNumMeshes); // Mesh count
    writeUint(output, usedMaterialCount); // Material count
    writeUint(output, cast(uint) texturePaths.length); // Texture count

    for (uint i = 0; i < scene.mNumMeshes; i++) {
        writeMeshData(output, scene.mMeshes[i], materialIndexMap);
    }

    // Emit one material entry per used Assimp material, in the order they were
    // first referenced. A material maps to `unlit` when it uses the unlit
    // shading model and references an external texture, or to `vertexColors`
    // when it is unlit, textureless and drawn with per-vertex colors; anything
    // we cannot classify falls back to the `invalid` sentinel.
    for (uint i = 0; i < scene.mNumMaterials; i++) {
        if (materialIndexMap[i] == 0) {
            continue;
        }

        const(aiMaterial)* material = scene.mMaterials[i];
        MaterialType type = materialTypes[i];

        writeUint(output, materialIndexMap[i]); // Material index
        writeUbyte(output, cast(ubyte) type); // Material type

        // The `invalid` sentinel carries no common-flags byte and no payload.
        if (type == MaterialType.invalid) {
            continue;
        }

        int twoSided = 0;
        aiReturn twoSidedResult = aiGetMaterialInteger(
            material,
            AI_MATKEY_TWOSIDED[0].toStringz(),
            AI_MATKEY_TWOSIDED[1],
            AI_MATKEY_TWOSIDED[2],
            &twoSided
        );

        bool doubleSided = twoSidedResult == AI_SUCCESS && twoSided != 0;
        ubyte flags = doubleSided ? cast(ubyte) MaterialFlags.doubleSided : 0;
        writeUbyte(output, flags); // Common flags (bit 0 = double-sided)

        if (type == MaterialType.unlit) {
            writeUint(output, materialTextureIndices[i]); // Referenced texture index
        }
    }

    // Emit the Textures list. Every texture produced here is a `reference`: its payload
    // is the (optionally renamed) texture path. The `embedded` texture type is not yet
    // implemented and is never written.
    foreach (idx, texturePath; texturePaths) {
        writeUint(output, cast(uint)(idx + 1)); // Texture index (1-based)
        writeUbyte(output, cast(ubyte) TextureType.reference); // Texture type
        writeString(output, texturePath); // Path payload
    }
}

/**
 * Returns true when the Assimp material should be emitted as
 * `MaterialType.vertexColors`. This requires all of:
 *
 *  - Its shading model is unlit (AI_MATKEY_SHADING_MODEL == aiShadingMode_Unlit,
 *    which Assimp aliases to aiShadingMode_NoShading, 0x9).
 *  - At least one mesh referencing it carries per-vertex colors.
 *  - It references no textures of any type.
 */
bool isVertexColorMaterial(const(aiScene)* scene, uint assimpIndex) {
    const(aiMaterial)* material = scene.mMaterials[assimpIndex];
    return isUnlitShading(material)
        && materialHasVertexColors(scene, assimpIndex)
        && !materialHasTextures(material);
}

/**
 * Returns true when the Assimp material should be emitted as
 * `MaterialType.unlit`: it uses the unlit shading model and references an
 * external texture. Unlike `isVertexColorMaterial`, per-vertex colors are not
 * required. On success, `textureName` is set to that texture's path, which
 * becomes the unlit material's payload.
 *
 * Only referenced textures are supported; embedded textures (which Assimp
 * denotes with a '*'-prefixed path) are ignored, so a material carrying only
 * embedded textures does not classify as unlit.
 */
bool isUnlitMaterial(const(aiScene)* scene, uint assimpIndex, out string textureName) {
    const(aiMaterial)* material = scene.mMaterials[assimpIndex];
    if (!isUnlitShading(material)) {
        return false;
    }

    string name = getReferencedTextureName(material);
    if (name.length == 0) {
        return false;
    }

    textureName = name;
    return true;
}

/**
 * Returns the path of the first externally referenced texture found on the
 * material, or an empty string when it has none. Embedded textures (whose
 * Assimp path begins with '*') are skipped.
 */
string getReferencedTextureName(const(aiMaterial)* material) {
    for (uint t = aiTextureType.NONE; t <= AI_TEXTURE_TYPE_MAX; t++) {
        uint count = aiGetMaterialTextureCount(material, cast(aiTextureType) t);
        for (uint idx = 0; idx < count; idx++) {
            aiString path;
            aiReturn result = aiGetMaterialTexture(
                material, cast(aiTextureType) t, idx, &path,
                null, null, null, null, null, null
            );

            if (result != AI_SUCCESS) {
                continue;
            }

            string name = path.data[0 .. path.length].idup;
            if (name.length > 0 && name[0] != '*') {
                return name;
            }
        }
    }

    return "";
}

/**
 * Returns true if the material's shading model is unlit. Assimp exposes the
 * glTF `KHR_materials_unlit` extension as aiShadingMode_Unlit, which is an alias
 * for aiShadingMode_NoShading (0x9).
 */
bool isUnlitShading(const(aiMaterial)* material) {
    int shadingModel;
    aiReturn result = aiGetMaterialInteger(
        material,
        AI_MATKEY_SHADING_MODEL[0].toStringz(),
        AI_MATKEY_SHADING_MODEL[1],
        AI_MATKEY_SHADING_MODEL[2],
        &shadingModel
    );

    return result == AI_SUCCESS && shadingModel == aiShadingMode.NoShading;
}

/**
 * Returns true if any mesh that references the material at `assimpIndex` carries
 * per-vertex colors (vertex colors are a mesh attribute, not a material one).
 */
bool materialHasVertexColors(const(aiScene)* scene, uint assimpIndex) {
    for (uint i = 0; i < scene.mNumMeshes; i++) {
        const(aiMesh)* mesh = scene.mMeshes[i];
        if (mesh.mMaterialIndex == assimpIndex && mesh.mColors[0]!is null) {
            return true;
        }
    }

    return false;
}

/**
 * Returns true if the material references at least one texture of any type.
 */
bool materialHasTextures(const(aiMaterial)* material) {
    for (uint t = aiTextureType.NONE; t <= AI_TEXTURE_TYPE_MAX; t++) {
        if (aiGetMaterialTextureCount(material, cast(aiTextureType) t) > 0) {
            return true;
        }
    }

    return false;
}

/**
 * Returns true if the material at `index` is the synthetic default that
 * Assimp's glTF2 importer fabricates for primitives that have no material.
 *
 * The importer always appends exactly one such material at the highest index
 * (`mNumMaterials - 1`), regardless of whether any primitive actually needs it,
 * and leaves it nameless. We require BOTH conditions — last slot AND nameless —
 * so that a genuine (if unnamed) material sitting in any other slot is still
 * treated as real and emitted. Real materials from authoring tools (Blender,
 * etc.) carry a name, so this only ever fires on the appended placeholder.
 */
bool isSyntheticDefaultMaterial(const(aiScene)* scene, uint index) {
    return index + 1 == scene.mNumMaterials && !isNamedMaterial(scene.mMaterials[index]);
}

/**
 * Returns true if the Assimp material carries a non-empty name (AI_MATKEY_NAME).
 */
bool isNamedMaterial(const(aiMaterial)* material) {
    aiString name;
    aiReturn result = aiGetMaterialString(
        material,
        AI_MATKEY_NAME[0].toStringz(),
        AI_MATKEY_NAME[1],
        AI_MATKEY_NAME[2],
        &name
    );

    return result == AI_SUCCESS && name.length > 0;
}

void writeMeshData(ref File output, const(aiMesh)* mesh, const uint[] materialIndexMap) {
    uint triangleCount = countTriangles(mesh);
    uint uvChannelCount = countUvChannels(mesh);

    if (uvChannelCount > maxUvChannels) {
        throw new Exception(
            "Mesh has more UV channels than the RGM format supports (max " ~
                maxUvChannels.stringof ~ ").");
    }

    uint materialIndex = mesh.mMaterialIndex < materialIndexMap.length
        ? materialIndexMap[mesh.mMaterialIndex] : noMaterial;

    // Mesh header
    writeUint(output, mesh.mNumVertices);
    writeUint(output, triangleCount);
    writeUbyte(output, cast(ubyte) uvChannelCount);
    writeUint(output, materialIndex);

    bool hasColors = mesh.mColors[0]!is null;

    // Vertex data (24 bytes per vertex: x, y, z, r, g, b)
    for (uint i = 0; i < mesh.mNumVertices; i++) {
        aiVector3D v = mesh.mVertices[i];
        writeFloat(output, v.x);
        writeFloat(output, v.y);
        writeFloat(output, v.z);

        if (hasColors) {
            aiColor4D c = mesh.mColors[0][i];
            writeFloat(output, c.r);
            writeFloat(output, c.g);
            writeFloat(output, c.b);
        } else {
            // Default to white when no vertex colors are present.
            writeFloat(output, 1.0f);
            writeFloat(output, 1.0f);
            writeFloat(output, 1.0f);
        }
    }

    // Face data (12 bytes per face: 3 vertex indices)
    for (uint i = 0; i < mesh.mNumFaces; i++) {
        const(aiFace)* face = &mesh.mFaces[i];
        if (face.mNumIndices != 3)
            continue; // Skip non-triangle primitives.
        writeUint(output, face.mIndices[0]);
        writeUint(output, face.mIndices[1]);
        writeUint(output, face.mIndices[2]);
    }

    // UV channel data (channel-major: all UVs for channel 0, then channel 1, ...)
    for (uint c = 0; c < uvChannelCount; c++) {
        for (uint i = 0; i < mesh.mNumVertices; i++) {
            aiVector3D uv = mesh.mTextureCoords[c][i];
            writeFloat(output, uv.x);
            writeFloat(output, uv.y);
        }
    }
}

uint countUvChannels(const(aiMesh)* mesh) {
    uint count = 0;
    for (uint c = 0; c < AI_MAX_NUMBER_OF_TEXTURECOORDS; c++) {
        if (mesh.mTextureCoords[c] is null) {
            break;
        }

        count++;
    }

    return count;
}

uint countTriangles(const(aiMesh)* mesh) {
    uint count = 0;
    for (uint i = 0; i < mesh.mNumFaces; i++) {
        if (mesh.mFaces[i].mNumIndices == 3) {
            count++;
        }
    }

    return count;
}

void writeUint(ref File output, uint value) {
    ubyte[4] bytes = nativeToLittleEndian(value);
    output.rawWrite(bytes[]);
}

void writeUbyte(ref File output, ubyte value) {
    ubyte[1] bytes = [value];
    output.rawWrite(bytes[]);
}

void writeUshort(ref File output, ushort value) {
    ubyte[2] bytes = nativeToLittleEndian(value);
    output.rawWrite(bytes[]);
}

void writeFloat(ref File output, float value) {
    ubyte[4] bytes = nativeToLittleEndian(value);
    output.rawWrite(bytes[]);
}

/// Writes a length-prefixed string: a ushort byte length followed by the raw
/// UTF-8 bytes (no null terminator).
void writeString(ref File output, string value) {
    if (value.length > ushort.max) {
        throw new Exception(
            "String is too long for the RGM format (max " ~ ushort.max.stringof ~ " bytes).");
    }

    writeUshort(output, cast(ushort) value.length);
    output.rawWrite(cast(const(ubyte)[]) value);
}
