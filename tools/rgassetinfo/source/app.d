module app;

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
import retrograde.data.model : Model, Mesh, Material, MaterialType, noMaterial,
    Texture, TextureType;
import retrograde.data.image : ChannelFormat, bytesPerChannel;

private enum AssetKind {
    unknown,
    rgm,
    rgi,
}

/**
 * Outcome of inspecting a single file, used by directory mode to decide
 * whether to emit a separator and whether to count a failure.
 */
private enum InspectResult {
    printed, /// File info was printed.
    skipped, /// File was silently skipped (--valid-only, non-asset file).
    failed, /// Read or parse failure.
}

int main(string[] args) {
    string inputPath;
    bool validOnly;

    int argsResult = parseArgs(args, inputPath, validOnly);
    if (argsResult != -1) {
        return argsResult;
    }

    if (!exists(inputPath)) {
        stderr.writefln("Error: input path '%s' does not exist.", inputPath);
        return 1;
    }

    if (isDir(inputPath)) {
        return showDirInfo(inputPath, validOnly);
    }

    bool printedAny = false;
    return showFileInfo(inputPath, true, validOnly, printedAny) == InspectResult.failed ? 1 : 0;
}

/**
 * Emit a blank-line separator before an entry, but only once a previous entry
 * has produced output. Flips `printedAny` so the next entry knows to separate.
 */
void emitSeparator(ref bool printedAny) {
    if (printedAny) {
        writeln();
    }

    printedAny = true;
}

/**
 * Inspect a single file. When `requireAssetMagic` is true (single-file mode),
 * an unrecognized magic number is reported as an error. In directory mode it
 * is reported as a one-line notice on stdout so the user still sees the file
 * listed without bailing out the whole scan.
 *
 * When `validOnly` is true, files that are not recognized as Retrograde assets
 * are skipped silently (no output, not counted as a failure) regardless of
 * mode.
 */
InspectResult showFileInfo(string inputFile, bool requireAssetMagic, bool validOnly, ref bool printedAny) {
    ubyte[] data;
    try {
        data = cast(ubyte[]) read(inputFile);
    } catch (Exception e) {
        if (validOnly) {
            return InspectResult.skipped;
        }

        stderr.writefln("Error: failed to read '%s': %s", inputFile, e.msg);
        return InspectResult.failed;
    }

    AssetKind kind = detectAssetKind(data);
    final switch (kind) {
    case AssetKind.rgm:
        return showModelInfo(inputFile, data, printedAny) == 0 ? InspectResult.printed : InspectResult
            .failed;

    case AssetKind.rgi:
        return showImageInfo(inputFile, data, printedAny) == 0 ? InspectResult.printed : InspectResult
            .failed;

    case AssetKind.unknown:
        if (validOnly) {
            return InspectResult.skipped;
        }

        emitSeparator(printedAny);
        writefln("File:           %s", inputFile);
        writeln("Not a Retrograde asset file");
        return requireAssetMagic ? InspectResult.failed : InspectResult.printed;
    }
}

int showDirInfo(string inputDir, bool validOnly) {
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

    // `printedAny` is threaded into each inspection so the blank-line
    // separator is emitted right before an entry's first output line, and
    // only after a previous entry has actually printed. This keeps skipped
    // files (and failures, which write to stderr) from leaving stray gaps.
    int failures = 0;
    bool printedAny = false;
    foreach (file; files) {
        if (showFileInfo(file, false, validOnly, printedAny) == InspectResult.failed) {
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
int parseArgs(ref string[] args, out string inputPath, out bool validOnly) {
    try {
        auto opts = getopt(args,
            "valid-only", "Silently skip files not recognized as Retrograde assets", &validOnly,
        );

        if (opts.helpWanted) {
            defaultGetoptPrinter(
                "rgassetinfo - Display statistics about Retrograde asset files.\n\n" ~
                    "Usage: rgassetinfo <input>\n\n" ~
                    "Supports Retrograde Model (.rgm) and Retrograde Image (.rgi) files.\n" ~
                    "If <input> is a directory, all RGM and RGI files inside it are\n" ~
                    "inspected (non-recursive).\n",
                    opts.options
            );
            return 0;
        }

        // getopt strips recognized options, leaving the program name in
        // args[0] and the positional input path (if any) in args[1].
        if (args.length < 2) {
            stderr.writeln("Error: an input path is required.");
            stderr.writeln("Use --help for usage information.");
            return 1;
        }

        inputPath = args[1];
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }

    return -1;
}

int showModelInfo(string inputFile, const(ubyte)[] data, ref bool printedAny) {
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
    Texture[] textures = model.ptr.textures.arr();

    emitSeparator(printedAny);
    writefln("File:              %s", inputFile);
    writefln("Size on disk:      %d bytes", data.length);
    writefln("Format:            RGM (Retrograde Model)");
    writefln("Version:           %d", header.formatVersion);
    writefln("Meshes:            %d", meshes.length);
    writefln("Materials:         %d", materials.length);
    writefln("Textures:          %d", textures.length);

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
            writefln("  Material %d: index %d, type %s%s%s",
                i, material.index, materialTypeName(material.type),
                materialCommonFlagsDescription(material),
                materialPayloadDescription(material));
        }
    }

    if (textures.length > 0) {
        writeln("Per-texture:");
        foreach (i, ref texture; textures) {
            writefln("  Texture %d: index %d, type %s%s",
                i, texture.index, textureTypeName(texture.type),
                texturePayloadDescription(texture));
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

string materialCommonFlagsDescription(ref Material material) {
    return material.doubleSided ? ", double-sided" : "";
}

string materialPayloadDescription(ref Material material) {
    final switch (material.type) {
    case MaterialType.invalid:
        return "";
    case MaterialType.vertexColors:
        return "";
    case MaterialType.unlit:
        import std.conv : to;

        return ", texture " ~ to!string(material.textureIndex);
    }
}

string textureTypeName(TextureType type) {
    final switch (type) {
    case TextureType.reference:
        return "reference";
    case TextureType.embedded:
        return "embedded";
    }
}

string texturePayloadDescription(ref Texture texture) {
    final switch (texture.type) {
    case TextureType.reference:
        auto path = texture.path[];
        return ", path \"" ~ path.idup ~ "\"";
    case TextureType.embedded:
        return "";
    }
}

int showImageInfo(string inputFile, const(ubyte)[] data, ref bool printedAny) {
    auto headerResult = loadImageHeader(data);
    if (!headerResult.isSuccessful()) {
        stderr.writefln("Error: failed to parse '%s': %s",
            inputFile, errorMessageString(headerResult.errorMessage()));
        return 1;
    }

    ImageHeader header = headerResult.value();

    emitSeparator(printedAny);
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
