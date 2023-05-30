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

module retrograde.wasm.memory;

version (WebAssembly)  :  //

import retrograde.std.result : success, failure, Result;

private enum _64KiB = 65_536;

/**
 * @param mem Index of the WASM Memory object to grow.
 * @param delta Number of pages to grow memory by. Each page is 65536 bytes (64KiB).
 * @return Previous memory size in pages or -1 on failure.
 */
pragma(LDC_intrinsic, "llvm.wasm.memory.grow.i32")
private int llvm_wasm_memory_grow(int mem, int delta);

/// Returns currently allocated memory pages. Each page is 65536 bytes (64KiB).
pragma(LDC_intrinsic, "llvm.wasm.memory.size.i32")
private int llvm_wasm_memory_size(int mem);

// End of static data. Take an address of it (&__data_end) to get the actual address.
private extern (C) ubyte __data_end;

// Start of heap. Take an address of it (&__heap_base) to get the actual address.
private extern (C) ubyte __heap_base;

private size_t heapSize() {
    return llvm_wasm_memory_size(0) * _64KiB - cast(size_t)&__heap_base;
}

private ubyte* heapStart() {
    return &__heap_base;
}

export extern (C) ubyte* memset(ubyte* ptr, ubyte value, size_t num) {
    foreach (i; 0 .. num) {
        ptr[i] = value;
    }

    return ptr;
}

// Result!(void*) malloc(size_t size) {

// }

version (WasmMemTest)  :  //
import retrograde.std.stdio : writeln;

void runMemTests() {
    writeln("end of data: ");
    writeln(cast(size_t)&__data_end);
    writeln("start of heap: ");
    writeln(cast(size_t)&__heap_base);
    writeln("memory size: ");
    writeln(llvm_wasm_memory_size(0) * _64KiB);
    writeln("freely usable memory: ");
    writeln(heapSize);

    writeln("Starting memory tests...");
    testInitialHeapSizeIsUsable();
}

void test(string name, void function() testFunc) {
    writeln(name);
    testFunc();
    writeln("  OK");
}

void testInitialHeapSizeIsUsable() {
    test("Initial heap size is usable", {
        foreach (i; 0 .. heapSize) {
            heapStart[i] = 42;
        }

        foreach (i; 0 .. heapSize) {
            assert(heapStart[i] == 42);
        }
    });
}
