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
        auto extendRes = extendBlockspace(size);
        if (extendRes.isFailure) {
            version (MemoryDebug) {
                writeErrLn(extendRes.errorMessage);
            }

            return null;
        }

        return malloc(size);
    }
}

/** 
 * Sets the num bytes of the block of memory pointed by ptr to the specified value (interpreted as an unsigned byte).
 * Returns: ptr as-is.
 */
export extern (C) void* memset(void* ptr, ubyte value, size_t num) {
    foreach (i; 0 .. num) {
        *(cast(ubyte*)&ptr[i]) = value;
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
    firstFreeBlock = null;
    heapOffset = _heapOffset;

    auto res = maybeGrowInitialHeap();
    if (res.isFailure) {
        return res;
    }

    wipeHeap();
    createBlock(heapStart, heapSize - MemoryBlock.sizeof);
    firstFreeBlock = cast(MemoryBlock*) heapStart;
    return success();
}

void printDebugInfo() {
    import retrograde.std.stdio : writeln;

    writeln("--Memory Debug Info--");
    writeln("End of Static Data: ");
    writeln(cast(size_t)&__data_end);
    writeln("Start of Heap Base: ");
    writeln(cast(size_t)&__heap_base);
    writeln("Start of Usable Heap: ");
    writeln(cast(size_t) heapStart);
    writeln("Memory Size: ");
    writeln(llvm_wasm_memory_size(0) * _64KiB);
    writeln("Freely Usable Memory: ");
    writeln(heapSize);
    writeln("End of Heap: ");
    writeln(cast(size_t) heapEnd);
    writeln("--End of Memory Debug Info--");
}

private enum _64KiB = 65_536;
private enum initialHeapSize = _64KiB;
private size_t heapOffset;
private MemoryBlock* firstFreeBlock;

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

private ubyte* heapEnd() {
    return heapStart + heapSize;
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

    MemoryBlock* nextBlock() {
        return cast(MemoryBlock*) blockDataEnd;
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
    // TODO: Find out if neighbouring blocks can be merged to make room for the requested size.
    //TODO: Replace with Option

    MemoryBlock* block = firstFreeBlock !is null ? firstFreeBlock : cast(MemoryBlock*) heapStart;
    MemoryBlock* previousBlock = null;
    auto endOfHeap = cast(void*) heapEnd;
    while (cast(void*) block < endOfHeap && block.isValidBlock()) {
        // if (!previousBlock.isAllocated) {

        // }

        if (!block.isAllocated && block.blockSize >= wantedBytes) {
            return success(block);
        }

        previousBlock = block;
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

private OperationResult combineBlocks(MemoryBlock* block1, MemoryBlock* block2) {
    if (!block1.isValidBlock()) {
        return failure("Failed to combine blocks: block1 is not valid");
    }

    if (!block2.isValidBlock()) {
        return failure("Failed to combine blocks: block2 is not valid");
    }

    if (block1.isAllocated) {
        return failure("Failed to combine blocks: block1 is allocated");
    }

    if (block2.isAllocated) {
        return failure("Failed to combine blocks: block2 is allocated");
    }

    auto newBlockSize = block1.blockSize + block2.blockSize + MemoryBlock.sizeof;
    createBlock(block1, newBlockSize);
    memset(block1.dataStart, 0, newBlockSize);
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
    if (block is firstFreeBlock) {
        firstFreeBlock = cast(MemoryBlock*)(
            (cast(ubyte*) block) + MemoryBlock.sizeof + block.blockSize
        );
    }

    return success();
}

private OperationResult extendBlockspace(size_t wantedBytes) {
    auto previousEndOfHeap = heapEnd;
    auto res = growHeap(wantedBytes + MemoryBlock.sizeof);
    if (res.isFailure) {
        return res;
    }

    auto newEndOfHeap = heapEnd;
    auto newBlockSize = newEndOfHeap - previousEndOfHeap - MemoryBlock.sizeof;
    createBlock(previousEndOfHeap, newBlockSize);
    firstFreeBlock = cast(MemoryBlock*) previousEndOfHeap;
    return success();
}

version (WasmMemTest)  :  //
import retrograde.std.stdio : writeln;

void runMemTests() {
    initializeHeapMemory();

    version (MemoryDebug) {
        printDebugInfo();
    }

    writeln("");
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
        MemoryBlock* block = cast(MemoryBlock*) heapStart;
        assert(block.header == MemoryBlock.BlockHeader);
        assert(!block.isAllocated);
        assert(block.blockSize == heapSize - MemoryBlock.sizeof);
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
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        assert(res.value.header == MemoryBlock.BlockHeader);
        assert(!res.value.isAllocated);
        assert(res.value.blockSize == heapSize() - MemoryBlock.sizeof);
        assert(res.value.usedSize == 0);
        assert(res.value.checksum == (res.value.blockSize ^ MemoryBlock.BlockHeader));
        assert(res.value.isValidBlock());
    });

    test("findFreeBlock fails when there are no free blocks", {
        createBlock(heapStart, 10);
        allocateBlock(cast(MemoryBlock*) heapStart, 10);
        auto res = findFreeBlock(3);
        assert(res.isFailure);
    });

    // test("findFreeBlock combines adjected blocks that are not allocated", {
    //     splitBlock(cast(MemoryBlock*) heapStart, 5);
    //     auto res = findFreeBlock(10);
    //     assert(res.isSuccessful);
    //     assert(res.value is cast(MemoryBlock*) heapStart);
    // });

    test("combineBlocks combines two unallocated blocks", {
        splitBlock(cast(MemoryBlock*) heapStart, 5);
        auto block1 = cast(MemoryBlock*) heapStart;
        auto block2 = block1.nextBlock;
        assert(block1.isValidBlock());
        assert(block2.isValidBlock());

        auto res = combineBlocks(block1, block2);
        assert(res.isSuccessful);
        assert(block1.isValidBlock());
        assert(!block2.isValidBlock());
    });

    test("combineBlocks fails when one block is not a block", {
        auto validBlock = cast(MemoryBlock*) heapStart;
        auto invalidBlock = cast(MemoryBlock*)(heapStart + 10);
        assert(validBlock.isValidBlock());
        assert(!invalidBlock.isValidBlock());

        auto res = combineBlocks(validBlock, invalidBlock);
        assert(res.isFailure);
        assert(res.errorMessage == "Failed to combine blocks: block2 is not valid");
    });

    test("combineBlocks fails when one block is already allocated", {
        splitBlock(cast(MemoryBlock*) heapStart, 5);
        auto block1 = cast(MemoryBlock*) heapStart;
        auto block2 = block1.nextBlock;
        allocateBlock(block1, 5);
        assert(block1.isValidBlock());
        assert(block2.isValidBlock());

        auto res = combineBlocks(block1, block2);
        assert(res.isFailure);
        assert(res.errorMessage == "Failed to combine blocks: block1 is allocated");
    });

    test("splitBlock splits a block to the wanted size", {
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

        auto nextBlock = block.nextBlock;
        assert(nextBlock.header == MemoryBlock.BlockHeader);
        assert(!nextBlock.isAllocated);
        assert(nextBlock.blockSize == heapSize() - MemoryBlock.sizeof - 5 - MemoryBlock.sizeof);
        assert(nextBlock.usedSize == 0);
        assert(nextBlock.checksum == (nextBlock.blockSize ^ MemoryBlock.BlockHeader));
        assert(nextBlock.isValidBlock());
    });

    test("splitBlock does not split a block if it is too small", {
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
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        block.header = 0;
        auto splitRes = splitBlock(block, 5);
        assert(!splitRes.isSuccessful);
        assert(splitRes.errorMessage == "Failed to split block: it is not valid");
    });

    test("allocateBlock allocates a block", {
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
        createBlock(heapStart, 10);
        auto res = findFreeBlock(10);
        assert(res.isSuccessful);
        auto block = res.value;
        auto allocRes = allocateBlock(block, 5);
        assert(allocRes.isSuccessful);

        assert(block.dataStart is cast(ubyte*) block + MemoryBlock.sizeof);
        assert(block.blockDataEnd is cast(ubyte*) block + MemoryBlock.sizeof + 10);
        assert(block.usedDataEnd is cast(ubyte*) block + MemoryBlock.sizeof + 5);

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

    test("extendBlockspace extends block space", {
        auto firstBlock = cast(MemoryBlock*) heapStart;
        assert(heapEnd is firstBlock.blockDataEnd);
        extendBlockspace(10 + MemoryBlock.sizeof);

        auto secondBlock = firstBlock.nextBlock;
        assert(secondBlock.isValidBlock());
        assert(secondBlock.blockSize == cast(size_t) heapEnd - cast(
            size_t) secondBlock - MemoryBlock.sizeof);
        assert(!secondBlock.isAllocated);
        assert(secondBlock.usedSize == 0);
    });

    test("malloc allocates memory when free block is available", {
        createBlock(heapStart, 10);
        auto ptr = malloc(5);
        assert(ptr !is null);
        auto block = cast(MemoryBlock*)(cast(ubyte*) ptr - MemoryBlock.sizeof);
        assert(ptr is block.dataStart);
        assert(block.header == MemoryBlock.BlockHeader);
        assert(block.isAllocated);
        assert(block.blockSize == 10);
        assert(block.usedSize == 5);
        assert(block.checksum == (block.blockSize ^ MemoryBlock.BlockHeader));
        assert(block.isValidBlock());
    });

    test("malloc extends memory when no free block is available", {
        auto block = cast(MemoryBlock*) heapStart;
        assert(block.isValidBlock());
        allocateBlock(block, block.blockSize);
        auto findRes = findFreeBlock(10);
        assert(!findRes.isSuccessful);

        auto prevHeapEnd = heapEnd;
        auto ptr = malloc(10);
        assert(ptr != null);
        assert(ptr is prevHeapEnd + MemoryBlock.sizeof);
    });

    test("memset sets memory", {
        string str = "Hello World!";
        auto ret = memset(cast(ubyte*) str.ptr, '-', 5);
        assert(ret is cast(ubyte*) str.ptr);
        assert(str == "----- World!");
    });

    test("memcmp compares two sequences of memory", {
        auto ptr1 = malloc(10);
        auto ptr2 = malloc(10);
        assert(ptr1 != null);
        assert(ptr1 != ptr2);

        memset(ptr1, '$', 10);
        memset(ptr2, '$', 10);
        assert(memcmp(ptr1, ptr2, 10) == 0);

        memset(ptr2, '#', 10);
        assert(memcmp(ptr1, ptr2, 10) > 0);

        memset(ptr2, '%', 10);
        assert(memcmp(ptr1, ptr2, 10) < 0);
    });

    writeln("");
    writeln("All tests passed!");
    writeln("");
}

void test(string name, void function() testFunc) {
    initializeHeapMemory();
    writeln(name);
    testFunc();
    writeln("  OK!");
}
