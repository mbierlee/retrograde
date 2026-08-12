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
import std.array : join;
import std.conv : ConvException, to;
import std.file : exists, isDir;
import std.path : baseName, stripExtension, buildPath;
import std.traits : EnumMembers;
import std.typecons : Nullable;

import retrograde.assets.model : TextureMagFilter, TextureMinFilter;

import reader : readModel;
import writer : encodeRgm;
import model : ModelData;

/// The conversion settings gathered from the command line.
struct Options {
    string inputFile;
    string outputFile;
    bool showStats;
    bool noRenameImages;
    string texturePath;
    bool forceBackfaceCulling;
    Nullable!TextureMagFilter magFilter; /// Null unless --mag-filter was given.
    Nullable!TextureMinFilter minFilter; /// Null unless --min-filter was given.
}

int main(string[] args) {
    Options options;

    int argsResult = parseArgs(args, options);
    if (argsResult != -1) {
        return argsResult;
    }

    if (!exists(options.inputFile)) {
        stderr.writefln("Error: input file '%s' does not exist.", options.inputFile);
        return 1;
    }

    if (exists(options.outputFile) && isDir(options.outputFile)) {
        options.outputFile = buildPath(options.outputFile,
            stripExtension(baseName(options.inputFile)) ~ ".rgm");
    }

    auto readResult = readModel(options.inputFile);
    if (!readResult.ok) {
        stderr.writefln("Error: Failed to import '%s': %s", options.inputFile, readResult.error);
        return 1;
    }

    if (readResult.model.primitives.length == 0) {
        stderr.writefln("Warning: '%s' contains no meshes.", options.inputFile);
    }

    try {
        ubyte[] bytes = encodeRgm(readResult.model, !options.noRenameImages, options.texturePath,
            options.forceBackfaceCulling, options.magFilter, options.minFilter);
        auto output = File(options.outputFile, "wb");
        output.rawWrite(bytes);
    } catch (Exception e) {
        stderr.writefln("Error writing output file '%s': %s", options.outputFile, e.msg);
        return 1;
    }

    writefln("Converted '%s' -> '%s'", options.inputFile, options.outputFile);

    if (options.showStats) {
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
int parseArgs(ref string[] args, out Options options) {
    string magFilter;
    string minFilter;

    try {
        auto opts = getopt(args,
            "input|i", "Input glTF (.gltf) file path", &options.inputFile,
            "output|o", "Output RGM file path", &options.outputFile,
            "stats", "Print mesh statistics after conversion", &options.showStats,
            "no-rename-images",
            "Keep original texture image names instead of rewriting their extension to .rgi",
            &options.noRenameImages,
            "texture-path",
            "Prefix all texture paths with the given path",
            &options.texturePath,
            "force-backface-culling",
            "Write all materials as single-sided, ignoring the source model's double-sided flag",
            &options.forceBackfaceCulling,
            "mag-filter",
            "Write all textures with this magnification filter, ignoring the source model's sampler. One of: " ~
                enumValueList!TextureMagFilter,
            &magFilter,
            "min-filter",
            "Write all textures with this minification filter, ignoring the source model's sampler. One of: " ~
                enumValueList!TextureMinFilter,
            &minFilter,
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

        if (options.inputFile.length == 0 || options.outputFile.length == 0) {
            stderr.writeln("Error: Both --input and --output are required.");
            stderr.writeln("Use --help for usage information.");
            return 1;
        }

        if (!parseEnumOption("mag-filter", magFilter, options.magFilter)) {
            return 1;
        }

        if (!parseEnumOption("min-filter", minFilter, options.minFilter)) {
            return 1;
        }
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }

    return -1;
}

/**
 * Resolve an option whose value names a member of the enum `T`.
 *
 * An empty `value` means the option was not given and leaves `result` null.
 *
 * Returns: true when the option was absent or named a valid member, false on an
 *   unknown name, in which case the accepted values have been reported.
 */
bool parseEnumOption(T)(string optionName, string value, out Nullable!T result) {
    if (value.length == 0) {
        return true;
    }

    try {
        result = value.to!T;
    } catch (ConvException) {
        stderr.writefln("Error: unknown --%s value '%s'. Valid values: %s", optionName, value,
            enumValueList!T);
        return false;
    }

    return true;
}

/// A comma-separated list of every member name of the enum `T`, for help and error text.
template enumValueList(T) {
    enum enumValueList = {
        string[] names;
        static foreach (member; EnumMembers!T) {
            names ~= member.to!string;
        }

        return names.join(", ");
    }();
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
