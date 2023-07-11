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

version (UnitTesting)  :  ///

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
        version (WasmMemTest) {
            import retrograde.wasm.memory : runWasmMemTests;

            runWasmMemTests();
        }
    }

    import retrograde.std.memory : runStdMemoryTests;
    import retrograde.std.string : runStringTests;
    import retrograde.std.stringid : runStringIdTests;
    import retrograde.std.option : runOptionTests;
    import retrograde.std.result : runResultTests;
    import retrograde.std.math : runMathTests;
    import retrograde.std.collections : runCollectionsTests;
    import retrograde.std.hash : runHashTests;

    runStdMemoryTests();
    runStringTests();
    runStringIdTests();
    runOptionTests();
    runResultTests();
    runMathTests();
    runCollectionsTests();
    runHashTests();
}

version (unittest) {
    unittest {
        runTests();
    }
}
