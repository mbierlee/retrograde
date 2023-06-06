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

import retrograde.std.result : success, failure, Result, OperationResult;

version (MemoryDebug) {
    import retrograde.std.stdio : writeErrLn;
}

/** 
 * Allocate memory block of size bytes. Returns a pointer to the allocated memory, 
 * or a null pointer if the request fails.
 */
export extern (C) void* malloc(size_t size) {
    auto res = findFreeBlock(size);
    if (res.isSuccessful) {
        auto block = res.value;
        auto splitRes = splitBlock(block, size);
        if (splitRes.isFailure) {
            version (MemoryDebug) {
                writeErrLn(splitRes.errorMessage);
            }

            return null;
        }

        auto allocateRes = allocateBlock(block, size);
        if (allocateRes.isFailure) {
            version (MemoryDebug) {
                writeErrLn(allocateRes.errorMessage);
            }

            return null;
        }

        return cast(void*) block.dataStart;
    } else {
        assert(false, "free block not found: not yet implemented");
    }

    assert(false, "not yet implemented");
}

/** 
 * Sets the num bytes of the block of memory pointed by ptr to the specified value (interpreted as an unsigned char).
 * Returns: ptr as-is.
 */
export extern (C) ubyte* memset(ubyte* ptr, ubyte value, size_t num) {
    foreach (i; 0 .. num) {
        ptr[i] = value;
    }

    return ptr;
}

/**
 * Compares the block of memory pointed by ptr1 to the block of memory pointed by ptr2, returning zero if they are equal
 * or a value different from zero representing which is greater if they are not.
 */
export extern (C) int memcmp(const void* ptr1, const void* ptr2, size_t num) {
    const ubyte* p1 = cast(const ubyte*) ptr1;
    const ubyte* p2 = cast(const ubyte*) ptr2;

    foreach (i; 0 .. num) {
        if (p1[i] != p2[i]) {
            return p1[i] - p2[i];
        }
    }

    return 0;
}

OperationResult initializeHeapMemory(size_t _heapOffset = 0) {
    heapOffset = _heapOffset;
    auto res = maybeGrowInitialHeap();
    if (res.isFailure) {
        return res;
    }

    wipeHeap();
    createBlock(heapStart, heapSize - MemoryBlock.sizeof);
    return success();
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
private enum initialHeapSize = _64KiB;

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

private align(16) struct MemoryBlock {
    enum BlockHeader = 0x4B4F4C42;

    size_t header = BlockHeader;
    bool isAllocated = false;
    size_t blockSize; // In bytes
    size_t usedSize; // In bytes
    size_t checksum;

    void setChecksum() {
        checksum = calculateChecksum();
    }

    bool isValidBlock() {
        return header == BlockHeader && checksum == calculateChecksum();
    }

    ubyte[] blockData() {
        return ((cast(ubyte*)&this) + typeof(this).sizeof)[0 .. blockSize];
    }

    ubyte[] usedData() {
        return blockData[0 .. usedSize];
    }

    ubyte* dataStart() {
        return &blockData[0];
    }

    ubyte* blockDataEnd() {
        return dataStart + blockSize;
    }

    ubyte* usedDataEnd() {
        return dataStart + usedSize;
    }

    private size_t calculateChecksum() {
        return blockSize ^ BlockHeader;
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

private OperationResult maybeGrowInitialHeap() {
    auto wantedTotal = MemoryBlock.sizeof + initialHeapSize;
    auto currentHeapSize = heapSize;
    if (currentHeapSize < wantedTotal) {
        auto res = growHeap(wantedTotal);
        if (res.isFailure) {
            return res;
        }
    }

    return success();
}

private OperationResult growHeap(size_t wantedBytes) {
    auto wantedTotal = wantedBytes + MemoryBlock.sizeof;
    size_t pages = wantedTotal / _64KiB + 1;
    auto res = llvm_wasm_memory_grow(0, pages);
    if (res == -1) {
        return failure("Failed to grow heap");
    }

    return success();
}

private Result!(MemoryBlock*) findFreeBlock(size_t wantedBytes) {
    MemoryBlock* block = cast(MemoryBlock*) heapStart;
    while (block.isValidBlock()) {
        if (!block.isAllocated && block.blockSize >= wantedBytes) {
            return success(block);
        }

        block = cast(MemoryBlock*)(cast(ubyte*) block + block.blockSize + MemoryBlock.sizeof);
    }

    return failure!(MemoryBlock*)("No free block found");
}

private OperationResult splitBlock(MemoryBlock* block, size_t wantedBytes) {
    if (!block.isValidBlock()) {
        return failure("Failed to split block: it is not valid");
    }

    if (wantedBytes > block.blockSize) {
        return failure("Failed to split block: it is too small");
    }

    if (wantedBytes + MemoryBlock.sizeof >= block.blockSize) {
        return success();
    }

    auto newBlockSize = block.blockSize - wantedBytes - MemoryBlock.sizeof;
    createBlock(cast(ubyte*) block + MemoryBlock.sizeof + wantedBytes, newBlockSize);
    block.blockSize = wantedBytes;
    block.setChecksum();
    return success();
}

private OperationResult allocateBlock(MemoryBlock* block, size_t usedBytes) {
    if (!block.isValidBlock()) {
        return failure("Failed to allocate block: it is not valid");
    }

    if (usedBytes > block.blockSize) {
        return failure("Failed to allocate block: it is too small");
    }

    block.isAllocated = true;
    block.usedSize = usedBytes;
    return success();
}

version (WasmMemTest)  :  //
import retrograde.std.stdio : writeln;

void runMemTests() {
    initializeHeapMemory();

    version (MemoryDebug) {
        printDebugInfo();
    }

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
        assert(block.usedSize == 0);
        assert(block.checksum == (block.blockSize ^ MemoryBlock.BlockHeader));
        assert(block.isValidBlock());
    });

    test("initializeHeapMemory with offset initializes the heap at the offset", {
        initializeHeapMemory(10);

        MemoryBlock* block = cast(MemoryBlock*) heapStart;
        assert(block.header == MemoryBlock.BlockHeader);
        assert(!block.isAllocated);
        assert(block.blockSize == heapSize() - MemoryBlock.sizeof);
        assert(block.usedSize == 0);
        assert(block.checksum == (block.blockSize ^ MemoryBlock.BlockHeader));
        assert(block.isValidBlock());
    });

    test("findFreeBlock finds a free block", {
        initializeHeapMemory();
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        assert(res.value.header == MemoryBlock.BlockHeader);
        assert(!res.value.isAllocated);
        assert(res.value.blockSize == heapSize() - MemoryBlock.sizeof);
        assert(res.value.usedSize == 0);
        assert(res.value.checksum == (res.value.blockSize ^ MemoryBlock.BlockHeader));
        assert(res.value.isValidBlock());
    });

    test("splitBlock splits a block to the wanted size", {
        initializeHeapMemory();
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        auto splitRes = splitBlock(block, 5);
        assert(splitRes.isSuccessful);
        assert(block.header == MemoryBlock.BlockHeader);
        assert(!block.isAllocated);
        assert(block.blockSize == 5);
        assert(block.usedSize == 0);
        assert(block.checksum == (block.blockSize ^ MemoryBlock.BlockHeader));
        assert(block.isValidBlock());

        auto nextBlock = cast(MemoryBlock*)(cast(ubyte*) block + block.blockSize + MemoryBlock
            .sizeof);
        assert(nextBlock.header == MemoryBlock.BlockHeader);
        assert(!nextBlock.isAllocated);
        assert(nextBlock.blockSize == heapSize() - MemoryBlock.sizeof - 5 - MemoryBlock.sizeof);
        assert(nextBlock.usedSize == 0);
        assert(nextBlock.checksum == (nextBlock.blockSize ^ MemoryBlock.BlockHeader));
        assert(nextBlock.isValidBlock());
    });

    test("splitBlock does not split a block if it is too small", {
        initializeHeapMemory();
        createBlock(heapStart, 10);
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        auto splitRes = splitBlock(block, 15);
        assert(!splitRes.isSuccessful);
        assert(splitRes.errorMessage == "Failed to split block: it is too small");
        assert(block.header == MemoryBlock.BlockHeader);
        assert(!block.isAllocated);
        assert(block.blockSize == 10);
        assert(block.usedSize == 0);
        assert(block.checksum == (block.blockSize ^ MemoryBlock.BlockHeader));
        assert(block.isValidBlock());
    });

    test("splitBlock does not split a block if it is invalid", {
        initializeHeapMemory();
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        block.header = 0;
        auto splitRes = splitBlock(block, 5);
        assert(!splitRes.isSuccessful);
        assert(splitRes.errorMessage == "Failed to split block: it is not valid");
    });

    test("allocateBlock allocates a block", {
        initializeHeapMemory();
        createBlock(heapStart, 10);
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        auto allocRes = allocateBlock(block, 5);
        assert(allocRes.isSuccessful);
        assert(block.header == MemoryBlock.BlockHeader);
        assert(block.isAllocated);
        assert(block.blockSize == 10);
        assert(block.usedSize == 5);
        assert(block.checksum == (block.blockSize ^ MemoryBlock.BlockHeader));
        assert(block.isValidBlock());
    });

    test("allocateBlock does not allocate a block if it is too small", {
        initializeHeapMemory();
        createBlock(heapStart, 10);
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        auto allocRes = allocateBlock(block, 15);
        assert(!allocRes.isSuccessful);
        assert(allocRes.errorMessage == "Failed to allocate block: it is too small");
        assert(!block.isAllocated);
    });

    test("allocateBlock does not allocate a block if it is invalid", {
        initializeHeapMemory();
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        block.header = 0;
        auto allocRes = allocateBlock(block, 5);
        assert(!allocRes.isSuccessful);
        assert(allocRes.errorMessage == "Failed to allocate block: it is not valid");
        assert(!block.isAllocated);
    });

    test("Access MemoryBlock data and pointers", {
        initializeHeapMemory();
        createBlock(heapStart, 10);
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        auto allocRes = allocateBlock(block, 5);
        assert(allocRes.isSuccessful);

        assert(block.dataStart == cast(ubyte*) block + MemoryBlock.sizeof);
        assert(block.blockDataEnd == cast(ubyte*) block + MemoryBlock.sizeof + 10);
        assert(block.usedDataEnd == cast(ubyte*) block + MemoryBlock.sizeof + 5);

        auto data = cast(ubyte*) block + MemoryBlock.sizeof;
        data[0] = 'H';
        data[1] = 'e';
        data[2] = 'l';
        data[3] = 'l';
        data[4] = 'o';
        assert(block.header == MemoryBlock.BlockHeader);
        assert(block.isValidBlock);
        assert(block.blockData[0] == 'H');
        assert(block.blockData[1] == 'e');
        assert(block.blockData[2] == 'l');
        assert(block.blockData[3] == 'l');
        assert(block.blockData[4] == 'o');
        assert(block.blockData[5] == '\0');
        assert(block.blockData[6] == '\0');
        assert(block.blockData[7] == '\0');
        assert(block.blockData[8] == '\0');
        assert(block.blockData[9] == '\0');
    });

    test("malloc allocates memory when free block is available", {
        initializeHeapMemory();
        createBlock(heapStart, 10);
        auto ptr = malloc(5);
        assert(ptr != null);
        auto block = cast(MemoryBlock*)(cast(ubyte*) ptr - MemoryBlock.sizeof);
        assert(ptr == block.dataStart);
        assert(block.header == MemoryBlock.BlockHeader);
        assert(block.isAllocated);
        assert(block.blockSize == 10);
        assert(block.usedSize == 5);
        assert(block.checksum == (block.blockSize ^ MemoryBlock.BlockHeader));
        assert(block.isValidBlock());
    });
}

void test(string name, void function() testFunc) {
    writeln(name);
    testFunc();
    writeln("  OK!");
}
