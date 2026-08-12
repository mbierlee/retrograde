/**
 * rgmodelconv - Convert 3D model files to Retrograde Model (.rgm) format.
 *
 * Reads a glTF 2.0 model (`.gltf` text file with an external `.bin` buffer and
 * external image files) and writes it as a Retrograde `.rgm` binary file. Binary
 * `.glb` containers and embedded buffers/images are not supported.
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
import std.file : exists, isDir;
import std.path : baseName, stripExtension, buildPath;

import reader : readModel;
import writer : encodeRgm;
import model : ModelData;

int main(string[] args) {
    string inputFile;
    string outputFile;
    bool showStats;
    bool noRenameImages;
    string texturePath;
    bool forceBackfaceCulling;

    int argsResult = parseArgs(args, inputFile, outputFile, showStats, noRenameImages, texturePath,
        forceBackfaceCulling);
    if (argsResult != -1) {
        return argsResult;
    }

    if (!exists(inputFile)) {
        stderr.writefln("Error: input file '%s' does not exist.", inputFile);
        return 1;
    }

    if (exists(outputFile) && isDir(outputFile)) {
        outputFile = buildPath(outputFile, stripExtension(baseName(inputFile)) ~ ".rgm");
    }

    auto readResult = readModel(inputFile);
    if (!readResult.ok) {
        stderr.writefln("Error: Failed to import '%s': %s", inputFile, readResult.error);
        return 1;
    }

    if (readResult.model.primitives.length == 0) {
        stderr.writefln("Warning: '%s' contains no meshes.", inputFile);
    }

    try {
        ubyte[] bytes = encodeRgm(readResult.model, !noRenameImages, texturePath, forceBackfaceCulling);
        auto output = File(outputFile, "wb");
        output.rawWrite(bytes);
    } catch (Exception e) {
        stderr.writefln("Error writing output file '%s': %s", outputFile, e.msg);
        return 1;
    }

    writefln("Converted '%s' -> '%s'", inputFile, outputFile);

    if (showStats) {
        printStats(readResult.model);
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
    out bool noRenameImages, out string texturePath, out bool forceBackfaceCulling) {
    try {
        auto opts = getopt(args,
            "input|i", "Input glTF (.gltf) file path", &inputFile,
            "output|o", "Output RGM file path", &outputFile,
            "stats", "Print mesh statistics after conversion", &showStats,
            "no-rename-images",
            "Keep original texture image names instead of rewriting their extension to .rgi",
            &noRenameImages,
            "texture-path",
            "Prefix all texture paths with the given path",
            &texturePath,
            "force-backface-culling",
            "Write all materials as single-sided, ignoring the source model's double-sided flag",
            &forceBackfaceCulling,
        );

        if (opts.helpWanted) {
            defaultGetoptPrinter(
                "rgmodelconv - Convert 3D model files to Retrograde Model (.rgm) format.\n\n" ~
                    "Usage: rgmodelconv -i <input> -o <output>\n\n" ~
                    "Supports glTF 2.0 (.gltf) with an external .bin buffer and external images.\n" ~
                    "Binary .glb containers are not supported.\n",
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

void printStats(in ModelData model) {
    uint totalVertices = 0;
    uint totalFaces = 0;
    uint totalUvChannels = 0;
    uint maxUvChannelsUsed = 0;
    foreach (ref prim; model.primitives) {
        totalVertices += prim.vertexCount;
        totalFaces += cast(uint)(prim.indices.length / 3);
        uint uvChannels = cast(uint) prim.uvChannels.length;
        totalUvChannels += uvChannels;
        if (uvChannels > maxUvChannelsUsed) {
            maxUvChannelsUsed = uvChannels;
        }
    }

    writefln("  Meshes:            %d", model.primitives.length);
    writefln("  Total vertices:    %d", totalVertices);
    writefln("  Total faces:       %d", totalFaces);
    writefln("  Total UV chans:    %d", totalUvChannels);
    writefln("  Max UV chans/mesh: %d", maxUvChannelsUsed);
}
