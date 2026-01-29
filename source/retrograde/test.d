module retrograde.test;

version (UnitTesting)  :  ///

import retrograde.std.stdio : writeln;
import retrograde.std.test : testCount;

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
    import retrograde.std.conv : runConvTests;
    import retrograde.engine.entity : runEntityTests;
    import retrograde.std.endian : runEndianTests;
    import retrograde.data.assets.rgm : runRgmTests;

    runStdMemoryTests();
    runStringTests();
    runStringIdTests();
    runOptionTests();
    runResultTests();
    runMathTests();
    runCollectionsTests();
    runHashTests();
    runEntityTests();
    runConvTests();
    runEndianTests();
    runRgmTests();

    writeln();
    writeln("Tests run:");
    writeln(testCount);
}

version (unittest) {
    unittest {
        runTests();
    }
}