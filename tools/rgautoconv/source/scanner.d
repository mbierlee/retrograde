/**
 * rgautoconv - Input directory scanning and staleness checks.
 *
 * Walks the input tree for files rgautoconv knows how to convert and works out
 * where each one lands in the output tree, mirroring the directory structure.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module scanner;

import std.algorithm : sort, startsWith;
import std.datetime : SysTime;
import std.file : DirEntry, dirEntries, exists, isDir, SpanMode, timeLastModified;
import std.path : absolutePath, asNormalizedPath, buildPath, dirSeparator, relativePath,
    setExtension;
import std.conv : to;

import converters : ConverterRule, findRule;

/// A source asset found in the input tree, paired with its destination.
struct AssetFile {
    string inputPath; /// Path as passed to the converter.
    string relativePath; /// Path relative to the input directory, used for logging.
    string outputPath; /// Destination path in the output tree.
    SysTime modified; /// Write time of the source file.
    ulong size; /// Size of the source file, used to spot in-progress writes.
    immutable(ConverterRule)* rule; /// The conversion that applies to this file.
}

/// The outcome of a scan; `error` is only set when the walk itself failed.
struct ScanResult {
    bool ok;
    string error;
    AssetFile[] assets;
}

/**
 * Collect every supported asset under `inputDir`.
 *
 * Anything under `outputDir` is skipped so that an output directory nested in
 * the input tree does not feed converted assets back in. Files that fail to
 * stat are left out rather than aborting the scan: they are typically being
 * written or removed right now and will be picked up by a later poll.
 */
ScanResult scanAssets(string inputDir, string outputDir) {
    AssetFile[] assets;
    string outputPrefix = normalize(outputDir) ~ dirSeparator;

    try {
        foreach (DirEntry entry; dirEntries(inputDir, SpanMode.breadth, false)) {
            if (!entry.isFile) {
                continue;
            }

            auto rule = findRule(entry.name);
            if (rule is null) {
                continue;
            }

            if (normalize(entry.name).startsWith(outputPrefix)) {
                continue;
            }

            string relative = relativePath(absolutePath(entry.name), absolutePath(inputDir));

            try {
                assets ~= AssetFile(
                    entry.name,
                    relative,
                    buildPath(outputDir, setExtension(relative, rule.outputExtension)),
                    entry.timeLastModified,
                    entry.size,
                    rule
                );
            } catch (Exception) {
                continue;
            }
        }
    } catch (Exception e) {
        return ScanResult(false, e.msg, null);
    }

    assets.sort!((a, b) => a.relativePath < b.relativePath);
    return ScanResult(true, "", assets);
}

/**
 * Whether `asset` needs converting: its output is missing, or the source has
 * been written since the output was produced.
 */
bool isStale(in AssetFile asset) {
    if (!exists(asset.outputPath)) {
        return true;
    }

    try {
        return timeLastModified(asset.outputPath) < asset.modified;
    } catch (Exception) {
        return true;
    }
}

/// An absolute, separator-normalized form of `path`, for prefix comparisons.
private string normalize(string path) {
    return absolutePath(path).asNormalizedPath.to!string;
}
