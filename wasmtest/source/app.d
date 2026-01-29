import retrograde.wasm.memory : initializeHeapMemory, printDebugInfo;
import retrograde.std.stdio : writeln;
import retrograde.std.test : writeSection;
import retrograde.test : runTests;

export extern (C) void _start() {
    initializeHeapMemory();

    version (MemoryDebug) {
        printDebugInfo();
    }

    writeSection("Starting tests...");
    runTests();
    writeSection("All tests passed!");
}
