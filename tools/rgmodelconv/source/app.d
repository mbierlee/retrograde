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
import std.path : baseName, stripExtension, buildPath;

import bindbc.assimp;

int main(string[] args) {
    string inputFile;
    string outputFile;
    bool showStats;

    int argsResult = parseArgs(args, inputFile, outputFile, showStats);
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
            .SortByPType
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
        writeRgmFile(output, scene);

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
int parseArgs(ref string[] args, out string inputFile, out string outputFile, out bool showStats) {
    try {
        auto opts = getopt(args,
            "input|i", "Input model file path", &inputFile,
            "output|o", "Output RGM file path", &outputFile,
            "stats", "Print mesh statistics after conversion", &showStats,
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

enum materialTypeVertexColors = 1;
enum noMaterialIndex = 0;

void writeRgmFile(ref File output, const(aiScene)* scene) {
    // Map Assimp material index -> RGM material index. Unused Assimp materials
    // (e.g. the synthetic default the glTF2 importer always appends) map to 0
    // and are not emitted. Used materials get sequential 1-based RGM indices
    // assigned in Assimp order.
    uint[] materialIndexMap = new uint[scene.mNumMaterials];
    uint nextRgmIndex = 1;
    for (uint i = 0; i < scene.mNumMeshes; i++) {
        uint mi = scene.mMeshes[i].mMaterialIndex;
        if (mi < scene.mNumMaterials && materialIndexMap[mi] == 0) {
            materialIndexMap[mi] = nextRgmIndex++;
        }
    }
    uint usedMaterialCount = nextRgmIndex - 1;

    // Header (14 bytes)
    writeBytes(output, 0x52, 0x47, 0x4D, 0x20); // Magic "RGM "
    writeUshort(output, 1); // Version 1
    writeUint(output, scene.mNumMeshes); // Mesh count
    writeUint(output, usedMaterialCount); // Material count

    for (uint i = 0; i < scene.mNumMeshes; i++) {
        writeMeshData(output, scene.mMeshes[i], materialIndexMap);
    }

    // Emit one vertex-colors material per used Assimp material, in the order
    // they were first referenced.
    for (uint i = 0; i < scene.mNumMaterials; i++) {
        if (materialIndexMap[i] != 0) {
            writeUint(output, materialIndexMap[i]);
            writeUbyte(output, materialTypeVertexColors);
        }
    }
}

enum maxUvChannels = 8;

void writeMeshData(ref File output, const(aiMesh)* mesh, const uint[] materialIndexMap) {
    uint triangleCount = countTriangles(mesh);
    uint uvChannelCount = countUvChannels(mesh);

    if (uvChannelCount > maxUvChannels) {
        throw new Exception(
            "Mesh has more UV channels than the RGM format supports (max " ~
                maxUvChannels.stringof ~ ").");
    }

    uint materialIndex = mesh.mMaterialIndex < materialIndexMap.length
        ? materialIndexMap[mesh.mMaterialIndex] : noMaterialIndex;

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

void writeBytes(ref File output, ubyte[] bytes...) {
    output.rawWrite(bytes);
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
