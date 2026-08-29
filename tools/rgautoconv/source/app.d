module app;

/**
 * rgautoconv - Watch a directory of source assets and keep converted copies up to date.
 *
 * Mirrors an input tree into an output tree, running rgmodelconv and
 * rgimageconv over the files they support. On start-up every asset whose output
 * is missing or older than its source is converted; afterwards the input tree is
 * polled and any asset that changes is converted again.
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
import std.datetime : msecs, SysTime;
import std.file : exists, isDir, mkdirRecurse, thisExePath;
import std.path : dirName;

import core.thread : Thread;

import converters : ConverterRule, converterRules, ConversionResult, resolveTool, runConverter,
    supportedList;
import scanner : AssetFile, isStale, scanAssets, ScanResult;

/// The watchdog settings gathered from the command line.
struct Options {
    string inputDir;
    string outputDir;
    uint intervalMs = 500;
    bool once; /// Convert what is out of date and exit instead of watching.
    bool force; /// Convert everything on start-up, ignoring write times.
    bool verbose;
    string toolsPath; /// Where to look for the conversion tools.
    string[] modelArgs; /// Extra flags forwarded to rgmodelconv.
    string[] imageArgs; /// Extra flags forwarded to rgimageconv.
}

/**
 * What the watchdog last saw of a source file.
 *
 * A file is only converted once its write time and size have stayed put for a
 * full poll, so that an asset still being written out by an exporter is not
 * picked up half finished.
 */
struct WatchEntry {
    SysTime modified;
    ulong size;
    bool converted; /// Whether this exact revision has been handed to a converter.
    string relativePath; /// Kept so a removed file can still be named in a report.
}

/// Tool paths resolved once at start-up, keyed by the tool name from the rules.
alias ToolPaths = string[string];

int main(string[] args) {
    Options options;

    int argsResult = parseArgs(args, options);
    if (argsResult != -1) {
        return argsResult;
    }

    if (!exists(options.inputDir) || !isDir(options.inputDir)) {
        stderr.writefln("Error: input directory '%s' does not exist.", options.inputDir);
        return 1;
    }

    try {
        mkdirRecurse(options.outputDir);
    } catch (Exception e) {
        stderr.writefln("Error: could not create output directory '%s': %s",
            options.outputDir, e.msg);
        return 1;
    }

    ToolPaths tools = resolveTools(options.toolsPath);
    if (tools.length == 0) {
        stderr.writefln("Error: none of the conversion tools were found in '%s' or on PATH.",
            options.toolsPath);
        return 1;
    }

    WatchEntry[string] state;
    uint failures = initialSync(options, tools, state);

    if (options.once) {
        return failures > 0 ? 1 : 0;
    }

    writefln("Watching '%s' -> '%s' every %dms. Press Ctrl+C to stop.",
        options.inputDir, options.outputDir, options.intervalMs);
    watch(options, tools, state);
    return 0;
}

/**
 * Returns:
 *   -1 if parsing succeeded and execution should continue,
 *   0  if the program should exit successfully (e.g. --help was shown),
 *   1  if there was a usage error.
 */
int parseArgs(ref string[] args, out Options options) {
    options = Options.init;

    try {
        auto opts = getopt(args,
            "input|i", "Directory of source assets to watch", &options.inputDir,
            "output|o", "Directory to write converted assets to", &options.outputDir,
            "interval", "Poll interval in milliseconds (default: 500)", &options.intervalMs,
            "once", "Convert what is out of date and exit instead of watching", &options.once,
            "force", "Convert every asset on start-up, ignoring write times", &options.force,
            "tools", "Directory containing the conversion tools (default: next to rgautoconv)",
            &options.toolsPath,
            "model-arg", "Extra argument to pass to rgmodelconv, e.g. --model-arg=--stats (repeatable)",
            &options.modelArgs,
            "image-arg", "Extra argument to pass to rgimageconv, e.g. --image-arg=--mode=indexed (repeatable)",
            &options.imageArgs,
            "verbose|v", "Also report assets that are already up to date", &options.verbose,
        );

        if (opts.helpWanted) {
            defaultGetoptPrinter(
                "rgautoconv - Watch a directory of source assets and keep converted copies up to date.\n\n" ~
                    "Usage: rgautoconv -i <input dir> -o <output dir> [--once]\n\n" ~
                    "Supported source files: " ~ supportedList() ~ ".\n" ~
                    "The input directory structure is mirrored in the output directory.\n" ~
                    "Outputs of assets that are removed from the input directory are left in place.\n",
                    opts.options
            );
            return 0;
        }

        if (options.inputDir.length == 0 || options.outputDir.length == 0) {
            stderr.writeln("Error: Both --input and --output are required.");
            stderr.writeln("Use --help for usage information.");
            return 1;
        }

        if (options.intervalMs == 0) {
            stderr.writeln("Error: --interval must be at least 1 millisecond.");
            return 1;
        }
    } catch (Exception e) {
        stderr.writeln("Error: ", e.msg);
        return 1;
    }

    if (options.toolsPath.length == 0) {
        options.toolsPath = dirName(thisExePath());
    }

    return -1;
}

/**
 * Look up every tool named by the conversion rules.
 *
 * A missing tool is reported but not fatal: the assets it handles are skipped
 * so that, say, an image-only project still works without rgmodelconv around.
 */
ToolPaths resolveTools(string toolsPath) {
    ToolPaths tools;
    foreach (ref rule; converterRules) {
        string path = resolveTool(rule.tool, toolsPath);
        if (path.length > 0) {
            tools[rule.tool] = path;
        } else {
            stderr.writefln("Warning: '%s' not found in '%s' or on PATH; %s files will be skipped.",
                rule.tool, toolsPath, joinExtensions(rule));
        }
    }

    return tools;
}

string joinExtensions(in ConverterRule rule) {
    string result;
    foreach (i, ext; rule.inputExtensions) {
        if (i > 0) {
            result ~= "/";
        }

        result ~= ext;
    }

    return result;
}

/**
 * Bring the output tree up to date and seed the watch state.
 *
 * Every asset seen here is recorded as converted, including ones that failed:
 * retrying a broken asset on every poll would only repeat the same error, so a
 * failed conversion is picked up again when its source next changes.
 *
 * Returns: the number of assets that failed to convert.
 */
uint initialSync(in Options options, in ToolPaths tools, ref WatchEntry[string] state) {
    ScanResult scan = scanAssets(options.inputDir, options.outputDir);
    if (!scan.ok) {
        stderr.writefln("Error: could not read input directory '%s': %s",
            options.inputDir, scan.error);
        return 1;
    }

    uint converted = 0;
    uint upToDate = 0;
    uint skipped = 0;
    uint failed = 0;

    foreach (ref asset; scan.assets) {
        state[asset.inputPath] = WatchEntry(asset.modified, asset.size, true, asset.relativePath);

        if (asset.rule.tool !in tools) {
            skipped++;
            continue;
        }

        if (!options.force && !isStale(asset)) {
            upToDate++;
            if (options.verbose) {
                writefln("Up to date: %s", asset.relativePath);
            }

            continue;
        }

        if (convert(asset, options, tools)) {
            converted++;
        } else {
            failed++;
        }
    }

    writefln("%d converted, %d up to date, %d skipped, %d failed.",
        converted, upToDate, skipped, failed);
    return failed;
}

/**
 * Poll the input tree forever, converting assets as they settle after a change.
 *
 * Assets removed from the input tree simply drop out of the state; their
 * outputs are left alone.
 */
void watch(in Options options, in ToolPaths tools, ref WatchEntry[string] state) {
    while (true) {
        Thread.sleep(options.intervalMs.msecs);

        ScanResult scan = scanAssets(options.inputDir, options.outputDir);
        if (!scan.ok) {
            stderr.writefln("Warning: could not read input directory '%s': %s",
                options.inputDir, scan.error);
            continue;
        }

        WatchEntry[string] next;
        foreach (ref asset; scan.assets) {
            auto previous = asset.inputPath in state;
            bool unchanged = previous !is null
                && previous.modified == asset.modified && previous.size == asset.size;

            if (!unchanged) {
                next[asset.inputPath] = WatchEntry(asset.modified, asset.size, false,
                    asset.relativePath);
                continue;
            }

            if (!previous.converted && asset.rule.tool in tools) {
                cast(void) convert(asset, options, tools);
            }

            next[asset.inputPath] = WatchEntry(asset.modified, asset.size, true,
                asset.relativePath);
        }

        if (options.verbose) {
            foreach (path, ref entry; state) {
                if (path !in next) {
                    writefln("Removed: %s", entry.relativePath);
                }
            }

            stdout.flush();
        }

        state = next;
    }
}

/**
 * Run the conversion for a single asset, creating its output directory first.
 *
 * Returns: true when the tool reported success.
 */
bool convert(in AssetFile asset, in Options options, in ToolPaths tools) {
    try {
        mkdirRecurse(dirName(asset.outputPath));
    } catch (Exception e) {
        stderr.writefln("Error: could not create output directory for '%s': %s",
            asset.relativePath, e.msg);
        return false;
    }

    const(string[]) extraArgs = asset.rule.tool == "rgmodelconv"
        ? options.modelArgs : options.imageArgs;

    ConversionResult result = runConverter(tools[asset.rule.tool], asset.inputPath,
        asset.outputPath, extraArgs);

    if (!result.ok) {
        stderr.writefln("Error converting '%s':", asset.relativePath);
        stderr.write(result.output);
        return false;
    }

    write(result.output);
    stdout.flush();
    return true;
}
