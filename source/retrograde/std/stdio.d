module retrograde.std.stdio;

version (WebAssembly) {

    export extern (C) void writeln(string msg);

} else {
    import core.stdc.stdio : printf;

    void writeln(string msg) {
        printf("%s\n", msg.ptr);
    }
}
