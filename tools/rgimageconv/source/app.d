/**
 * rgimageconv - Convert image files to Retrograde Image (.rgi) format.
 *
 * Reads an input image (BMP for now; structured to support more formats),
 * encodes it as an RGI file in either direct or indexed color mode, and
 * writes the result to disk. In auto mode the smaller encoding is picked.
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
import std.file : exists, isDir, read;
import std.path : baseName, stripExtension, buildPath;

import retrograde.assets.rgi : IndexFormat;

import decoder : decodeImage, supportedList;
import encoders.rgi : encodeRgi, Mode, EncodeOutcome;
import image : channelCount;

int main(string[] args) {
    string inputFile;
    string outputFile;
    string modeStr = "auto";
    bool showStats;

    int argsResult = parseArgs(args, inputFile, outputFile, modeStr, showStats);
    if (argsResult != -1) {
        return argsResult;
    }

    Mode mode;
    if (!parseMode(modeStr, mode)) {
        stderr.writefln("Error: invalid --mode value '%s' (expected direct, indexed, or auto).", modeStr);
        return 1;
    }

    if (!exists(inputFile)) {
        stderr.writefln("Error: input file '%s' does not exist.", inputFile);
        return 1;
    }

    if (exists(outputFile) && isDir(outputFile)) {
        outputFile = buildPath(outputFile, stripExtension(baseName(inputFile)) ~ ".rgi");
    }

    ubyte[] inputBytes;
    try {
        inputBytes = cast(ubyte[]) read(inputFile);
    } catch (Exception e) {
        stderr.writefln("Error: failed to read '%s': %s", inputFile, e.msg);
        return 1;
    }

    auto decodeResult = decodeImage(inputFile, inputBytes);
    if (!decodeResult.ok) {
        stderr.writefln("Error decoding '%s': %s", inputFile, decodeResult.error);
        return 1;
    }

    auto outcome = encodeRgi(decodeResult.image, mode);

    try {
        auto output = File(outputFile, "wb");
        output.rawWrite(outcome.bytes);
    } catch (Exception e) {
        stderr.writefln("Error writing output file '%s': %s", outputFile, e.msg);
        return 1;
    }

    writefln("Converted '%s' -> '%s'", inputFile, outputFile);

    if (showStats) {
        printStats(decodeResult.image.width, decodeResult.image.height,
            channelCount(decodeResult.image.format), mode, outcome);
    }

    return 0;
}

/**
 * Returns:
 *   -1 if parsing succeeded and execution should continue,
 *   0  if the program should exit successfully (e.g. --help was shown),
 *   1  if there was a usage error.
 */
int parseArgs(ref string[] args, out string inputFile, out string outputFile,
    ref string modeStr, out bool showStats) {
    try {
        auto opts = getopt(args,
            "input|i", "Input image file path", &inputFile,
            "output|o", "Output RGI file path (file or directory)", &outputFile,
            "mode|m", "Color mode: direct, indexed, or auto (default: auto)", &modeStr,
            "stats", "Print conversion statistics", &showStats,
        );

        if (opts.helpWanted) {
            defaultGetoptPrinter(
                "rgimageconv - Convert image files to Retrograde Image (.rgi) format.\n\n" ~
                    "Usage: rgimageconv -i <input> -o <output> [--mode <direct|indexed|auto>]\n\n" ~
                    "Supported input formats: " ~ supportedList() ~ ".\n",
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

bool parseMode(string s, out Mode mode) {
    switch (s) {
    case "direct":
        mode = Mode.direct;
        return true;
    case "indexed":
        mode = Mode.indexed;
        return true;
    case "auto":
        mode = Mode.auto_;
        return true;
    default:
        return false;
    }
}

string modeName(Mode m) {
    final switch (m) {
    case Mode.direct:
        return "direct";
    case Mode.indexed:
        return "indexed";
    case Mode.auto_:
        return "auto";
    }
}

string indexFmtName(IndexFormat f) {
    final switch (f) {
    case IndexFormat.u8:
        return "u8";
    case IndexFormat.u16:
        return "u16";
    case IndexFormat.u32:
        return "u32";
    }
}

void printStats(uint width, uint height, ubyte channels, Mode requestedMode, in EncodeOutcome o) {
    writefln("  Dimensions: %d x %d", width, height);
    writefln("  Channels:   %d", channels);
    if (requestedMode == Mode.auto_) {
        writefln("  Mode:       %s (auto)", modeName(o.chosen));
    } else {
        writefln("  Mode:       %s", modeName(o.chosen));
    }
    if (o.indexedComputed) {
        writefln("  Palette:    %d entries (%s indices)", o.paletteEntries, indexFmtName(o.indexFmt));
    }
    if (o.directComputed) {
        writefln("  Direct:     %d bytes", o.directSize);
    }
    if (o.indexedComputed) {
        writefln("  Indexed:    %d bytes", o.indexedSize);
    }
}
