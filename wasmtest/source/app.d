import retrograde.wasm.memory : initializeHeapMemory, printDebugInfo, runWasmMemTests;
import retrograde.std.stdio : writeln;
import retrograde.std.memory : runStdMemoryTests;
import retrograde.std.test : writeSection, runTests;
import retrograde.std.string : runStringTests;

export extern (C) void _start() {
    initializeHeapMemory();

    version (MemoryDebug) {
        printDebugInfo();
    }

    writeSection("Starting tests...");
    runTests();
    writeSection("All tests passed!");
}
