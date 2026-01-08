/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.std.debugging;

import retrograde.std.stdio : writeln;

public void breakpoint(string file = __FILE__, int line = __LINE__) {
    breakpoint(true, file, line);
}

public void breakpoint(bool condition, string file = __FILE__, int line = __LINE__) {
    if (condition) {
        writeln("--- BREAKPOINT ---");
        writeln(file);
        writeln(line);
        assert(false);
    }
}

public void breakpoint(T)(T printValue, string file = __FILE__, int line = __LINE__) {
    breakpoint(true, printValue, file, line);
}

public void breakpoint(T)(bool condition, T printValue, string file = __FILE__, int line = __LINE__) {
    if (condition) {
        writeln("--- BREAKPOINT ---");
        writeln(file);
        writeln(line);
        writeln(printValue);
        assert(false);
    }
}
