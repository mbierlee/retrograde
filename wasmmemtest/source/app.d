import retrograde.wasm.memory : runMemTests;

export extern (C) void _start() {
    runMemTests();
}
