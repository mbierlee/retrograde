/**
 * rgautoconv - Converter registry and process invocation.
 *
 * Maps source asset extensions onto the conversion tool that handles them and
 * runs those tools as child processes.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module converters;

import std.algorithm : splitter;
import std.array : join;
import std.file : exists, isFile;
import std.path : buildPath, extension, pathSeparator;
import std.process : environment, execute;
import std.uni : toLower;

/// A rule mapping source file extensions onto the tool that converts them.
struct ConverterRule {
    string tool; /// Executable name, without any platform specific extension.
    string outputExtension; /// Extension of the produced asset, including the dot.
    string[] inputExtensions; /// Lower-case source extensions, including the dot.
}

/**
 * The conversions rgautoconv knows how to perform.
 *
 * The image extensions mirror the decoder registry in
 * tools/rgimageconv/source/decoder.d; a new image format is added there first.
 */
immutable ConverterRule[] converterRules = [
    ConverterRule("rgmodelconv", ".rgm", [".gltf"]),
    ConverterRule("rgimageconv", ".rgi", [".bmp", ".png", ".tga", ".jpg", ".jpeg"]),
];

version (Windows) {
    private enum exeSuffix = ".exe";
} else {
    private enum exeSuffix = "";
}

/**
 * The rule that converts `path`, or null when the file is not a supported asset.
 */
immutable(ConverterRule)* findRule(string path) {
    string ext = extension(path).toLower();
    if (ext.length == 0) {
        return null;
    }

    foreach (ref rule; converterRules) {
        foreach (candidate; rule.inputExtensions) {
            if (candidate == ext) {
                return &rule;
            }
        }
    }

    return null;
}

/// A comma-separated list of every supported source extension, for help text.
string supportedList() {
    string[] extensions;
    foreach (ref rule; converterRules) {
        foreach (ext; rule.inputExtensions) {
            extensions ~= ext;
        }
    }

    return extensions.join(", ");
}

/**
 * Locate the executable for `tool`.
 *
 * `searchPath` is checked before PATH so that a build tree's own tools win over
 * any copy installed system wide. Returns an empty string when the tool is in
 * neither place.
 */
string resolveTool(string tool, string searchPath) {
    string name = tool ~ exeSuffix;
    if (searchPath.length > 0) {
        string candidate = buildPath(searchPath, name);
        if (isExecutableFile(candidate)) {
            return candidate;
        }
    }

    string pathVar = environment.get("PATH", "");
    foreach (dir; pathVar.splitter(pathSeparator)) {
        if (dir.length == 0) {
            continue;
        }

        string candidate = buildPath(dir, name);
        if (isExecutableFile(candidate)) {
            return candidate;
        }
    }

    return "";
}

private bool isExecutableFile(string path) {
    try {
        return exists(path) && isFile(path);
    } catch (Exception) {
        return false;
    }
}

/// The result of running a conversion tool.
struct ConversionResult {
    bool ok;
    string output; /// Combined stdout and stderr of the tool, trailing newline included.
}

/**
 * Run `toolPath` over `inputFile`, writing `outputFile`.
 *
 * `extraArgs` are passed through verbatim, letting the caller forward tool
 * specific flags such as --texture-path.
 */
ConversionResult runConverter(string toolPath, string inputFile, string outputFile,
    const string[] extraArgs) {
    string[] command = [toolPath, "--input", inputFile, "--output", outputFile];
    foreach (arg; extraArgs) {
        command ~= arg;
    }

    try {
        auto result = execute(command);
        return ConversionResult(result.status == 0, result.output);
    } catch (Exception e) {
        return ConversionResult(false, "Failed to run '" ~ toolPath ~ "': " ~ e.msg ~ "\n");
    }
}
