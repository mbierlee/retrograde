/**
 * Retrograde Engine
 *
 * Thanks to Adam D. Ruppe's WASM memory allocator for inspiration and help with LLVM intrinsics:
 * https://github.com/adamdruppe/webassembly/blob/master/arsd-webassembly/core/arsd/memory_allocation.d
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

Result!(void*) malloc(size_t size) {
    assert(false, "not yet implemented");
}

void initializeHeapMemory(size_t _heapOffset = 0) {
    heapOffset = _heapOffset;
    wipeHeap();
    createBlock(heapStart, heapSize() - MemoryBlock.sizeof);
}

void printDebugInfo() {
    import retrograde.std.stdio : writeln;

    writeln("Memory debug info: ");
    writeln("end of data: ");
    writeln(cast(size_t)&__data_end);
    writeln("start of heap base: ");
    writeln(cast(size_t)&__heap_base);
    writeln("start of usable heap: ");
    writeln(cast(size_t) heapStart);
    writeln("memory size: ");
    writeln(llvm_wasm_memory_size(0) * _64KiB);
    writeln("freely usable memory: ");
    writeln(heapSize);
}

private enum _64KiB = 65_536;
private size_t heapOffset = 0;

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
    return llvm_wasm_memory_size(0) * _64KiB - cast(size_t) heapStart;
}

private ubyte* heapStart() {
    return &__heap_base + heapOffset;
}

export extern (C) ubyte* memset(ubyte* ptr, ubyte value, size_t num) {
    foreach (i; 0 .. num) {
        ptr[i] = value;
    }

    return ptr;
}

private align(16) struct MemoryBlock {
    enum BlockHeader = 0x4B4F4C42;

    size_t header = BlockHeader;
    bool isAllocated = false;
    size_t blockSize;
    size_t checksum;

    void setChecksum() {
        checksum = blockSize ^ BlockHeader;
    }

    bool isValidBlock() {
        return header == BlockHeader && checksum == (blockSize ^ BlockHeader);
    }
}

private void wipeHeap() {
    memset(heapStart, 0, heapSize);
}

private void createBlock(void* ptr, size_t blockSize) {
    MemoryBlock* block = cast(MemoryBlock*) ptr;
    *block = MemoryBlock();
    block.blockSize = blockSize;
    block.setChecksum();
}

version (WasmMemTest)  :  //
import retrograde.std.stdio : writeln;

void runMemTests() {
    printDebugInfo();

    writeln("Starting memory tests...");
    writeln("");

    test("Initial heap size is usable", {
        foreach (i; 0 .. heapSize) {
            heapStart[i] = 42;
        }

        foreach (i; 0 .. heapSize) {
            assert(heapStart[i] == 42);
        }
    });

    test("initializeHeapMemory initializes the heap", {
        initializeHeapMemory();

        MemoryBlock* block = cast(MemoryBlock*) heapStart;
        assert(block.header == MemoryBlock.BlockHeader);
        assert(!block.isAllocated);
        assert(block.blockSize == heapSize() - MemoryBlock.sizeof);
        assert(block.checksum == (block.blockSize ^ MemoryBlock.BlockHeader));
        assert(block.isValidBlock());
    });
}

void test(string name, void function() testFunc) {
    writeln(name);
    testFunc();
    writeln("  OK!");
}
