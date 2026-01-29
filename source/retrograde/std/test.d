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

module retrograde.std.test;

version (UnitTesting)  :  ///

import retrograde.std.stdio : writeln;

uint testCount;

/** 
 * Run a test. 
 *
 * Params:
 *   name = The name of the test.
 *   testFunc = The function to run.
 */
void test(string name, void function() testFunc) {
    version (WasmMemTest) {
        import retrograde.wasm.memory : wipeHeap, initializeHeapMemory;

        wipeHeap();
        initializeHeapMemory();
    }

    writeln(name);
    testFunc();
    writeln("  OK!");
    testCount += 1;
}

/** 
 * Print a section header.
 * Params:
 *   name = The name of the section.
 */
void writeSection(string name) {
    writeln("");
    writeln(name);
    writeln("");
}
