/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.std.test;

import retrograde.std.stdio : writeln;

void test(string name, void function() testFunc) {
    version (WasmMemTest) {
        import retrograde.wasm.memory : wipeHeap, initializeHeapMemory;

        wipeHeap();
        initializeHeapMemory();
    }

    writeln(name);
    testFunc();
    writeln("  OK!");
}

void writeSection(string name) {
    writeln("");
    writeln(name);
    writeln("");
}

void runTests() {
    version (WebAssembly) {
        import retrograde.wasm.memory : runWasmMemTests;

        runWasmMemTests();
    }

    import retrograde.std.memory : runStdMemoryTests;
    import retrograde.std.string : runStringTests;

    runStdMemoryTests();
    runStringTests();
}

version (unittest) {
    unittest {
        runTests();
    }
}
