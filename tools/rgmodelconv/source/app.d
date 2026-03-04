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

    int argsResult = parseArgs(args, inputFile, outputFile);
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
            stderr.writeln("Ensure Assimp5.dll (Windows), libassimp.so.5 (Linux), or libassimp.dylib.5 (macOS) is available.");
            return 1;
        }
        if (support == AssimpSupport.badLibrary) {
            stderr.writeln("Warning: Assimp library loaded but one or more symbols are missing. Results may be incorrect.");
        }
    }

    const(aiScene)* scene = aiImportFile(
        inputFile.toStringz(),
        aiPostProcessSteps.Triangulate | aiPostProcessSteps.JoinIdenticalVertices | aiPostProcessSteps.SortByPType
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

        uint totalVertices = 0;
        uint totalFaces = 0;
        for (uint i = 0; i < scene.mNumMeshes; i++) {
            auto mesh = scene.mMeshes[i];
            totalVertices += mesh.mNumVertices;
            totalFaces += countTriangles(mesh);
        }

        writefln("Converted '%s' -> '%s'", inputFile, outputFile);
        writefln("  Meshes:         %d", scene.mNumMeshes);
        writefln("  Total vertices: %d", totalVertices);
        writefln("  Total faces:    %d", totalFaces);
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
int parseArgs(ref string[] args, out string inputFile, out string outputFile) {
    try {
        auto opts = getopt(args,
            "input|i", "Input model file path", &inputFile,
            "output|o", "Output RGM file path", &outputFile,
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

void writeRgmFile(ref File output, const(aiScene)* scene) {
    // Header (10 bytes)
    writeBytes(output, 0x52, 0x47, 0x4D, 0x20); // Magic "RGM "
    writeUshort(output, 1); // Version 1
    writeUint(output, scene.mNumMeshes); // Mesh count

    for (uint i = 0; i < scene.mNumMeshes; i++) {
        writeMeshData(output, scene.mMeshes[i]);
    }
}

void writeMeshData(ref File output, const(aiMesh)* mesh) {
    uint triangleCount = countTriangles(mesh);

    // Mesh header
    writeUint(output, mesh.mNumVertices);
    writeUint(output, triangleCount);

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
}

uint countTriangles(const(aiMesh)* mesh) {
    uint count = 0;
    for (uint i = 0; i < mesh.mNumFaces; i++) {
        if (mesh.mFaces[i].mNumIndices == 3)
            count++;
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

void writeUshort(ref File output, ushort value) {
    ubyte[2] bytes = nativeToLittleEndian(value);
    output.rawWrite(bytes[]);
}

void writeFloat(ref File output, float value) {
    ubyte[4] bytes = nativeToLittleEndian(value);
    output.rawWrite(bytes[]);
}
