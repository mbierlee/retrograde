/**
 * rgassetinfo - Display statistics about Retrograde asset files.
 *
 * Inspects a Retrograde Model (.rgm) or Retrograde Image (.rgi) file and
 * prints the same kind of summary the conversion tools emit with --stats.
 * The retrograde engine library is reused for parsing.
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
import std.file : exists, isDir, isFile, read, dirEntries, SpanMode;
import std.algorithm : sort;
import std.array : array;

import retrograde.data.assets.rgm : loadModel, loadModelHeader, ModelHeader, rgmMagicNumber;
import retrograde.data.assets.rgi : loadImageHeader, ImageHeader, rgiMagicNumber,
    CompressionType, ColorMode, IndexFormat, bytesPerIndex;
import retrograde.data.model : Model, Mesh, Material, MaterialType, noMaterial;
import retrograde.data.image : ChannelFormat, bytesPerChannel;

private enum AssetKind {
    unknown,
    rgm,
    rgi,
}

int main(string[] args) {
    string inputPath;

    int argsResult = parseArgs(args, inputPath);
    if (argsResult != -1) {
        return argsResult;
    }

    if (!exists(inputPath)) {
        stderr.writefln("Error: input path '%s' does not exist.", inputPath);
        return 1;
    }

    if (isDir(inputPath)) {
        return showDirInfo(inputPath);
    }

    return showFileInfo(inputPath, true);
}

/**
 * Inspect a single file. When `requireAssetMagic` is true (single-file mode),
 * an unrecognized magic number is reported as an error and the process exits
 * non-zero. In directory mode it is reported as a one-line notice on stdout
 * so the user still sees the file listed without bailing out the whole scan.
 *
 * Returns:
 *   0 on success, or on a recognized non-asset in directory mode,
 *   1 on read or parse failures, or — in single-file mode — when the file
 *     is not a Retrograde asset.
 */
int showFileInfo(string inputFile, bool requireAssetMagic) {
    ubyte[] data;
    try {
        data = cast(ubyte[]) read(inputFile);
    } catch (Exception e) {
        stderr.writefln("Error: failed to read '%s': %s", inputFile, e.msg);
        return 1;
    }

    AssetKind kind = detectAssetKind(data);
    final switch (kind) {
    case AssetKind.rgm:
        return showModelInfo(inputFile, data);

    case AssetKind.rgi:
        return showImageInfo(inputFile, data);

    case AssetKind.unknown:
        writefln("File:           %s", inputFile);
        writeln("Not a Retrograde asset file");
        return requireAssetMagic ? 1 : 0;
    }
}

int showDirInfo(string inputDir) {
    string[] files;
    try {
        foreach (entry; dirEntries(inputDir, SpanMode.shallow)) {
            if (entry.isFile) {
                files ~= entry.name;
            }
        }
    } catch (Exception e) {
        stderr.writefln("Error: failed to scan '%s': %s", inputDir, e.msg);
        return 1;
    }

    // Stable, predictable ordering across filesystems.
    sort(files);

    int failures = 0;
    foreach (i, file; files) {
        if (i > 0) {
            writeln();
        }

        if (showFileInfo(file, false) != 0) {
            failures++;
        }
    }

    return failures == 0 ? 0 : 1;
}

AssetKind detectAssetKind(const(ubyte)[] data) {
    if (data.length < 4) {
        return AssetKind.unknown;
    }

    if (data[0 .. 4] == rgmMagicNumber) {
        return AssetKind.rgm;
    }

    if (data[0 .. 4] == rgiMagicNumber) {
        return AssetKind.rgi;
    }

    return AssetKind.unknown;
}

/**
 * Returns:
 *   -1 if parsing succeeded and execution should continue,
 *   0  if the program should exit successfully (e.g. --help was shown),
 *   1  if there was a usage error.
 */
int parseArgs(ref string[] args, out string inputPath) {
    try {
        auto opts = getopt(args,
            "input|i", "Input RGM or RGI file, or directory to scan", &inputPath,
        );

        if (opts.helpWanted) {
            defaultGetoptPrinter(
                "rgassetinfo - Display statistics about Retrograde asset files.\n\n" ~
                    "Usage: rgassetinfo -i <input>\n\n" ~
                    "Supports Retrograde Model (.rgm) and Retrograde Image (.rgi) files.\n" ~
                    "If <input> is a directory, all RGM and RGI files inside it are\n" ~
                    "inspected (non-recursive).\n",
                    opts.options
            );
            return 0;
        }

        if (inputPath.length == 0) {
            stderr.writeln("Error: --input is required.");
            stderr.writeln("Use --help for usage information.");
            return 1;
        }
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }

    return -1;
}

int showModelInfo(string inputFile, const(ubyte)[] data) {
    auto headerResult = loadModelHeader(data);
    if (!headerResult.isSuccessful()) {
        stderr.writefln("Error: failed to parse '%s': %s",
            inputFile, errorMessageString(headerResult.errorMessage()));
        return 1;
    }

    auto result = loadModel(data);
    if (!result.isSuccessful()) {
        stderr.writefln("Error: failed to parse '%s': %s",
            inputFile, errorMessageString(result.errorMessage()));
        return 1;
    }

    ModelHeader header = headerResult.value();
    auto model = result.unique();

    // Access the model through the raw pointer so we can use `arr()` to take
    // a non-owning D slice over the underlying Mesh storage. Going through
    // UniquePtr's opDispatch or Array's `opIndex` would copy each Mesh by
    // value, which deep-copies vertex/face/UV data we only want to inspect.
    Mesh[] meshes = model.ptr.meshes.arr();
    Material[] materials = model.ptr.materials.arr();

    writefln("File:              %s", inputFile);
    writefln("Size on disk:      %d bytes", data.length);
    writefln("Format:            RGM (Retrograde Model)");
    writefln("Version:           %d", header.formatVersion);
    writefln("Meshes:            %d", meshes.length);
    writefln("Materials:         %d", materials.length);

    size_t totalVertices = 0;
    size_t totalFaces = 0;
    size_t totalUvChannels = 0;
    size_t maxUvChannelsUsed = 0;

    foreach (ref mesh; meshes) {
        totalVertices += mesh.vertices.length;
        totalFaces += mesh.faces.length;
        totalUvChannels += mesh.uvChannelCount;
        if (mesh.uvChannelCount > maxUvChannelsUsed) {
            maxUvChannelsUsed = mesh.uvChannelCount;
        }
    }

    writefln("Total vertices:    %d", totalVertices);
    writefln("Total faces:       %d", totalFaces);
    writefln("Total UV chans:    %d", totalUvChannels);
    writefln("Max UV chans/mesh: %d", maxUvChannelsUsed);

    if (meshes.length > 0) {
        writeln("Per-mesh:");
        foreach (i, ref mesh; meshes) {
            writefln("  Mesh %d: %d vertices, %d faces, %d UV channels, material %s",
                i, mesh.vertices.length, mesh.faces.length, mesh.uvChannelCount,
                materialReferenceLabel(mesh.materialIndex)
            );
        }
    }

    if (materials.length > 0) {
        writeln("Per-material:");
        foreach (i, ref material; materials) {
            writefln("  Material %d: index %d, type %s%s",
                i, material.index, materialTypeName(material.type),
                materialPayloadDescription(material));
        }
    }

    return 0;
}

string materialTypeName(MaterialType type) {
    final switch (type) {
    case MaterialType.invalid:
        return "Invalid";
    case MaterialType.vertexColors:
        return "Vertex Colors";
    case MaterialType.unlit:
        return "Unlit";
    }
}

string materialReferenceLabel(uint materialIndex) {
    import std.conv : to;

    if (materialIndex == noMaterial) {
        return "none";
    }

    return to!string(materialIndex);
}

string materialPayloadDescription(ref Material material) {
    final switch (material.type) {
    case MaterialType.invalid:
        return "";
    case MaterialType.vertexColors:
        return "";
    case MaterialType.unlit:
        auto name = material.textureName[];
        return ", texture \"" ~ name.idup ~ "\"";
    }
}

int showImageInfo(string inputFile, const(ubyte)[] data) {
    auto headerResult = loadImageHeader(data);
    if (!headerResult.isSuccessful()) {
        stderr.writefln("Error: failed to parse '%s': %s",
            inputFile, errorMessageString(headerResult.errorMessage()));
        return 1;
    }

    ImageHeader header = headerResult.value();

    writefln("File:           %s", inputFile);
    writefln("Size on disk:   %d bytes", data.length);
    writefln("Format:         RGI (Retrograde Image)");
    writefln("Version:        %d", header.formatVersion);
    writefln("Compression:    %s", compressionName(header.compression));
    writefln("Dimensions:     %d x %d", header.width, header.height);
    writefln("Channels:       %d (%s)", header.channelCount, channelMeaning(header.channelCount));
    writefln("Channel format: %s (%d bytes/channel)",
        channelFormatName(header.channelFormat), bytesPerChannel(header.channelFormat));

    final switch (header.colorMode) {
    case ColorMode.direct:
        writeln("Color mode:     direct");
        break;
    case ColorMode.indexed:
        writeln("Color mode:     indexed");
        writefln("Index format:   %s (%d bytes/index)",
            indexFormatName(header.indexFormat), bytesPerIndex(header.indexFormat));
        writefln("Palette:        %d entries", header.paletteEntryCount);
        break;
    }

    size_t expandedBytes = cast(size_t) header.width
        * cast(size_t) header.height
        * cast(
            size_t) header.channelCount
        * bytesPerChannel(header.channelFormat);
    writefln("Expanded pixel data: %d bytes", expandedBytes);

    return 0;
}

string compressionName(CompressionType c) {
    final switch (c) {
    case CompressionType.none:
        return "none";
    }
}

string channelMeaning(ubyte count) {
    switch (count) {
    case 1:
        return "grayscale";
    case 2:
        return "grayscale + alpha";
    case 3:
        return "RGB";
    case 4:
        return "RGBA";
    default:
        return "unknown";
    }
}

string channelFormatName(ChannelFormat fmt) {
    final switch (fmt) {
    case ChannelFormat.u8:
        return "u8";
    case ChannelFormat.u16:
        return "u16";
    case ChannelFormat.u32:
        return "u32";
    }
}

string indexFormatName(IndexFormat fmt) {
    final switch (fmt) {
    case IndexFormat.u8:
        return "u8";
    case IndexFormat.u16:
        return "u16";
    case IndexFormat.u32:
        return "u32";
    }
}

/**
 * Copy the engine's `String` error message into a GC-allocated D string so it
 * can be passed safely to Phobos formatting routines. The temporary `String`
 * returned by `errorMessage()` would otherwise free its buffer at the end of
 * the full expression.
 */
string errorMessageString(S)(auto ref S msg) {
    auto slice = msg[];
    return slice.idup;
}
