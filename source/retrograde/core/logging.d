/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.logging;

import std.experimental.logger;
import std.stdio;

class StdoutLogger : Logger {

    private File stdoutFile, stderrFile;

    this(LogLevel logLevel = LogLevel.info) {
        super(logLevel);
        stdoutFile = stdout;
        stderrFile = stderr;
    }

    protected override void writeLogMsg(ref LogEntry payload) {
        File* outFile = &stdoutFile;
        if (payload.logLevel == LogLevel.error) {
            outFile = &stderrFile;
        }

        auto logLevelLabel = "";
        switch (payload.logLevel) {
            case LogLevel.warning:
                logLevelLabel = "WARNING: ";
                break;

            case LogLevel.error:
                logLevelLabel = "ERROR: ";
                break;

            case LogLevel.critical:
                logLevelLabel = "CRITICAL: ";
                break;

            case LogLevel.fatal:
                logLevelLabel = "FATAL: ";
                break;

            default:
                break;
        }

        outFile.writeln(logLevelLabel ~ payload.msg);
        outFile.flush();
    }

    public bool stdoutIsAvailable() {
        try {
            stdoutFile.writeln();
            stdoutFile.flush();
            return true;
        } catch (Exception e) {
            return false;
        }
    }
}
