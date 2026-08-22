/**
 * Retrograde Engine
 *
 * WASM heap allocator: size-class pages with an out-of-band page map.
 *
 * The heap is carved into 4 KiB logical pages. Small allocations (<= 2048 bytes)
 * are rounded up to a size class and served as fixed-size slots from pages
 * dedicated to that class; larger allocations take a contiguous run of whole
 * pages. All allocator metadata lives in a flat page map stored in reserved
 * metadata pages — no header precedes any allocation.
 *
 * Behavioural notes (changes from the former inline-block allocator):
 * - Freed memory is no longer inert: free() writes an intrusive free-list link
 *   into the first two bytes of a freed slot. Reading freed memory was always
 *   undefined behaviour; it is now also visibly destructive.
 * - memmove() through a freed heap pointer is rejected (returns null) instead
 *   of silently copying through stale metadata.
 * - Bounds checks in release builds are class-granular (the slot capacity, not
 *   the requested byte count). Under MemoryDebug a requested-size shadow
 *   restores byte-exact bounds.
 * - Returned pointers are guaranteed at least 8-byte aligned.
 *
 * Thanks to Adam D. Ruppe's WASM memory allocator for help with LLVM intrinsics:
 * https://github.com/adamdruppe/webassembly/blob/master/arsd-webassembly/core/arsd/memory_allocation.d
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.wasm.memory;

version (WebAssembly)  :  //

import retrograde.std.result : success, failure, OperationResult;
import retrograde.std.stdio : writeln, writeErrLn;

version (LDC) {
    // https://github.com/ldc-developers/druntime/blob/ldc/src/ldc/intrinsics.di
    import ldc.intrinsics : llvm_wasm_memory_grow, llvm_wasm_memory_size, llvm_trap;
    import ldc.attributes : optStrategy;
}

private enum _64KiB = 65_536;
private enum initialHeapSize = _64KiB;
private enum size_t PageSize = 4096;
private enum uint PageShift = 12;
private enum uint PagesPerWasmPage = _64KiB / PageSize;

// Sentinels. Page indices span at most 2^20 values (wasm32 4 GiB / 4 KiB, and
// pagesBase > 0 keeps numPages strictly below that), so uint.max is unambiguous.
private enum uint NoPage = uint.max;
private enum ushort NoSlot = ushort.max;

// Bitmap cell ids occupy 26 bits (20-bit page index << 6 | 6-bit cell index),
// leaving bit 31 free for the bumpZeroed flag. The "no cell" sentinel is the
// 26-bit all-ones value and must always be compared against the masked field:
// (slotState & CellIdMask) == NoCell. Never compare slotState as a whole word.
private enum uint CellIdMask = 0x03FF_FFFF;
private enum uint NoCell = CellIdMask;
private enum uint BumpZeroedBit = 1u << 31;

// Generic cell-pool failure/none value (full-width, unlike the 26-bit NoCell).
private enum uint NoCellId = uint.max;

private enum PageKind : ubyte {
    freeRun, // first page of a run of free pages
    freeCont, // continuation of a free run; the *last* page of a run mirrors the run length
    smallPage, // holds slots of one size class
    largeStart, // first page of a large allocation
    largeCont, // continuation page of a large allocation
    metadata // page map or cell-pool page
}

// Stored in PageEntry.sizeClass when kind == metadata.
private enum MetaKind : ubyte {
    pageMap,
    cellPool,
    shadowPool // MemoryDebug requested-size shadow cells; unused in release builds
}

/*
 * One entry per 4 KiB logical page. Field order is load-bearing: the ushorts
 * ahead of the uints and the flag folded into slotState's bit 31 are what make
 * the struct exactly 20 bytes (24 under MemoryDebug); a union-first spelling
 * pads to 28.
 *
 * Every kind has a defined interpretation for every field:
 * - freeRun:    runLength = pages in the run; next/prev thread the free-run
 *               list; other fields unused (zeroed).
 * - freeCont:   runLength mirrors the run length on the run's *last* page only;
 *               stale on interior pages (never read there); rest unused.
 * - smallPage:  sizeClass indexes the class table; usedSlots/freeHead/bumpIndex
 *               track slots; next/prev thread the class's partial-page list;
 *               slotState = bitmap cell id (bits 0..25) | bumpZeroed (bit 31).
 * - largeStart: runLength = pages in the run; other fields unused (zeroed).
 * - largeCont:  runStart = page index of the run's largeStart page; rest unused.
 * - metadata:   sizeClass = MetaKind. For pageMap pages all other fields are
 *               unused. For cellPool/shadowPool pages usedSlots/freeHead/
 *               bumpIndex track cells exactly like a small page's slots and
 *               next/prev thread the has-free-cells pool list.
 *
 * Under MemoryDebug, debugInfo holds: smallPage = shadow cell id (NoCellId if
 * unset); largeStart = exact requested size in bytes; others unused.
 */
private struct PageEntry {
    PageKind kind;
    ubyte sizeClass;
    ushort usedSlots;
    ushort freeHead;
    ushort bumpIndex;
    uint next;
    uint prev;
    union {
        uint slotState;
        uint runLength;
        uint runStart;
    }

    version (MemoryDebug) {
        uint debugInfo;
    }
}

version (MemoryDebug) {
    static assert(PageEntry.sizeof == 24);
} else {
    static assert(PageEntry.sizeof == 20);
}

// Entries per map page; the map is indexed flat over its contiguous region, so
// this is a (safe) lower bound on what the region physically holds. Never
// hardcode 204/170 — always derive from PageEntry.sizeof.
private enum uint entriesPerMapPage = cast(uint)(PageSize / PageEntry.sizeof);

// Size classes: ~8-byte granularity at the bottom, ~25% geometric growth above,
// capped at MaxSmallSize. All multiples of 8 => every returned pointer is at
// least 8-aligned.
private static immutable ushort[26] classSizes = [
    8, 16, 24, 32, 48, 64, 80, 96, 112, 128, 160, 192, 224, 256,
    320, 384, 448, 512, 640, 768, 896, 1024, 1280, 1536, 1792, 2048
];
private enum uint NumSizeClasses = cast(uint) classSizes.length;
private enum size_t MaxSmallSize = classSizes[NumSizeClasses - 1];

// sizeToClass lookup: index (size + 7) >> 3 covers 1..2048 in 257 entries.
private ubyte[257] buildSizeToClassTable() {
    ubyte[257] table;
    foreach (i; 1 .. 257) {
        size_t coveredSize = i * 8;
        ubyte cls = 0;
        while (classSizes[cls] < coveredSize) {
            cls++;
        }

        table[i] = cls;
    }

    table[0] = 0;
    return table;
}

private static immutable ubyte[257] sizeToClassTable = buildSizeToClassTable();

private ubyte sizeToClass(size_t size) {
    return sizeToClassTable[(size + 7) >> 3];
}

// CTFE proof that the table and the class array agree: for every size 1..2048
// the mapped class covers the size and the next-smaller class does not.
private bool validateSizeToClassTable() {
    for (size_t size = 1; size <= MaxSmallSize; size++) {
        auto cls = sizeToClassTable[(size + 7) >> 3];
        if (classSizes[cls] < size) {
            return false;
        }

        if (cls > 0 && classSizes[cls - 1] >= size) {
            return false;
        }
    }

    return true;
}

static assert(validateSizeToClassTable());

// Division/modulo by a class size must not be a runtime division by a
// non-constant: the switch gives LLVM compile-time divisors per case, which it
// lowers to multiply-shift sequences. Cannot be final switch (sizeClass is a
// raw ubyte; final switch would demand all 256 cases); the default treats an
// unknown class as a broken internal invariant.
private uint slotsPerPage(ubyte sizeClass) {
    switch (sizeClass) {
        static foreach (i; 0 .. NumSizeClasses) {
    case cast(ubyte) i:
            return cast(uint)(PageSize / classSizes[i]);
        }
    default:
        trapInternal("slotsPerPage: unknown size class");
        return 0;
    }
}

// Slot index of a page offset; returns false if the offset is not an exact
// slot start (interior or bogus pointer).
private bool slotFromOffset(ubyte sizeClass, size_t pageOffset, out uint slot) {
    switch (sizeClass) {
        static foreach (i; 0 .. NumSizeClasses) {
    case cast(ubyte) i:
            slot = cast(uint)(pageOffset / classSizes[i]);
            return (pageOffset % classSizes[i]) == 0;
        }
    default:
        trapInternal("slotFromOffset: unknown size class");
        return false;
    }
}

/*
 * Global allocator state. Declared __gshared: D module globals are
 * thread-local by default, and the non-zero initializers these need (= NoPage)
 * would land in a .tdata segment whose TLS setup a betterC WASM module never
 * performs. initializeHeapMemory assigns every one of them explicitly instead
 * of relying on declaration-site initializers.
 */
private __gshared uint[NumSizeClasses] partialPages; // first page with free slots per class
private __gshared uint firstFreeRun; // head of the free-run list
private __gshared uint firstCellPoolPage; // head of the bitmap-cell pool pages with free cells
private __gshared uint numPages; // pages currently covered by the map
private __gshared uint mapCapacity; // entries the current map region can hold
private __gshared uint mapStartPage;
private __gshared uint mapPageCount;
private __gshared uint neverTouchedFrom; // pages >= this are provably still zero from memory.grow
private __gshared ubyte* pagesBase;
private __gshared size_t heapOffset;

version (MemoryDebug) {
    private __gshared uint firstShadowPoolPage; // shadow-cell pool pages with free cells
    private __gshared uint callocMemsetSkips; // incremented once per skipped calloc memset
    private __gshared uint canaryViolations; // slack canary mismatches found on free
}

// End of static data. Take an address of it (&__data_end) to get the actual address.
// Provided by the linker (wasm-ld). The `extern` storage class is essential: without it,
// D *defines* a new 1-byte variable in .bss that shadows the linker's symbol, making all
// zero-initialized globals appear to live past the start of the heap.
private extern extern (C) __gshared ubyte __data_end;

// Start of heap: the first address past all static data (including .bss) and the shadow
// stack. Take an address of it (&__heap_base) to get the actual address. Provided by the
// linker (wasm-ld). See __data_end regarding the `extern` storage class.
private extern extern (C) __gshared ubyte __heap_base;

// Size of the full heap, including unusable memory.
private size_t fullHeapSize() {
    return llvm_wasm_memory_size(0) * _64KiB - cast(size_t)&__heap_base;
}

// Size of the usable heap.
private size_t heapSize() {
    return llvm_wasm_memory_size(0) * _64KiB - cast(size_t) heapStart;
}

// Start of the usable heap.
private ubyte* heapStart() {
    return &__heap_base + heapOffset;
}

// The page map, indexed flat over its contiguous region. Entry addresses are
// only valid until the next operation that can claim a page (which can cascade
// into a map relocation); page indices are stable, addresses are not.
private PageEntry* pageMap() {
    return cast(PageEntry*)(pagesBase + cast(size_t) mapStartPage * PageSize);
}

private ubyte* pageBaseAddr(uint page) {
    return pagesBase + cast(size_t) page * PageSize;
}

// Report a caller error (bad API input). Identical in all builds; on WASM
// writeErrLn dispatches straight to a JS import and does not allocate.
private void reportInvalid(string message) {
    writeErrLn(message);
}

// A broken internal invariant: the heap is already corrupt and continuing
// would spread it. Reports and traps (lowers to the WASM unreachable
// instruction) in every build; betterC assert cannot do this under -release.
private void trapInternal(string message) {
    writeErrLn(message);
    version (LDC) {
        llvm_trap();
    }

    assert(0);
}

// --- Slot bitmap (always on, all builds) ---------------------------------
// Every small page owns a 64-byte bitmap cell: one bit per slot, set while the
// slot is handed out. 4096 / 8 = 512 is the maximum slot count, so 64 bytes
// always suffice. This keeps the intrusive free-slot list honest: exact
// double-free detection and freelist-corruption checks in release builds too.

private enum size_t BitmapCellSize = 64;

private ubyte* bitmapCellAddr(uint cellId) {
    enum cellsPerPage = cast(uint)(PageSize / BitmapCellSize);
    return pagesBase + cast(size_t)(cellId / cellsPerPage) * PageSize
        + cast(size_t)(cellId % cellsPerPage) * BitmapCellSize;
}

private ubyte* bitmapOf(const PageEntry* entry) {
    auto cellId = entry.slotState & CellIdMask;
    if (cellId == NoCell) {
        trapInternal("bitmapOf: small page has no bitmap cell");
    }

    return bitmapCellAddr(cellId);
}

private bool bitmapTest(const ubyte* bitmap, uint slot) {
    return (bitmap[slot >> 3] & (1 << (slot & 7))) != 0;
}

private void bitmapSet(ubyte* bitmap, uint slot) {
    bitmap[slot >> 3] |= cast(ubyte)(1 << (slot & 7));
}

private void bitmapClear(ubyte* bitmap, uint slot) {
    bitmap[slot >> 3] &= cast(ubyte) ~(1 << (slot & 7));
}

private uint bitmapPopCount(const ubyte* bitmap, uint slotCount) {
    uint count = 0;
    auto byteCount = (slotCount + 7) >> 3;
    foreach (i; 0 .. byteCount) {
        ubyte b = bitmap[i];
        while (b != 0) {
            count += b & 1;
            b >>= 1;
        }
    }

    return count;
}

// --- Doubly-linked page lists (threaded through map entries) --------------
// Used for the per-class partial lists, the free-run list and the cell-pool
// lists. List membership never touches user-visible memory.

private void listPush(ref uint head, uint page) {
    auto entry = &pageMap[page];
    entry.prev = NoPage;
    entry.next = head;
    if (head != NoPage) {
        pageMap[head].prev = page;
    }

    head = page;
}

private void listUnlink(ref uint head, uint page) {
    auto entry = &pageMap[page];
    if (entry.prev != NoPage) {
        pageMap[entry.prev].next = entry.next;
    } else {
        head = entry.next;
    }

    if (entry.next != NoPage) {
        pageMap[entry.next].prev = entry.prev;
    }

    entry.next = NoPage;
    entry.prev = NoPage;
}

// --- Watermark ------------------------------------------------------------
// neverTouchedFrom carries exactly one claim: every page at index >=
// neverTouchedFrom is still byte-for-byte as memory.grow left it (all zero).
// "Nothing is untouched" is spelled neverTouchedFrom == numPages, never NoPage.
//
// claimPages is the sole owner of the watermark. There are exactly two ways a
// page is obtained: carvePages (out of a free run) and fresh memory.grow space
// the current map cannot describe (bootstrap in initializeHeapMemory and map
// growth branch 2) — the latter paths call claimPages directly.

private bool claimPages(uint firstPage, uint count) {
    auto wasUntouched = firstPage >= neverTouchedFrom;
    if (firstPage + count > neverTouchedFrom) {
        neverTouchedFrom = firstPage + count;
    }

    return wasUntouched;
}

/*
 * Carves `count` pages off the *front* of the free run starting at `runStart`
 * and returns whether the carved pages were never touched (sampled before the
 * watermark advances). Front-carving is deliberate: carving off the back of an
 * untouched run would advance the watermark past the untouched remainder and
 * permanently forfeit its calloc zero-skip.
 *
 * The carved pages' entries are left as-is; the caller retags them. The
 * remainder run (if any) gets a fresh head and an updated boundary mirror.
 */
private bool carvePages(uint runStart, uint count) {
    auto runLength = pageMap[runStart].runLength;
    if (count > runLength) {
        trapInternal("carvePages: carve larger than run");
    }

    listUnlink(firstFreeRun, runStart);
    if (count < runLength) {
        auto newStart = runStart + count;
        auto newLength = runLength - count;
        auto head = &pageMap[newStart];
        head.kind = PageKind.freeRun;
        head.sizeClass = 0;
        head.usedSlots = 0;
        head.freeHead = NoSlot;
        head.bumpIndex = 0;
        head.runLength = newLength;
        version (MemoryDebug) {
            head.debugInfo = 0;
        }

        auto tail = runStart + runLength - 1;
        pageMap[tail].runLength = newLength;
        if (newLength > 1) {
            pageMap[tail].kind = PageKind.freeCont;
        }

        listPush(firstFreeRun, newStart);
    }

    return claimPages(runStart, count);
}

// Writes a plain freeCont entry; runLength is only meaningful on a run's last
// page (the boundary mirror), interior values are dead by invariant.
private void writeFreeContEntry(uint page) {
    auto entry = &pageMap[page];
    entry.kind = PageKind.freeCont;
    entry.sizeClass = 0;
    entry.usedSlots = 0;
    entry.freeHead = NoSlot;
    entry.bumpIndex = 0;
    entry.next = NoPage;
    entry.prev = NoPage;
    entry.runLength = 0;
    version (MemoryDebug) {
        entry.debugInfo = 0;
    }
}

/*
 * Converts pages [start, start + count) into a free run, coalescing with
 * adjacent free runs, and pushes the result onto the free-run list.
 *
 * Neighbour lookup is O(1) via the boundary mirror: page start - 1 is by
 * construction always the *last* page of its run (page start was not free
 * before this call), so it always carries the run length. Both probes carry
 * explicit bounds guards (start == 0 is reachable once the map relocates off
 * page 0; start + count == numPages at the heap end).
 */
private void convertToFreeRun(uint start, uint count) {
    if (count == 0 || start + count > numPages) {
        trapInternal("convertToFreeRun: range does not describe pages");
    }

    auto mergedStart = start;
    auto mergedLength = count;

    if (start > 0) {
        auto predKind = pageMap[start - 1].kind;
        if (predKind == PageKind.freeRun || predKind == PageKind.freeCont) {
            auto predLength = pageMap[start - 1].runLength;
            if (predLength == 0 || predLength > start) {
                trapInternal("convertToFreeRun: corrupt predecessor mirror");
            }

            auto predStart = start - predLength;
            if (pageMap[predStart].kind != PageKind.freeRun
                || pageMap[predStart].runLength != predLength) {
                trapInternal("convertToFreeRun: predecessor head disagrees with mirror");
            }

            listUnlink(firstFreeRun, predStart);
            mergedStart = predStart;
            mergedLength += predLength;
        }
    }

    auto successor = start + count;
    bool absorbedSuccessor = false;
    if (successor < numPages && pageMap[successor].kind == PageKind.freeRun) {
        auto succLength = pageMap[successor].runLength;
        listUnlink(firstFreeRun, successor);
        mergedLength += succLength;
        absorbedSuccessor = true;
    }

    foreach (page; start .. start + count) {
        writeFreeContEntry(page);
    }

    if (absorbedSuccessor) {
        pageMap[successor].kind = PageKind.freeCont;
    }

    auto head = &pageMap[mergedStart];
    head.kind = PageKind.freeRun;
    head.sizeClass = 0;
    head.usedSlots = 0;
    head.freeHead = NoSlot;
    head.bumpIndex = 0;
    head.runLength = mergedLength;
    version (MemoryDebug) {
        head.debugInfo = 0;
    }

    auto tail = mergedStart + mergedLength - 1;
    pageMap[tail].runLength = mergedLength;
    if (tail != mergedStart) {
        pageMap[tail].kind = PageKind.freeCont;
    }

    listPush(firstFreeRun, mergedStart);
}

// Claims one page off the front of the first free run, growing the heap if the
// list is empty. Returns NoPage on OOM. The claimed page's entry is left for
// the caller to write.
private uint claimOnePage() {
    if (firstFreeRun == NoPage) {
        if (!growHeap(PageSize)) {
            return NoPage;
        }
    }

    auto page = firstFreeRun;
    if (page == NoPage) {
        return NoPage;
    }

    carvePages(page, 1);
    return page;
}

// --- Cell pools ------------------------------------------------------------
// A cell-pool page is a small page whose slots are fixed-size cells; the pool
// mechanism is parameterized by cell size (bitmap cells are 64 bytes, 64 per
// page; MemoryDebug shadow cells are 512 bytes, 8 per page). Cell ids encode
// their own location (page * cellsPerPage + index), so the pool needs no
// lookup table and never relocates. Pool pages with free cells are threaded
// into a list headed by the pool's head global.

/*
 * Claims a cell from the pool, growing the pool by one page if no page has
 * free cells. Returns the cell id, or NoCellId on OOM. The claimed cell is
 * memset to zero: a recycled cell holds the previous owner's bits plus the
 * freelist link, and a bump cell on a recycled pool page holds whatever the
 * page held before.
 *
 * Can claim a page and therefore relocate the map: callers must not hold
 * PageEntry pointers across this call.
 */
private uint claimPoolCell(ref uint poolHead, size_t cellSize, MetaKind poolKind) {
    auto cellsPerPage = cast(uint)(PageSize / cellSize);
    if (poolHead == NoPage) {
        auto page = claimOnePage();
        if (page == NoPage) {
            return NoCellId;
        }

        auto entry = &pageMap[page];
        entry.kind = PageKind.metadata;
        entry.sizeClass = cast(ubyte) poolKind;
        entry.usedSlots = 0;
        entry.freeHead = NoSlot;
        entry.bumpIndex = 0;
        entry.next = NoPage;
        entry.prev = NoPage;
        entry.slotState = 0;
        version (MemoryDebug) {
            entry.debugInfo = 0;
        }

        listPush(poolHead, page);
    }

    auto page = poolHead;
    auto entry = &pageMap[page];
    uint index;
    if (entry.freeHead != NoSlot) {
        index = entry.freeHead;
        if (index >= cellsPerPage) {
            trapInternal("claimPoolCell: corrupt cell freelist");
        }

        entry.freeHead = *cast(ushort*)(pageBaseAddr(page) + index * cellSize);
    } else {
        if (entry.bumpIndex >= cellsPerPage) {
            trapInternal("claimPoolCell: pool page on free list but full");
        }

        index = entry.bumpIndex;
        entry.bumpIndex++;
    }

    entry.usedSlots++;
    if (entry.usedSlots == cellsPerPage) {
        listUnlink(poolHead, page);
    }

    memset(pageBaseAddr(page) + index * cellSize, 0, cellSize);
    return page * cellsPerPage + index;
}

/*
 * Releases a cell back to its pool page. When the page's last cell is
 * released the page converts to a free run and coalesces as usual — a cascade
 * at most one level deep (pool pages own no cells of their own).
 */
private void releasePoolCell(ref uint poolHead, size_t cellSize, uint cellId) {
    auto cellsPerPage = cast(uint)(PageSize / cellSize);
    auto page = cellId / cellsPerPage;
    auto index = cellId % cellsPerPage;
    auto entry = &pageMap[page];
    if (entry.kind != PageKind.metadata || entry.usedSlots == 0) {
        trapInternal("releasePoolCell: cell id does not resolve to a live pool cell");
    }

    auto wasFull = entry.usedSlots == cellsPerPage;
    *cast(ushort*)(pageBaseAddr(page) + index * cellSize) = entry.freeHead;
    entry.freeHead = cast(ushort) index;
    entry.usedSlots--;

    if (entry.usedSlots == 0) {
        if (!wasFull) {
            listUnlink(poolHead, page);
        }

        convertToFreeRun(page, 1);
    } else if (wasFull) {
        listPush(poolHead, page);
    }
}

// --- Small allocation path ---------------------------------------------------

/*
 * Sets up a fresh page for the given size class: carve, write the full
 * smallPage entry, claim the bitmap (and MemoryDebug shadow) cell, push onto
 * the class's partial list. Returns the page index or NoPage on OOM.
 *
 * Ordering is deliberate: the entry is fully self-describing *before* the
 * cell claim, because claiming a cell can carve a pool page, grow the heap
 * and relocate the map — all of which walk or copy entries they did not
 * write. And on any failure after the carve, the page is rolled back onto the
 * free-run list: leaking it would leave a permanent slotless smallPage
 * special case for every later walk.
 */
private uint newSmallPage(ubyte sizeClass) {
    if (firstFreeRun == NoPage) {
        if (!growHeap(PageSize)) {
            return NoPage;
        }

        if (firstFreeRun == NoPage) {
            return NoPage;
        }
    }

    auto page = firstFreeRun;
    auto wasUntouched = carvePages(page, 1);

    {
        auto entry = &pageMap[page];
        entry.kind = PageKind.smallPage;
        entry.sizeClass = sizeClass;
        entry.usedSlots = 0;
        entry.freeHead = NoSlot;
        entry.bumpIndex = 0;
        entry.next = NoPage;
        entry.prev = NoPage;
        entry.slotState = NoCell | (wasUntouched ? BumpZeroedBit : 0);
        version (MemoryDebug) {
            entry.debugInfo = NoCellId;
        }
    }

    auto bitmapCell = claimPoolCell(firstCellPoolPage, BitmapCellSize, MetaKind.cellPool);
    if (bitmapCell == NoCellId) {
        convertToFreeRun(page, 1);
        return NoPage;
    }

    {
        // Re-index: the cell claim may have relocated the map.
        auto entry = &pageMap[page];
        entry.slotState = (entry.slotState & BumpZeroedBit) | (bitmapCell & CellIdMask);
    }

    version (MemoryDebug) {
        auto shadowCell = claimPoolCell(firstShadowPoolPage, ShadowCellSize, MetaKind.shadowPool);
        if (shadowCell == NoCellId) {
            releasePoolCell(firstCellPoolPage, BitmapCellSize, bitmapCell);
            convertToFreeRun(page, 1);
            return NoPage;
        }

        pageMap[page].debugInfo = shadowCell;
    }

    listPush(partialPages[sizeClass], page);
    return page;
}

/*
 * The O(1) small path. slotIsZero reports whether the returned slot is
 * provably still in its memory.grow state (bump-path slot on a bumpZeroed
 * page) — calloc's zero-skip. Any slot obtained from the freelist has been
 * handed out before and its first two bytes hold the freelist link, so it is
 * never reported zero.
 */
private void* mallocSmall(size_t size, out bool slotIsZero) {
    auto sizeClass = sizeToClass(size);
    auto page = partialPages[sizeClass];
    if (page == NoPage) {
        page = newSmallPage(sizeClass);
        if (page == NoPage) {
            return null;
        }
    }

    auto entry = &pageMap[page];
    auto slots = slotsPerPage(sizeClass);
    auto classSize = cast(size_t) classSizes[sizeClass];
    auto pageBase = pageBaseAddr(page);
    auto bitmap = bitmapOf(entry);
    uint slot;
    if (entry.freeHead != NoSlot) {
        slot = entry.freeHead;
        if (slot >= slots) {
            trapInternal("malloc: corrupt slot freelist index");
        }

        if (bitmapTest(bitmap, slot)) {
            trapInternal("malloc: freelist slot is marked live");
        }

        entry.freeHead = *cast(ushort*)(pageBase + slot * classSize);
        slotIsZero = false;
    } else {
        if (entry.bumpIndex >= slots) {
            trapInternal("malloc: partial page has no free slot");
        }

        slot = entry.bumpIndex;
        entry.bumpIndex++;
        slotIsZero = (entry.slotState & BumpZeroedBit) != 0;
    }

    bitmapSet(bitmap, slot);
    entry.usedSlots++;
    if (entry.usedSlots == slots) {
        listUnlink(partialPages[sizeClass], page);
        version (MemoryDebug) {
            checkBitmapAgreement(page);
        }
    }

    version (MemoryDebug) {
        writeShadow(page, slot, size);
    }

    return pageBase + slot * classSize;
}

// --- Large allocation path ---------------------------------------------------

private uint findRun(uint pages) {
    auto run = firstFreeRun;
    while (run != NoPage) {
        if (pageMap[run].runLength >= pages) {
            return run;
        }

        run = pageMap[run].next;
    }

    return NoPage;
}

// Tags pages [runStart, runStart + pages) as a large allocation. runStart on
// every continuation page is what makes interior pointers resolve in O(1).
private void writeLargeRun(uint runStart, uint pages, size_t requestedSize) {
    auto entry = &pageMap[runStart];
    entry.kind = PageKind.largeStart;
    entry.sizeClass = 0;
    entry.usedSlots = 0;
    entry.freeHead = NoSlot;
    entry.bumpIndex = 0;
    entry.next = NoPage;
    entry.prev = NoPage;
    entry.runLength = pages;
    version (MemoryDebug) {
        entry.debugInfo = cast(uint) requestedSize;
    }

    foreach (page; runStart + 1 .. runStart + pages) {
        auto cont = &pageMap[page];
        cont.kind = PageKind.largeCont;
        cont.sizeClass = 0;
        cont.usedSlots = 0;
        cont.freeHead = NoSlot;
        cont.bumpIndex = 0;
        cont.next = NoPage;
        cont.prev = NoPage;
        cont.runStart = runStart;
        version (MemoryDebug) {
            cont.debugInfo = 0;
        }
    }
}

private void* mallocLarge(size_t size, out bool runIsZero) {
    // Overflow bound, not a capacity bound: an over-heap request fails
    // ordinarily as OOM out of growHeap.
    if (size > size_t.max - PageSize + 1) {
        return null;
    }

    auto pages = cast(uint)((size + PageSize - 1) / PageSize);
    auto run = findRun(pages);
    if (run == NoPage) {
        if (!growHeap(size)) {
            return null;
        }

        run = findRun(pages);
        if (run == NoPage) {
            return null;
        }
    }

    runIsZero = carvePages(run, pages);
    writeLargeRun(run, pages, size);
    return pageBaseAddr(run);
}

// --- Heap growth and page map growth -----------------------------------------

private enum EnsureOutcome {
    covered, // existing capacity suffices; caller performs its own grow
    relocated, // map moved into an existing free run; caller performs its own grow
    grewAndAppended, // the single combined grow already happened; caller must NOT grow again
    failed // memory.grow refused; ordinary OOM
}

/*
 * Ensures the map can describe numPages + userPages entries. userPages must
 * already be a whole-wasm-page multiple (16 logical pages); growHeap is the
 * only caller.
 *
 * Failure is total, never partial: the old map stays authoritative until the
 * new one is fully built, so a refused grow leaves everything as it was. The
 * lasting invariant is mapCapacity >= numPages — capacity beyond coverage is
 * the harmless direction (e.g. the residue of a branch-1 relocation whose
 * follow-up user grow failed).
 */
private EnsureOutcome ensureMapCapacity(uint userPages) {
    auto needed = numPages + userPages;
    if (mapCapacity >= needed) {
        return EnsureOutcome.covered;
    }

    /*
     * Closed form for the new map size, folding in both roundings: the map's
     * self-reference (map pages are heap pages that need entries too) and the
     * 64 KiB granularity of a possible branch-2 grow (up to 15 slop pages the
     * map must also cover): mapPages = ceil((P + 15) / (E - 1)). The +15
     * occasionally costs one unneeded map page; capacity >= coverage is the
     * harmless direction.
     */
    auto newMapPages = (needed + 15 + (entriesPerMapPage - 2)) / (entriesPerMapPage - 1);

    // Branch 1: relocate into an existing free run if one fits the whole map.
    auto run = findRun(newMapPages);
    if (run != NoPage) {
        relocateMapInto(run, newMapPages);
        return EnsureOutcome.relocated;
    }

    /*
     * Branch 2: no interior run fits — one combined grow for user need + new
     * map, with the map at the *start* of the fresh region. Start-placement
     * keeps the pages beyond map + user above the watermark (their calloc
     * zero-skip survives); end-placement would strand them below it.
     */
    auto totalLogical = userPages + newMapPages;
    auto wasmPages = (totalLogical + PagesPerWasmPage - 1) / PagesPerWasmPage;
    if (llvm_wasm_memory_grow(0, wasmPages) == -1) {
        return EnsureOutcome.failed;
    }

    auto firstNew = numPages;
    auto newTotal = firstNew + wasmPages * PagesPerWasmPage;
    auto newMap = cast(PageEntry*) pageBaseAddr(firstNew);

    // Build the new map: copy old entries, then describe the fresh pages in
    // the new map only — the old map stays untouched until the switch-over.
    memcpy(newMap, pageMap, numPages * PageEntry.sizeof);
    foreach (page; firstNew .. firstNew + newMapPages) {
        writeMapPageEntry(newMap, page);
    }

    auto freeStart = firstNew + newMapPages;
    auto freeLength = newTotal - freeStart;
    if (freeLength > 0) {
        foreach (page; freeStart .. newTotal) {
            auto cont = &newMap[page];
            cont.kind = PageKind.freeCont;
            cont.sizeClass = 0;
            cont.usedSlots = 0;
            cont.freeHead = NoSlot;
            cont.bumpIndex = 0;
            cont.next = NoPage;
            cont.prev = NoPage;
            cont.runLength = 0;
            version (MemoryDebug) {
                cont.debugInfo = 0;
            }
        }

        auto head = &newMap[freeStart];
        head.kind = PageKind.freeRun;
        head.runLength = freeLength;
        newMap[newTotal - 1].runLength = freeLength;
    }

    // The map pages are written this instant; the fresh free run beyond them
    // stays above the watermark.
    claimPages(firstNew, newMapPages);

    auto oldMapStart = mapStartPage;
    auto oldMapCount = mapPageCount;

    // Switch-over: from here the new map is authoritative.
    mapStartPage = firstNew;
    mapPageCount = newMapPages;
    mapCapacity = newMapPages * entriesPerMapPage;
    numPages = newTotal;

    if (freeLength > 0) {
        listPush(firstFreeRun, freeStart);
    }

    // Release the old map region: recycled, below the watermark it was
    // claimed under when first built.
    convertToFreeRun(oldMapStart, oldMapCount);
    return EnsureOutcome.grewAndAppended;
}

private void writeMapPageEntry(PageEntry* map, uint page) {
    auto entry = &map[page];
    entry.kind = PageKind.metadata;
    entry.sizeClass = cast(ubyte) MetaKind.pageMap;
    entry.usedSlots = 0;
    entry.freeHead = NoSlot;
    entry.bumpIndex = 0;
    entry.next = NoPage;
    entry.prev = NoPage;
    entry.slotState = 0;
    version (MemoryDebug) {
        entry.debugInfo = 0;
    }
}

// Branch 1 of map growth: the new map fits in an existing free run. Carve
// (which handles the watermark), copy, retag, switch over, release the old
// region. No memory is grown here; the caller's own grow may still fail
// afterwards, leaving an oversized map — harmless.
private void relocateMapInto(uint runStart, uint newMapPages) {
    carvePages(runStart, newMapPages);
    auto newMap = cast(PageEntry*) pageBaseAddr(runStart);
    memcpy(newMap, pageMap, numPages * PageEntry.sizeof);
    foreach (page; runStart .. runStart + newMapPages) {
        writeMapPageEntry(newMap, page);
    }

    auto oldMapStart = mapStartPage;
    auto oldMapCount = mapPageCount;
    mapStartPage = runStart;
    mapPageCount = newMapPages;
    mapCapacity = newMapPages * entriesPerMapPage;
    convertToFreeRun(oldMapStart, oldMapCount);
}

/*
 * Grows linear memory by ceil(wantedBytes / 64 KiB) wasm pages and appends
 * the new logical pages as a free run. Sole caller of the map-growth
 * machinery; the three-outcome contract of ensureMapCapacity decides who
 * performs the grow (see the EnsureOutcome cases).
 *
 * Does not touch neverTouchedFrom: new pages are appended above numPages and
 * are zero per the WASM spec, so the watermark's claim survives the append.
 */
private bool growHeap(size_t wantedBytes) {
    // Rounding to whole wasm pages must not overflow: a request this size can
    // never be satisfied on wasm32, so it fails as ordinary OOM.
    if (wantedBytes > size_t.max - (_64KiB - 1)) {
        return false;
    }

    auto wasmPages = cast(uint)((wantedBytes + _64KiB - 1) / _64KiB);
    auto userPages = wasmPages * PagesPerWasmPage;
    auto outcome = ensureMapCapacity(userPages);
    if (outcome == EnsureOutcome.failed) {
        return false;
    }

    if (outcome == EnsureOutcome.grewAndAppended) {
        return true;
    }

    if (llvm_wasm_memory_grow(0, wasmPages) == -1) {
        return false;
    }

    auto firstNew = numPages;
    numPages = firstNew + userPages;
    convertToFreeRun(firstNew, userPages);
    return true;
}

// --- Pointer resolution ------------------------------------------------------

private enum HeapPointerKind {
    notHeap, // stack, static data, or outside the page area: no bounds check possible
    live, // inside a live small slot or large run
    freed // inside a free run or free slot — or allocator metadata, which no
        // legitimate caller may address either; both are bounds failures
}

private struct AllocationInfo {
    HeapPointerKind kind;
    void* base; // slot start or run start (live only)
    size_t capacity; // class size or run bytes (live only; exact requested size under MemoryDebug)
}

/*
 * Resolves any pointer — including interior pointers — to its allocation in
 * O(1). Private on purpose: this is a WASM-only capability with no native
 * counterpart, and exposing it would invite engine code that breaks the
 * native build.
 */
private AllocationInfo heapAllocationInfo(const void* ptr) {
    AllocationInfo info;
    info.kind = HeapPointerKind.notHeap;
    if (pagesBase is null || numPages == 0) {
        return info;
    }

    // Subtraction form: immune to the end-of-memory pointer wrapping to 0 at
    // the wasm32 4 GiB ceiling, and unsigned wraparound makes ptr < pagesBase
    // fail the same single comparison.
    auto offset = cast(size_t)(cast(const ubyte*) ptr - pagesBase);
    if (offset >= cast(size_t) numPages * PageSize) {
        return info;
    }

    auto page = cast(uint)(offset >> PageShift);
    auto entry = &pageMap[page];
    switch (entry.kind) {
    case PageKind.smallPage: {
            auto pageOffset = offset & (PageSize - 1);
            auto classSize = cast(size_t) classSizes[entry.sizeClass];
            uint slot;
            slotFromOffset(entry.sizeClass, pageOffset, slot);
            if (slot >= slotsPerPage(entry.sizeClass)) {
                trapInternal("heapAllocationInfo: slot out of range");
            }

            if (!bitmapTest(bitmapOf(entry), slot)) {
                info.kind = HeapPointerKind.freed;
                return info;
            }

            info.kind = HeapPointerKind.live;
            info.base = pageBaseAddr(page) + slot * classSize;
            info.capacity = classSize;
            version (MemoryDebug) {
                info.capacity = classSize - shadowByteOf(entry, slot);
            }

            return info;
        }
    case PageKind.largeStart: {
            info.kind = HeapPointerKind.live;
            info.base = pageBaseAddr(page);
            info.capacity = cast(size_t) entry.runLength * PageSize;
            version (MemoryDebug) {
                info.capacity = entry.debugInfo;
            }

            return info;
        }
    case PageKind.largeCont: {
            auto runStart = entry.runStart;
            auto startEntry = &pageMap[runStart];
            if (startEntry.kind != PageKind.largeStart) {
                trapInternal("heapAllocationInfo: largeCont does not resolve to a largeStart");
            }

            info.kind = HeapPointerKind.live;
            info.base = pageBaseAddr(runStart);
            info.capacity = cast(size_t) startEntry.runLength * PageSize;
            version (MemoryDebug) {
                info.capacity = startEntry.debugInfo;
            }

            return info;
        }
    case PageKind.freeRun:
    case PageKind.freeCont:
    case PageKind.metadata:
        info.kind = HeapPointerKind.freed;
        return info;
    default:
        trapInternal("heapAllocationInfo: unknown page kind");
        return info;
    }
}

// --- Public allocation API -----------------------------------------------------

/**
 * Allocate memory block of size bytes. Returns a pointer to the allocated memory,
 * or a null pointer if the request fails.
 *
 * The returned pointer is at least 8-byte aligned.
 *
 * Params:
 *  size: The size of the memory block in bytes.
 * Returns: A pointer to the allocated memory, or null if allocation failed.
 */
export extern (C) void* malloc(size_t size) {
    if (size == 0) {
        return null;
    }

    bool isZero;
    if (size <= MaxSmallSize) {
        return mallocSmall(size, isZero);
    }

    return mallocLarge(size, isZero);
}

/**
 * Allocates a memory block of the given size N times.
 * Unlike with malloc, the allocated memory is cleared upon allocation.
 * When the returned pointer is null, allocation failed.
 *
 * Params:
 *  nitems: The number of items to allocate.
 *  size: The size of each item.
 * Returns: A pointer to the allocated memory, or null if allocation failed.
 */
version (LDC) @optStrategy("none")
export extern (C) void* calloc(size_t nitems, size_t size) {
    if (size != 0 && nitems > size_t.max / size) {
        return null;
    }

    auto totalSize = nitems * size;
    if (totalSize == 0) {
        return null;
    }

    // The zero contract is unconditional; the memset is skipped only where
    // the memory is provably still in its memory.grow state (see the
    // watermark and the bumpZeroed flag). When in doubt, memset.
    bool isZero;
    void* ptr;
    if (totalSize <= MaxSmallSize) {
        ptr = mallocSmall(totalSize, isZero);
    } else {
        ptr = mallocLarge(totalSize, isZero);
    }

    if (ptr is null) {
        return null;
    }

    if (isZero) {
        version (MemoryDebug) {
            callocMemsetSkips++;
        }
    } else {
        memset(ptr, 0, totalSize);
    }

    return ptr;
}

/**
 * Frees the memory space pointed to by ptr, which must have been returned by a
 * previous call to malloc, calloc or realloc, and must point to the start of
 * that allocation.
 *
 * Invalid frees — double frees, interior pointers, pointers into free pages or
 * allocator metadata, non-heap pointers — are detected exactly, reported and
 * rejected in all builds. If ptr is null, no operation is performed.
 *
 * Note that freed memory does not preserve its contents: the allocator writes
 * a free-list link into the first two bytes of a freed slot.
 *
 * Params:
 *  ptr: The pointer to the memory block to free.
 */
export extern (C) void free(void* ptr) {
    if (ptr is null) {
        return;
    }

    auto offset = cast(size_t)(cast(ubyte*) ptr - pagesBase);
    if (pagesBase is null || offset >= cast(size_t) numPages * PageSize) {
        reportInvalid("free: pointer is not heap memory");
        return;
    }

    auto page = cast(uint)(offset >> PageShift);
    auto entry = &pageMap[page];
    switch (entry.kind) {
    case PageKind.smallPage:
        freeSmall(page, offset & (PageSize - 1));
        return;
    case PageKind.largeStart:
        if ((offset & (PageSize - 1)) != 0) {
            reportInvalid("free: pointer is not the start of the allocation");
            return;
        }

        convertToFreeRun(page, entry.runLength);
        return;
    case PageKind.largeCont:
        reportInvalid("free: pointer into the interior of a large allocation");
        return;
    case PageKind.freeRun:
    case PageKind.freeCont:
        reportInvalid("free: double free or pointer into free memory");
        return;
    case PageKind.metadata:
        reportInvalid("free: pointer into allocator metadata");
        return;
    default:
        trapInternal("free: unknown page kind");
        return;
    }
}

private void freeSmall(uint page, size_t pageOffset) {
    auto entry = &pageMap[page];
    auto sizeClass = entry.sizeClass;
    auto classSize = cast(size_t) classSizes[sizeClass];
    uint slot;
    if (!slotFromOffset(sizeClass, pageOffset, slot)) {
        reportInvalid("free: pointer is not the start of a slot");
        return;
    }

    auto slots = slotsPerPage(sizeClass);
    if (slot >= slots) {
        trapInternal("free: slot out of range");
    }

    auto bitmap = bitmapOf(entry);
    if (!bitmapTest(bitmap, slot)) {
        reportInvalid("free: double free");
        return;
    }

    version (MemoryDebug) {
        checkCanary(page, slot);
    }

    bitmapClear(bitmap, slot);
    auto pageBase = pageBaseAddr(page);
    *cast(ushort*)(pageBase + slot * classSize) = entry.freeHead;
    entry.freeHead = cast(ushort) slot;
    auto wasFull = entry.usedSlots == slots;
    entry.usedSlots--;

    if (entry.usedSlots == 0) {
        version (MemoryDebug) {
            checkBitmapAgreement(page);
        }

        /*
         * Eager empty-page reclamation. Read the cell ids out of the entry
         * first — converting it to a free run overwrites the union — and
         * release the cells only after the page's own conversion and
         * coalescing are complete, so the release's possible second coalesce
         * never observes a half-updated run.
         */
        auto bitmapCell = entry.slotState & CellIdMask;
        version (MemoryDebug) {
            auto shadowCell = entry.debugInfo;
        }

        if (!wasFull) {
            listUnlink(partialPages[sizeClass], page);
        }

        convertToFreeRun(page, 1);
        releasePoolCell(firstCellPoolPage, BitmapCellSize, bitmapCell);
        version (MemoryDebug) {
            releasePoolCell(firstShadowPoolPage, ShadowCellSize, shadowCell);
        }

        return;
    }

    if (wasFull) {
        version (MemoryDebug) {
            checkBitmapAgreement(page);
        }

        listPush(partialPages[sizeClass], page);
    }
}

/**
 * Similar to free, the memory space pointed to by ptr is freed.
 * A size check is performed for safety: the given size must resolve to the
 * same size class (or, for large allocations, the same page count) the block
 * was allocated with. Under MemoryDebug the check is byte-exact instead. On a
 * mismatch the free is reported and rejected.
 *
 * Params:
 *  ptr: The pointer to the memory block to free.
 *  size: The size of the memory block when it was allocated.
 */
export extern (C) void free_sized(void* ptr, size_t size) {
    if (ptr is null) {
        return;
    }

    auto offset = cast(size_t)(cast(ubyte*) ptr - pagesBase);
    if (pagesBase is null || offset >= cast(size_t) numPages * PageSize) {
        reportInvalid("free_sized: pointer is not heap memory");
        return;
    }

    auto page = cast(uint)(offset >> PageShift);
    auto entry = &pageMap[page];
    if (entry.kind == PageKind.smallPage) {
        version (MemoryDebug) {
            auto pageOffset = offset & (PageSize - 1);
            uint slot;
            if (slotFromOffset(entry.sizeClass, pageOffset, slot)
                && bitmapTest(bitmapOf(entry), slot)) {
                auto exactSize = classSizes[entry.sizeClass] - shadowByteOf(entry, slot);
                if (size != exactSize) {
                    reportInvalid("free_sized: size does not match the allocation");
                    return;
                }
            }
        } else {
            if (size == 0 || size > MaxSmallSize || sizeToClass(size) != entry.sizeClass) {
                reportInvalid("free_sized: size does not match the allocation's size class");
                return;
            }
        }
    } else if (entry.kind == PageKind.largeStart) {
        version (MemoryDebug) {
            if (size != entry.debugInfo) {
                reportInvalid("free_sized: size does not match the allocation");
                return;
            }
        } else {
            auto pages = cast(uint)((size + PageSize - 1) / PageSize);
            if (size <= MaxSmallSize || pages != entry.runLength) {
                reportInvalid("free_sized: size does not match the allocation's page count");
                return;
            }
        }
    }

    free(ptr);
}

/**
 * Resize a block of memory. If the given ptr is null, a new block is allocated.
 * Returns a pointer to either the same memory block if the resize fit within
 * the allocation's size class (or page count), otherwise a different pointer
 * to a new block of memory. When the returned pointer is null, the resize
 * failed and the original allocation is left intact.
 *
 * Like free, realloc requires the exact allocation start; interior pointers
 * and freed pointers are reported and rejected with null.
 *
 * Params:
 *  ptr: The pointer to the memory block to resize. If null, a new block is allocated.
 *  newSize: The new size of the memory block. If it is 0 and ptr is not null, the block
 *           is freed and a null pointer is returned (following glibc convention).
 * Returns: A pointer to the resized memory block, or null if something went wrong. The same pointer is returned when the resize fit.
 */
export extern (C) void* realloc(void* ptr, size_t newSize) {
    if (ptr is null) {
        return malloc(newSize);
    }

    if (newSize == 0) {
        free(ptr);
        return null;
    }

    auto offset = cast(size_t)(cast(ubyte*) ptr - pagesBase);
    if (pagesBase is null || offset >= cast(size_t) numPages * PageSize) {
        reportInvalid("realloc: pointer is not heap memory");
        return null;
    }

    auto page = cast(uint)(offset >> PageShift);
    auto kind = pageMap[page].kind;
    if (kind == PageKind.smallPage) {
        return reallocSmall(ptr, page, offset & (PageSize - 1), newSize);
    }

    if (kind == PageKind.largeStart) {
        if ((offset & (PageSize - 1)) != 0) {
            reportInvalid("realloc: pointer is not the start of the allocation");
            return null;
        }

        return reallocLarge(ptr, page, newSize);
    }

    reportInvalid("realloc: pointer does not point to a live allocation start");
    return null;
}

// Move fallback shared by both realloc paths. On allocation failure the
// original is left intact and null returned — the caller still owns its old
// pointer (glibc contract).
private void* reallocMove(void* ptr, size_t oldCapacity, size_t newSize) {
    auto newPtr = malloc(newSize);
    if (newPtr is null) {
        return null;
    }

    auto copyBytes = oldCapacity < newSize ? oldCapacity : newSize;
    memcpy(newPtr, ptr, copyBytes);
    free(ptr);
    return newPtr;
}

private void* reallocSmall(void* ptr, uint page, size_t pageOffset, size_t newSize) {
    auto entry = &pageMap[page];
    auto sizeClass = entry.sizeClass;
    auto classSize = cast(size_t) classSizes[sizeClass];
    uint slot;
    if (!slotFromOffset(sizeClass, pageOffset, slot)) {
        reportInvalid("realloc: pointer is not the start of a slot");
        return null;
    }

    if (!bitmapTest(bitmapOf(entry), slot)) {
        reportInvalid("realloc: pointer is not a live allocation");
        return null;
    }

    if (newSize <= MaxSmallSize && sizeToClass(newSize) == sizeClass) {
        // In place. The user bytes are untouched, but under MemoryDebug the
        // requested-size shadow and the slack canary describe the old size
        // and must be refreshed, or free_sized/memmove check stale bounds.
        version (MemoryDebug) {
            writeShadow(page, slot, newSize);
        }

        return ptr;
    }

    return reallocMove(ptr, classSize, newSize);
}

private void* reallocLarge(void* ptr, uint page, size_t newSize) {
    if (newSize > size_t.max - PageSize + 1) {
        return null;
    }

    auto entry = &pageMap[page];
    auto oldPages = entry.runLength;
    auto oldCapacity = cast(size_t) oldPages * PageSize;
    if (newSize <= MaxSmallSize) {
        return reallocMove(ptr, oldCapacity, newSize);
    }

    auto newPages = cast(uint)((newSize + PageSize - 1) / PageSize);
    if (newPages == oldPages) {
        version (MemoryDebug) {
            entry.debugInfo = cast(uint) newSize;
        }

        return ptr;
    }

    if (newPages < oldPages) {
        // In-place shrink: the freed tail coalesces with a following run.
        entry.runLength = newPages;
        version (MemoryDebug) {
            entry.debugInfo = cast(uint) newSize;
        }

        convertToFreeRun(page + newPages, oldPages - newPages);
        return ptr;
    }

    // In-place grow: absorb from the front of the directly following free
    // run, if it is long enough. carvePages rewrites the remainder's head and
    // boundary mirror on a partial absorb.
    auto next = page + oldPages;
    if (next < numPages && pageMap[next].kind == PageKind.freeRun
        && oldPages + pageMap[next].runLength >= newPages) {
        auto extra = newPages - oldPages;
        carvePages(next, extra);
        foreach (contPage; next .. next + extra) {
            auto cont = &pageMap[contPage];
            cont.kind = PageKind.largeCont;
            cont.sizeClass = 0;
            cont.usedSlots = 0;
            cont.freeHead = NoSlot;
            cont.bumpIndex = 0;
            cont.next = NoPage;
            cont.prev = NoPage;
            cont.runStart = page;
            version (MemoryDebug) {
                cont.debugInfo = 0;
            }
        }

        entry.runLength = newPages;
        version (MemoryDebug) {
            entry.debugInfo = cast(uint) newSize;
        }

        return ptr;
    }

    return reallocMove(ptr, oldCapacity, newSize);
}

// --- Byte primitives -----------------------------------------------------------

/**
 * Sets the num bytes of the block of memory pointed by ptr to the specified value (interpreted as an unsigned byte).
 *
 * Params:
 *  ptr: Pointer to the block of memory to fill.
 *  value: Value to be set. The value is passed as an int, but the function fills the block of memory using the
 *         unsigned char conversion of this value.
 *  num: Number of bytes to be set to the value.
 * Returns: ptr as-is.
 */
version (LDC) @optStrategy("none")
export extern (C) void* memset(void* ptr, int value, size_t num) {
    // optStrategy("none") is load-bearing: at -O3 LLVM rewrites fill loops
    // into calls to memset — this very function. Word-wise with byte head and
    // tail; the allocator zeroes multi-MiB regions through here.
    auto p = cast(ubyte*) ptr;
    auto b = cast(ubyte) value;
    while (num > 0 && (cast(size_t) p & 3) != 0) {
        *p = b;
        p++;
        num--;
    }

    uint word = b | (b << 8) | (b << 16) | (b << 24);
    auto wordPtr = cast(uint*) p;
    while (num >= 4) {
        *wordPtr = word;
        wordPtr++;
        num -= 4;
    }

    p = cast(ubyte*) wordPtr;
    while (num > 0) {
        *p = b;
        p++;
        num--;
    }

    return ptr;
}

/**
 * Compares the first num bytes of the memory areas pointed to by ptr1 and ptr2, returning zero if
 * they are equal or a value different from zero representing which is greater if they are not.
 *
 * Params:
 *  ptr1: Pointer to first memory area.
 *  ptr2: Pointer to second memory area.
 *  num: Number of bytes to compare.
 * Returns: An integral value indicating the relationship between the contents:
 *          A zero value indicates that the contents of both memory areas are equal.
 *          A value greater than zero indicates that the first differing byte has a greater value in ptr1 than in ptr2.
 *          A value less than zero indicates the opposite.
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

/**
 * Copies memory from src into dest for count amount of bytes.
 * No bounds checking is performed. When count is greated than src or dest's
 * allocated sizes, unintended memory is copied/replaced and corruption may occur.
 * It is faster than memmove, but unsafe.
 *
 * Params:
 *  dest: Pointer to the destination array where the content is to be copied.
 *  src: Pointer to the source of data to be copied.
 *  count: Number of bytes to copy.
 * Returns: dest as-is.
 */
export extern (C) void* memcpy(void* dest, const void* src, size_t count) {
    for (size_t i; i < count; i++) {
        (cast(ubyte*) dest)[i] = (cast(ubyte*) src)[i];
    }

    return dest;
}

/**
 * Copies count bytes from src into dest, correctly handling overlapping memory regions.
 * Works with any valid pointer (heap, stack, static data).
 *
 * When src or dest point into this allocator's heap, bounds checking is
 * performed against the resolved allocation — including interior pointers,
 * which resolve in O(1); the check is offset-relative within the allocation.
 * A pointer into freed heap memory or allocator metadata is a bounds failure:
 * null is returned and nothing is copied. When a pointer is not heap-managed
 * (stack, static data), no bounds check is possible and count is used as-is.
 *
 * Bounds are class/page-granular in release builds; under MemoryDebug the
 * requested-size shadow makes them byte-exact.
 *
 * Unlike memcpy, memmove handles the case where src and dest overlap by copying
 * backwards when dest > src with overlapping ranges.
 *
 * Params:
 *  dest: Pointer to the destination memory.
 *  src: Pointer to the source memory.
 *  count: Number of bytes to copy.
 * Returns: dest on success, or null if a heap bounds check fails.
 */
export extern (C) void* memmove(void* dest, const void* src, size_t count) {
    if (count == 0) {
        return dest;
    }

    auto srcInfo = heapAllocationInfo(src);
    if (srcInfo.kind == HeapPointerKind.freed) {
        reportInvalid("memmove: src points into freed memory or allocator metadata");
        return null;
    }

    if (srcInfo.kind == HeapPointerKind.live
        && (cast(size_t)(src - srcInfo.base)) + count > srcInfo.capacity) {
        reportInvalid("memmove: count exceeds src allocation bounds");
        return null;
    }

    auto destInfo = heapAllocationInfo(dest);
    if (destInfo.kind == HeapPointerKind.freed) {
        reportInvalid("memmove: dest points into freed memory or allocator metadata");
        return null;
    }

    if (destInfo.kind == HeapPointerKind.live
        && (cast(size_t)(dest - destInfo.base)) + count > destInfo.capacity) {
        reportInvalid("memmove: count exceeds dest allocation bounds");
        return null;
    }

    auto d = cast(ubyte*) dest;
    auto s = cast(const ubyte*) src;

    if (d > s && d < s + count) {
        for (size_t i = count; i > 0; i--) {
            d[i - 1] = s[i - 1];
        }
    } else {
        for (size_t i = 0; i < count; i++) {
            d[i] = s[i];
        }
    }

    return dest;
}

// --- MemoryDebug instrumentation ---------------------------------------------
// Forensics only: none of these change whether a call succeeds. The always-on
// checks (range, kind, slot alignment, slot bitmap, freelist validation) are
// release-mode features and live in the paths above.

version (MemoryDebug) {
    private enum size_t ShadowCellSize = 512;
    private enum ubyte CanaryByte = 0xC5;

    private ubyte* shadowCellAddr(uint cellId) {
        enum cellsPerPage = cast(uint)(PageSize / ShadowCellSize);
        return pagesBase + cast(size_t)(cellId / cellsPerPage) * PageSize
            + cast(size_t)(cellId % cellsPerPage) * ShadowCellSize;
    }

    // The shadow stores the *slack* (classSize - requested), which always
    // fits a byte (max 255, at 1793 -> 2048); the requested size itself would
    // not. Recover the requested size as classSize - slack.
    private ubyte shadowByteOf(const PageEntry* entry, uint slot) {
        if (entry.debugInfo == NoCellId) {
            trapInternal("shadowByteOf: small page has no shadow cell");
        }

        return shadowCellAddr(entry.debugInfo)[slot];
    }

    private void writeShadow(uint page, uint slot, size_t requestedSize) {
        auto entry = &pageMap[page];
        auto classSize = cast(size_t) classSizes[entry.sizeClass];
        auto slack = cast(ubyte)(classSize - requestedSize);
        shadowCellAddr(entry.debugInfo)[slot] = slack;
        if (slack > 0) {
            memset(pageBaseAddr(page) + slot * classSize + requestedSize, CanaryByte, slack);
        }
    }

    // optStrategy("none"): keeps LLVM from recognizing the compare loop and
    // rewriting it into a call to a C mem function defined in this module.
    version (LDC) @optStrategy("none")
    private void checkCanary(uint page, uint slot) {
        auto entry = &pageMap[page];
        auto classSize = cast(size_t) classSizes[entry.sizeClass];
        auto slack = cast(size_t) shadowByteOf(entry, slot);
        auto slackStart = pageBaseAddr(page) + slot * classSize + (classSize - slack);
        foreach (i; 0 .. slack) {
            if (slackStart[i] != CanaryByte) {
                canaryViolations++;
                reportInvalid("free: slack canary overwritten (write past the requested size)");
                return;
            }
        }
    }

    private void checkBitmapAgreement(uint page) {
        auto entry = &pageMap[page];
        auto slots = slotsPerPage(entry.sizeClass);
        if (bitmapPopCount(bitmapOf(entry), slots) != entry.usedSlots) {
            trapInternal("slot bitmap population disagrees with usedSlots");
        }
    }
}

// --- Initialization and debugging tools ----------------------------------------

/**
 * Initializes the heap memory.
 * This function must be called before any other memory function. It fully
 * rebuilds allocator state from nothing; re-initialization over an existing
 * heap conservatively treats every page as touched (see calloc).
 *
 * Params:
 *   _heapOffset: Extra offset from __heap_base to the start of the managed heap.
 *                Defaults to 0: __heap_base is provided by the linker and already points
 *                past all static data, including zero-initialized globals (.bss) and the
 *                shadow stack, so no offset is needed.
 */
OperationResult initializeHeapMemory(size_t _heapOffset = 0) {
    heapOffset = _heapOffset;
    foreach (i; 0 .. NumSizeClasses) {
        partialPages[i] = NoPage;
    }

    firstFreeRun = NoPage;
    firstCellPoolPage = NoPage;
    version (MemoryDebug) {
        firstShadowPoolPage = NoPage;
        callocMemsetSkips = 0;
        canaryViolations = 0;
    }

    numPages = 0;
    mapCapacity = 0;
    mapStartPage = 0;
    mapPageCount = 0;
    neverTouchedFrom = 0;
    pagesBase = null;

    // Raw initial grow — growHeap needs a map to exist, and this runs before
    // any map does.
    auto memBytesBefore = llvm_wasm_memory_size(0) * _64KiB;
    if (fullHeapSize() < initialHeapSize) {
        auto shortfall = initialHeapSize - fullHeapSize();
        auto growPages = (shortfall + _64KiB - 1) / _64KiB;
        if (llvm_wasm_memory_grow(0, growPages) == -1) {
            return failure("Failed to grow initial heap");
        }
    }

    auto pagesBaseAddress = (cast(size_t) heapStart + PageSize - 1) & ~(PageSize - 1);
    pagesBase = cast(ubyte*) pagesBaseAddress;
    auto memBytes = llvm_wasm_memory_size(0) * _64KiB;
    if (memBytes <= pagesBaseAddress) {
        return failure("No heap memory past the page area base");
    }

    // 4 KiB-aligned base and 64 KiB-granular memory size: this divides evenly
    // and the page area always ends exactly at the end of linear memory.
    numPages = cast(uint)((memBytes - pagesBaseAddress) / PageSize);

    // First page index this call grew into (a page straddling the old memory
    // end counts as touched), or numPages if it grew nothing.
    uint firstNewPage;
    if (memBytes == memBytesBefore) {
        firstNewPage = numPages;
    } else if (memBytesBefore <= pagesBaseAddress) {
        firstNewPage = 0;
    } else {
        firstNewPage = cast(uint)((memBytesBefore - pagesBaseAddress + PageSize - 1) / PageSize);
    }

    /*
     * The general multi-page map build, not a one-page shortcut: the test
     * allocator test suite re-initializes over an already-grown heap per test,
     * and WASM memory never shrinks — once anything grew the heap past one
     * map page's coverage, a one-page map would index past its own end.
     * This is the map-growth closed form without the +15 slop term: numPages
     * is already final here, so there is no pending 64 KiB rounding to cover.
     */
    auto mapPages = (numPages + (entriesPerMapPage - 1) - 1) / (entriesPerMapPage - 1);
    if (mapPages >= numPages) {
        return failure("Heap too small to hold its own page map");
    }

    mapStartPage = 0;
    mapPageCount = mapPages;
    mapCapacity = mapPages * entriesPerMapPage;
    auto map = pageMap;
    foreach (page; 0 .. mapPages) {
        writeMapPageEntry(map, page);
    }

    foreach (page; mapPages .. numPages) {
        writeFreeContEntry(page);
    }

    auto head = &pageMap[mapPages];
    head.kind = PageKind.freeRun;
    head.runLength = numPages - mapPages;
    pageMap[numPages - 1].runLength = numPages - mapPages;
    listPush(firstFreeRun, mapPages);

    // The map was just written into pages [0 .. mapPages), so they can never
    // count as untouched — even on a first-ever init that grew from nothing.
    neverTouchedFrom = firstNewPage > mapPages ? firstNewPage : mapPages;
    return success();
}

/**
 * Prints debug information about the heap.
 */
void printDebugInfo() {
    writeln("--Memory Debug Info--");
    writeln("End of Static Data: ");
    writeln(cast(size_t)&__data_end);
    writeln("Start of Heap Base: ");
    writeln(cast(size_t)&__heap_base);
    writeln("Start of Usable Heap: ");
    writeln(cast(size_t) heapStart);
    writeln("Pages Base: ");
    writeln(cast(size_t) pagesBase);
    writeln("Memory Size: ");
    writeln(llvm_wasm_memory_size(0) * _64KiB);
    writeln("Logical Pages: ");
    writeln(numPages);
    writeln("Page Map Pages: ");
    writeln(mapPageCount);
    writeln("Never Touched From Page: ");
    writeln(neverTouchedFrom);
    writeln("--End of Memory Debug Info--");
}

/**
 * Wipe the complete heap.
 * Used for testing purposes only.
 */
void wipeHeap() {
    memset(heapStart, 0, heapSize);
}

// Debug dump of the page map, one line group per region. Printing numbers
// from inside the allocator is safe on WASM: writeErrLn dispatches to JS
// imports and never allocates.
void dumpPageMap() {
    writeErrLn("-- page map dump --");
    writeErrLn("numPages:");
    writeErrLn(numPages);
    uint page = 0;
    while (page < numPages) {
        auto entry = &pageMap[page];
        writeErrLn("page:");
        writeErrLn(page);
        switch (entry.kind) {
        case PageKind.freeRun:
            writeErrLn("  freeRun, length:");
            writeErrLn(entry.runLength);
            page += entry.runLength > 0 ? entry.runLength : 1;
            break;
        case PageKind.smallPage:
            writeErrLn("  smallPage, class size:");
            writeErrLn(cast(uint) classSizes[entry.sizeClass]);
            writeErrLn("  used slots:");
            writeErrLn(cast(uint) entry.usedSlots);
            page++;
            break;
        case PageKind.largeStart:
            writeErrLn("  largeStart, pages:");
            writeErrLn(entry.runLength);
            page += entry.runLength > 0 ? entry.runLength : 1;
            break;
        case PageKind.metadata:
            if (entry.sizeClass == cast(ubyte) MetaKind.pageMap) {
                writeErrLn("  metadata: page map");
            } else if (entry.sizeClass == cast(ubyte) MetaKind.cellPool) {
                writeErrLn("  metadata: bitmap cell pool, used cells:");
                writeErrLn(cast(uint) entry.usedSlots);
            } else {
                writeErrLn("  metadata: shadow cell pool, used cells:");
                writeErrLn(cast(uint) entry.usedSlots);
            }

            page++;
            break;
        case PageKind.freeCont:
            writeErrLn("  freeCont (unexpected at region start!)");
            page++;
            break;
        case PageKind.largeCont:
            writeErrLn("  largeCont (unexpected at region start!)");
            page++;
            break;
        default:
            writeErrLn("  unknown kind!");
            page++;
            break;
        }
    }

    writeErrLn("-- end page map dump --");
}

/*
 * Walks the whole map and the free-run list and traps on any broken
 * invariant: runs must tile the page area without overlap, mirrors must agree
 * with heads, interiors must carry the right continuation kind, small-page
 * bitmaps must agree with usedSlots, and the free-run list must contain
 * exactly the freeRun heads the map shows.
 */
private void checkHeapInvariants() {
    uint page = 0;
    uint freeRunHeads = 0;
    while (page < numPages) {
        auto entry = &pageMap[page];
        switch (entry.kind) {
        case PageKind.freeRun: {
                auto length = entry.runLength;
                if (length == 0 || page + length > numPages) {
                    trapInternal("invariant: free run length out of bounds");
                }

                if (pageMap[page + length - 1].runLength != length) {
                    trapInternal("invariant: free-run boundary mirror disagrees with head");
                }

                foreach (p; page + 1 .. page + length) {
                    if (pageMap[p].kind != PageKind.freeCont) {
                        trapInternal("invariant: free run interior is not freeCont");
                    }
                }

                freeRunHeads++;
                page += length;
                break;
            }
        case PageKind.largeStart: {
                auto length = entry.runLength;
                if (length == 0 || page + length > numPages) {
                    trapInternal("invariant: large run length out of bounds");
                }

                foreach (p; page + 1 .. page + length) {
                    if (pageMap[p].kind != PageKind.largeCont || pageMap[p].runStart != page) {
                        trapInternal("invariant: large run interior is not largeCont/runStart");
                    }
                }

                page += length;
                break;
            }
        case PageKind.smallPage: {
                auto slots = slotsPerPage(entry.sizeClass);
                if (entry.usedSlots > slots || entry.bumpIndex > slots) {
                    trapInternal("invariant: small page slot counts out of range");
                }

                if ((entry.slotState & CellIdMask) == NoCell) {
                    trapInternal("invariant: small page without bitmap cell");
                }

                if (bitmapPopCount(bitmapOf(entry), slots) != entry.usedSlots) {
                    trapInternal("invariant: bitmap population disagrees with usedSlots");
                }

                page++;
                break;
            }
        case PageKind.metadata:
            page++;
            break;
        case PageKind.freeCont:
            trapInternal("invariant: orphan freeCont at region start");
            break;
        case PageKind.largeCont:
            trapInternal("invariant: orphan largeCont at region start");
            break;
        default:
            trapInternal("invariant: unknown page kind");
            break;
        }
    }

    uint listCount = 0;
    auto run = firstFreeRun;
    auto prev = NoPage;
    while (run != NoPage) {
        if (run >= numPages || pageMap[run].kind != PageKind.freeRun) {
            trapInternal("invariant: free-run list node is not a freeRun head");
        }

        if (pageMap[run].prev != prev) {
            trapInternal("invariant: free-run list prev link broken");
        }

        listCount++;
        if (listCount > numPages) {
            trapInternal("invariant: free-run list cycle");
        }

        prev = run;
        run = pageMap[run].next;
    }

    if (listCount != freeRunHeads) {
        trapInternal("invariant: free-run list does not match the map");
    }
}

version (UnitTesting)  :  ///

version (WasmMemTest)  :  //
import retrograde.std.test : test, writeSection;

private uint pageIndexOfPtr(const void* ptr) {
    return cast(uint)((cast(const ubyte*) ptr - pagesBase) >> PageShift);
}

// Consumes every free run (leaks on purpose; memTest re-inits per test).
private void allocateAllFreeSpace() {
    while (firstFreeRun != NoPage) {
        auto length = pageMap[firstFreeRun].runLength;
        auto ptr = malloc(cast(size_t) length * PageSize);
        assert(ptr !is null);
    }
}

private __gshared ubyte staticProbeByte;

/*
 * Run one allocator test on a heap rebuilt from nothing. These tests leak whole
 * free runs on purpose, clobber the page map and shift heapOffset, so each one
 * needs the heap handed back to it intact. Only this suite gets the treatment:
 * the shared harness leaves the heap alone, so every other suite frees its
 * memory the same way it does on native.
 */
private void memTest(string name, void function() testFunc) {
    resetHeap();
    test(name, testFunc);
}

private void resetHeap() {
    wipeHeap();
    initializeHeapMemory();
}

void runWasmMemTests() {
    writeSection("-- Low-level WASM memory tests --");

    memTest("Initial heap size is usable", {
        // This fill clobbers the page map; it stays harmless only because no
        // allocator call happens after it (memTest re-inits for the next one).
        foreach (i; 0 .. heapSize) {
            heapStart[i] = 42;
        }

        foreach (i; 0 .. heapSize) {
            assert(heapStart[i] == 42);
        }
    });

    memTest("initializeHeapMemory builds a map and one free run", {
        assert(pagesBase !is null);
        assert((cast(size_t) pagesBase & (PageSize - 1)) == 0);
        assert(numPages > 0);
        assert(mapStartPage == 0);
        assert(mapPageCount >= 1);
        assert(mapCapacity >= numPages);
        assert(firstFreeRun == mapPageCount);
        assert(pageMap[firstFreeRun].kind == PageKind.freeRun);
        assert(pageMap[firstFreeRun].runLength == numPages - mapPageCount);
        assert(pageMap[numPages - 1].runLength == numPages - mapPageCount);
        // Re-initialization over an existing heap must mark everything touched.
        assert(neverTouchedFrom == numPages);
        checkHeapInvariants();
    });

    memTest("initializeHeapMemory with offset initializes the heap at the offset", {
        initializeHeapMemory(10);
        assert(heapStart is &__heap_base + 10);
        assert((cast(size_t) pagesBase & (PageSize - 1)) == 0);
        assert(cast(ubyte*) pagesBase >= heapStart);
        auto ptr = malloc(100);
        assert(ptr !is null);
        free(ptr);
        checkHeapInvariants();
    });

    memTest("malloc returns a null pointer when the given size is 0", {
        assert(malloc(0) is null);
    });

    memTest("malloc refuses a size that would overflow page rounding", {
        assert(malloc(size_t.max) is null);
        assert(malloc(size_t.max - PageSize + 2) is null);
        // Largest size that passes the guard: fails as OOM (growHeap refuses
        // to wrap its own wasm-page rounding) and must leave the heap intact.
        assert(malloc(size_t.max - PageSize + 1) is null);
        checkHeapInvariants();
    });

    memTest("malloc rounds small sizes up to their size class", {
        auto ptr = malloc(100);
        assert(ptr !is null);
        auto entry = &pageMap[pageIndexOfPtr(ptr)];
        assert(entry.kind == PageKind.smallPage);
        assert(classSizes[entry.sizeClass] == 112);
        assert(entry.usedSlots == 1);
    });

    memTest("malloc returns pointers aligned to at least 8 bytes", {
        size_t[15] sizes = [1, 2, 3, 7, 8, 9, 24, 25, 100, 128, 129, 255, 1000, 1793, 2048];
        foreach (size; sizes) {
            auto ptr = malloc(size);
            assert(ptr !is null);
            assert((cast(size_t) ptr & 7) == 0);
        }
    });

    memTest("small allocations are distinct and hold their data", {
        ubyte*[20] ptrs;
        foreach (i; 0 .. ptrs.length) {
            ptrs[i] = cast(ubyte*) malloc(24);
            assert(ptrs[i] !is null);
            memset(ptrs[i], cast(int) i + 1, 24);
        }

        foreach (i; 0 .. ptrs.length) {
            foreach (b; 0 .. 24) {
                assert(ptrs[i][b] == cast(ubyte)(i + 1));
            }
        }

        checkHeapInvariants();
    });

    memTest("freed slots are reused before fresh ones", {
        // Two live slots keep the page partial; freeing one puts it at the
        // freelist head and the next malloc of the class must return it.
        auto a = malloc(32);
        auto b = malloc(32);
        assert(a !is null && b !is null);
        free(a);
        auto c = malloc(32);
        assert(c is a);
        free(b);
        free(c);
    });

    memTest("a full small page leaves the partial list and returns on free", {
        // Class 2048 has exactly 2 slots per page.
        auto sizeClass = sizeToClass(2048);
        auto a = malloc(2048);
        auto b = malloc(2048);
        assert(a !is null && b !is null);
        auto page = pageIndexOfPtr(a);
        assert(page == pageIndexOfPtr(b));
        assert(pageMap[page].usedSlots == 2);
        assert(partialPages[sizeClass] != page);

        free(a);
        assert(partialPages[sizeClass] == page);
        assert(pageMap[page].usedSlots == 1);
        free(b);
        checkHeapInvariants();
    });

    memTest("free(null) is a silent no-op", {
        free(null);
    });

    memTest("free rejects non-heap pointers", {
        free(&staticProbeByte);
        int stackLocal;
        free(&stackLocal);
        checkHeapInvariants();
    });

    memTest("free rejects interior small pointers exactly", {
        auto ptr = cast(ubyte*) malloc(100);
        assert(ptr !is null);
        free(ptr + 1);
        auto entry = &pageMap[pageIndexOfPtr(ptr)];
        assert(entry.usedSlots == 1);
        assert(bitmapTest(bitmapOf(entry), 0));
        free(ptr);
    });

    memTest("free detects a double free of a small slot exactly", {
        auto a = malloc(64);
        auto b = malloc(64);
        assert(a !is null && b !is null);
        free(a);
        auto page = pageIndexOfPtr(b);
        assert(pageMap[page].usedSlots == 1);
        free(a); // double free: rejected, nothing changes
        assert(pageMap[page].kind == PageKind.smallPage);
        assert(pageMap[page].usedSlots == 1);
        free(b);
        checkHeapInvariants();
    });

    memTest("free rejects pointers into free pages and metadata", {
        auto ptr = malloc(3 * PageSize);
        assert(ptr !is null);
        free(ptr);
        free(ptr); // whole page area is a free run now: rejected
        assert(pageMap[pageIndexOfPtr(ptr)].kind == PageKind.freeRun);
        free(pagesBase + mapStartPage * PageSize); // page map itself
        checkHeapInvariants();
    });

    memTest("freeing the last slot converts the page back to a free run", {
        auto runStart = firstFreeRun;
        auto runLength = pageMap[firstFreeRun].runLength;
        auto ptr = malloc(100);
        assert(ptr !is null);
        assert(firstCellPoolPage != NoPage);
        free(ptr);

        // The small page, its bitmap pool page (and under MemoryDebug the
        // shadow pool page) all reclaim and coalesce back into one run.
        assert(firstCellPoolPage == NoPage);
        version (MemoryDebug) {
            assert(firstShadowPoolPage == NoPage);
        }

        assert(firstFreeRun == runStart);
        assert(pageMap[runStart].runLength == runLength);
        assert(pageMap[runStart + runLength - 1].runLength == runLength);
        checkHeapInvariants();
    });

    memTest("free preserves slot contents past the free-list link", {
        auto ptr = cast(ubyte*) malloc(10);
        assert(ptr !is null);
        memset(ptr, 'X', 10);
        free(ptr);
        // The first two bytes now hold the intrusive free-list link; the rest
        // of the slot is untouched by free.
        foreach (i; 2 .. 10) {
            assert(ptr[i] == 'X');
        }
    });

    memTest("malloc serves large allocations as whole page runs", {
        auto ptr = malloc(3 * PageSize - 100);
        assert(ptr !is null);
        assert((cast(size_t)(cast(ubyte*) ptr - pagesBase) & (PageSize - 1)) == 0);
        auto page = pageIndexOfPtr(ptr);
        assert(pageMap[page].kind == PageKind.largeStart);
        assert(pageMap[page].runLength == 3);
        assert(pageMap[page + 1].kind == PageKind.largeCont);
        assert(pageMap[page + 1].runStart == page);
        assert(pageMap[page + 2].kind == PageKind.largeCont);
        checkHeapInvariants();
        free(ptr);
        checkHeapInvariants();
    });

    memTest("large runs hold data across their whole extent", {
        auto size = 2 * PageSize + 100;
        auto ptr = cast(ubyte*) malloc(size);
        assert(ptr !is null);
        memset(ptr, 0xAB, size);
        assert(ptr[0] == 0xAB);
        assert(ptr[size - 1] == 0xAB);
        free(ptr);
    });

    memTest("free rejects interior pointers of large runs", {
        auto ptr = cast(ubyte*) malloc(3 * PageSize);
        assert(ptr !is null);
        auto page = pageIndexOfPtr(ptr);
        free(ptr + 1); // interior of the largeStart page
        assert(pageMap[page].kind == PageKind.largeStart);
        free(ptr + PageSize); // largeCont page
        assert(pageMap[page].kind == PageKind.largeStart);
        free(ptr);
        assert(pageMap[page].kind != PageKind.largeStart);
        checkHeapInvariants();
    });

    memTest("adjacent free runs coalesce into one", {
        auto originalStart = firstFreeRun;
        auto originalLength = pageMap[firstFreeRun].runLength;
        auto a = malloc(PageSize);
        auto b = malloc(PageSize);
        auto c = malloc(PageSize);
        assert(a !is null && b !is null && c !is null);
        auto pageA = pageIndexOfPtr(a);
        assert(pageIndexOfPtr(b) == pageA + 1);
        assert(pageIndexOfPtr(c) == pageA + 2);

        free(a);
        free(c);
        assert(pageMap[pageA].runLength == 1);
        free(b); // merges predecessor, successor and the trailing remainder

        assert(firstFreeRun == originalStart);
        assert(pageMap[originalStart].runLength == originalLength);
        assert(pageMap[originalStart + originalLength - 1].runLength == originalLength);
        checkHeapInvariants();
    });

    memTest("the bitmap cell pool page fills, unlinks and relinks", {
        // 64 small pages fill one 64-cell bitmap pool page. Class 2048 has
        // 2 slots per page, so 128 allocations claim exactly 64 pages.
        ubyte*[128] ptrs;
        foreach (i; 0 .. 128) {
            ptrs[i] = cast(ubyte*) malloc(2048);
            assert(ptrs[i] !is null);
        }

        assert(firstCellPoolPage == NoPage); // pool page full: off the list

        // Freeing both slots of one small page reclaims it, releasing its
        // cell: the pool page returns to the list.
        free(ptrs[0]);
        free(ptrs[1]);
        assert(firstCellPoolPage != NoPage);
        assert(pageMap[firstCellPoolPage].kind == PageKind.metadata);
        assert(pageMap[firstCellPoolPage].sizeClass == cast(ubyte) MetaKind.cellPool);
        assert(pageMap[firstCellPoolPage].usedSlots == 63);

        foreach (i; 2 .. 128) {
            free(ptrs[i]);
        }

        assert(firstCellPoolPage == NoPage);
        checkHeapInvariants();
    });

    memTest("calloc refuses multiplication overflow", {
        assert(calloc(size_t.max / 2, 3) is null);
        assert(calloc(0, 10) is null);
        assert(calloc(10, 0) is null);
    });

    memTest("calloc clears recycled small slots", {
        auto ptr = cast(ubyte*) malloc(10 * uint.sizeof);
        assert(ptr !is null);
        memset(ptr, 0xFF, 10 * uint.sizeof);
        free(ptr);

        // Sanity check: the freed memory comes back dirty (only the first two
        // bytes were overwritten by the free-list link / fresh-page bump).
        ptr = cast(ubyte*) malloc(10 * uint.sizeof);
        foreach (i; 2 .. 10 * uint.sizeof) {
            assert(ptr[i] == 0xFF);
        }

        free(ptr);
        version (MemoryDebug) {
            auto skipsBefore = callocMemsetSkips;
        }

        ptr = cast(ubyte*) calloc(10, uint.sizeof);
        assert(ptr !is null);
        foreach (i; 0 .. 10 * uint.sizeof) {
            assert(ptr[i] == 0);
        }

        version (MemoryDebug) {
            assert(callocMemsetSkips == skipsBefore); // recycled: memset, not skipped
        }
    });

    memTest("calloc clears a recycled large run", {
        auto size = 3 * PageSize;
        auto ptr = cast(ubyte*) malloc(size);
        assert(ptr !is null);
        memset(ptr, 0xFF, size);
        free(ptr);
        version (MemoryDebug) {
            auto skipsBefore = callocMemsetSkips;
        }

        ptr = cast(ubyte*) calloc(1, size);
        assert(ptr !is null);
        foreach (i; 0 .. size) {
            assert(ptr[i] == 0);
        }

        version (MemoryDebug) {
            assert(callocMemsetSkips == skipsBefore);
        }

        free(ptr);
    });

    memTest("calloc skips the memset only on never-touched fresh pages", {
        // Re-init marked everything touched, so first occupy all existing
        // free space; the growth that follows delivers provably-zero pages.
        allocateAllFreeSpace();
        version (MemoryDebug) {
            auto skipsBefore = callocMemsetSkips;
        }

        auto size = 16 * PageSize;
        auto ptr = cast(ubyte*) calloc(1, size);
        assert(ptr !is null);
        foreach (i; 0 .. size) {
            assert(ptr[i] == 0);
        }

        version (MemoryDebug) {
            assert(callocMemsetSkips == skipsBefore + 1);
        }

        free(ptr);
        checkHeapInvariants();
    });

    memTest("calloc small takes the bump zero-skip on a fresh page and never on the freelist", {
        allocateAllFreeSpace();
        version (MemoryDebug) {
            auto skipsBefore = callocMemsetSkips;
        }

        // Fresh page for this class comes from freshly grown memory.
        auto a = cast(ubyte*) calloc(1, 100);
        assert(a !is null);
        foreach (i; 0 .. 100) {
            assert(a[i] == 0);
        }

        version (MemoryDebug) {
            assert(callocMemsetSkips == skipsBefore + 1);
        }

        // Keep the page partial so the freed slot returns via the freelist.
        auto keep = malloc(100);
        assert(keep !is null);
        memset(a, 0xFF, 100);
        free(a);
        version (MemoryDebug) {
            auto skipsMid = callocMemsetSkips;
        }

        auto b = cast(ubyte*) calloc(1, 100);
        assert(b is a); // freelist head
        foreach (i; 0 .. 100) {
            assert(b[i] == 0);
        }

        version (MemoryDebug) {
            assert(callocMemsetSkips == skipsMid); // freelist slot: always memset
        }

        checkHeapInvariants();
    });

    memTest("realloc simply mallocs when the given pointer is null", {
        auto ptr = realloc(null, 10);
        assert(ptr !is null);
        auto entry = &pageMap[pageIndexOfPtr(ptr)];
        assert(entry.kind == PageKind.smallPage);
        free(ptr);
    });

    memTest("realloc frees and returns a null pointer when newSize is 0", {
        auto ptr = malloc(10);
        assert(ptr !is null);
        auto newPtr = realloc(ptr, 0);
        assert(newPtr is null);
        assert(heapAllocationInfo(ptr).kind == HeapPointerKind.freed);
    });

    memTest("realloc stays in place within the same size class", {
        auto ptr = malloc(10); // class 16
        assert(ptr !is null);
        assert(realloc(ptr, 10) is ptr);
        assert(realloc(ptr, 16) is ptr);
        assert(realloc(ptr, 11) is ptr);
        assert(realloc(ptr, 9) is ptr);
        free(ptr);
    });

    memTest("realloc moves to a new slot when the class changes and preserves contents", {
        auto ptr = cast(ubyte*) malloc(16);
        assert(ptr !is null);
        memset(ptr, 0xEE, 16);
        auto grown = cast(ubyte*) realloc(ptr, 17); // class 24
        assert(grown !is null);
        assert(grown !is ptr);
        foreach (i; 0 .. 16) {
            assert(grown[i] == 0xEE);
        }

        auto shrunk = cast(ubyte*) realloc(grown, 8); // class 8
        assert(shrunk !is null);
        assert(shrunk !is grown);
        foreach (i; 0 .. 8) {
            assert(shrunk[i] == 0xEE);
        }

        free(shrunk);
        checkHeapInvariants();
    });

    memTest("realloc grows a small allocation into a large run and back", {
        auto ptr = cast(ubyte*) malloc(100);
        assert(ptr !is null);
        memset(ptr, 0x5A, 100);
        auto large = cast(ubyte*) realloc(ptr, 3000);
        assert(large !is null);
        assert(pageMap[pageIndexOfPtr(large)].kind == PageKind.largeStart);
        foreach (i; 0 .. 100) {
            assert(large[i] == 0x5A);
        }

        auto small = cast(ubyte*) realloc(large, 50);
        assert(small !is null);
        assert(pageMap[pageIndexOfPtr(small)].kind == PageKind.smallPage);
        foreach (i; 0 .. 50) {
            assert(small[i] == 0x5A);
        }

        free(small);
        checkHeapInvariants();
    });

    memTest("realloc keeps a large run in place when the page count is unchanged", {
        auto ptr = malloc(2 * PageSize);
        assert(ptr !is null);
        assert(realloc(ptr, 2 * PageSize - 100) is ptr);
        assert(realloc(ptr, PageSize + 1) is ptr);
        assert(pageMap[pageIndexOfPtr(ptr)].runLength == 2);
        free(ptr);
    });

    memTest("realloc shrinks a large run in place and frees the tail", {
        auto ptr = malloc(4 * PageSize);
        assert(ptr !is null);
        auto page = pageIndexOfPtr(ptr);
        assert(realloc(ptr, 2 * PageSize) is ptr);
        assert(pageMap[page].runLength == 2);
        assert(pageMap[page + 2].kind == PageKind.freeRun);
        checkHeapInvariants();
        free(ptr);
        checkHeapInvariants();
    });

    memTest("realloc grows a large run in place by partially absorbing the following run", {
        auto ptr = cast(ubyte*) malloc(2 * PageSize);
        assert(ptr !is null);
        memset(ptr, 0x77, 2 * PageSize);
        auto page = pageIndexOfPtr(ptr);
        assert(pageMap[page + 2].kind == PageKind.freeRun);
        auto remainderBefore = pageMap[page + 2].runLength;
        assert(remainderBefore > 2);

        assert(realloc(ptr, 3 * PageSize) is ptr);
        assert(pageMap[page].runLength == 3);
        assert(pageMap[page + 2].kind == PageKind.largeCont);
        assert(pageMap[page + 2].runStart == page);
        assert(ptr[0] == 0x77);
        assert(ptr[2 * PageSize - 1] == 0x77);

        // The partial absorb must re-head the remainder and rewrite the
        // boundary mirror at its far end.
        auto newRemainder = page + 3;
        assert(pageMap[newRemainder].kind == PageKind.freeRun);
        assert(pageMap[newRemainder].runLength == remainderBefore - 1);
        assert(pageMap[newRemainder + pageMap[newRemainder].runLength - 1].runLength
                == remainderBefore - 1);
        checkHeapInvariants();
        free(ptr);
        checkHeapInvariants();
    });

    memTest("realloc moves a large run when no adjacent free run fits", {
        auto ptr = cast(ubyte*) malloc(PageSize);
        assert(ptr !is null);
        memset(ptr, 0x33, PageSize);
        auto blocker = malloc(PageSize); // occupies the directly following page
        assert(blocker !is null);
        assert(pageIndexOfPtr(blocker) == pageIndexOfPtr(ptr) + 1);

        auto moved = cast(ubyte*) realloc(ptr, 2 * PageSize);
        assert(moved !is null);
        assert(moved !is ptr);
        foreach (i; 0 .. PageSize) {
            assert(moved[i] == 0x33);
        }

        free(moved);
        free(blocker);
        checkHeapInvariants();
    });

    memTest("realloc rejects interior and freed pointers", {
        auto ptr = cast(ubyte*) malloc(100);
        assert(ptr !is null);
        assert(realloc(ptr + 1, 200) is null);
        auto other = malloc(100); // keeps the page alive after the free below
        assert(other !is null);
        free(ptr);
        assert(realloc(ptr, 200) is null);
        free(other);

        auto large = cast(ubyte*) malloc(2 * PageSize);
        assert(large !is null);
        assert(realloc(large + PageSize, PageSize) is null);
        free(large);
    });

    memTest("free_sized frees when the size matches the allocation", {
        auto ptr = malloc(100);
        assert(ptr !is null);
        free_sized(ptr, 100);
        assert(heapAllocationInfo(ptr).kind == HeapPointerKind.freed);

        auto large = malloc(3 * PageSize - 50);
        assert(large !is null);
        free_sized(large, 3 * PageSize - 50);
        assert(heapAllocationInfo(large).kind == HeapPointerKind.freed);
        checkHeapInvariants();
    });

    memTest("free_sized rejects a size that does not match", {
        auto ptr = malloc(100); // class 112
        assert(ptr !is null);
        free_sized(ptr, 300); // wrong in every build
        assert(heapAllocationInfo(ptr).kind == HeapPointerKind.live);

        version (MemoryDebug) {
            // Byte-exact under MemoryDebug: same class, different size — rejected.
            free_sized(ptr, 112);
            assert(heapAllocationInfo(ptr).kind == HeapPointerKind.live);
            free_sized(ptr, 100);
        } else {
            // Class-granular in release: any size in the same class passes.
            free_sized(ptr, 112);
        }

        assert(heapAllocationInfo(ptr).kind == HeapPointerKind.freed);

        auto large = malloc(3 * PageSize);
        assert(large !is null);
        free_sized(large, PageSize); // wrong page count
        assert(heapAllocationInfo(large).kind == HeapPointerKind.live);
        free_sized(large, 3 * PageSize);
        assert(heapAllocationInfo(large).kind == HeapPointerKind.freed);
    });

    memTest("memset sets memory", {
        string str = "Hello World!";
        auto ret = memset(cast(ubyte*) str.ptr, '-', 5);
        assert(ret is cast(ubyte*) str.ptr);
        assert(str == "----- World!");
    });

    memTest("memset handles unaligned starts and word-sized bodies", {
        auto ptr = cast(ubyte*) malloc(64);
        assert(ptr !is null);
        memset(ptr, 0, 64);
        memset(ptr + 1, 0xAA, 61);
        assert(ptr[0] == 0);
        foreach (i; 1 .. 62) {
            assert(ptr[i] == 0xAA);
        }

        assert(ptr[62] == 0);
        assert(ptr[63] == 0);
        free(ptr);
    });

    memTest("memcmp compares two sequences of memory", {
        auto ptr1 = malloc(10);
        auto ptr2 = malloc(10);
        assert(ptr1 !is null);
        assert(ptr1 !is ptr2);

        memset(ptr1, '$', 10);
        memset(ptr2, '$', 10);
        assert(memcmp(ptr1, ptr2, 10) == 0);

        memset(ptr2, '#', 10);
        assert(memcmp(ptr1, ptr2, 10) > 0);

        memset(ptr2, '%', 10);
        assert(memcmp(ptr1, ptr2, 10) < 0);
    });

    memTest("memcpy copies src into dest", {
        auto ptr1 = cast(ubyte*) malloc(2);
        auto ptr2 = cast(ubyte*) calloc(1, 2);
        ptr1[0] = 'H';
        ptr1[1] = 'I';
        assert(ptr2[0] == 0);
        assert(ptr2[1] == 0);
        memcpy(ptr2, ptr1, 2);
        assert(ptr2[0] == 'H');
        assert(ptr2[1] == 'I');
    });

    memTest("memmove copies src into dest", {
        auto ptr1 = cast(ubyte*) malloc(2);
        auto ptr2 = cast(ubyte*) calloc(1, 2);
        ptr1[0] = 'H';
        ptr1[1] = 'I';
        assert(ptr2[0] == 0);
        assert(ptr2[1] == 0);
        auto ret = memmove(ptr2, ptr1, 2);
        assert(ret is ptr2);
        assert(ptr2[0] == 'H');
        assert(ptr2[1] == 'I');
    });

    memTest("memmove returns dest for zero count", {
        auto ptr = cast(ubyte*) malloc(4);
        auto ret = memmove(ptr, ptr, 0);
        assert(ret is ptr);
    });

    memTest("memmove handles forward overlap correctly", {
        auto ptr = cast(ubyte*) malloc(10);
        ptr[0] = 'A';
        ptr[1] = 'B';
        ptr[2] = 'C';
        ptr[3] = 'D';
        ptr[4] = 'E';
        // Copy [0..4] to [2..6] — dest > src, overlapping
        memmove(ptr + 2, ptr, 4);
        assert(ptr[0] == 'A');
        assert(ptr[1] == 'B');
        assert(ptr[2] == 'A');
        assert(ptr[3] == 'B');
        assert(ptr[4] == 'C');
        assert(ptr[5] == 'D');
    });

    memTest("memmove handles backward overlap correctly", {
        auto ptr = cast(ubyte*) malloc(10);
        ptr[2] = 'A';
        ptr[3] = 'B';
        ptr[4] = 'C';
        ptr[5] = 'D';
        // Copy [2..6] to [0..4] — dest < src, overlapping
        memmove(ptr, ptr + 2, 4);
        assert(ptr[0] == 'A');
        assert(ptr[1] == 'B');
        assert(ptr[2] == 'C');
        assert(ptr[3] == 'D');
    });

    memTest("memmove bounds-checks src against the allocation", {
        auto ptr1 = cast(ubyte*) malloc(2); // class 8
        auto ptr2 = cast(ubyte*) calloc(1, 100);
        ptr1[0] = 'H';
        ptr1[1] = 'I';
        version (MemoryDebug) {
            // The requested-size shadow makes bounds byte-exact.
            auto ret = memmove(ptr2, ptr1, 5);
            assert(ret is null);
            assert(ptr2[0] == 0);
            assert(ptr2[1] == 0);
        } else {
            // Class-granular in release: within the 8-byte slot passes, past it fails.
            assert(memmove(ptr2, ptr1, 5) is ptr2);
            assert(memmove(ptr2, ptr1, 9) is null);
        }
    });

    memTest("memmove bounds-checks dest against the allocation", {
        auto ptr1 = cast(ubyte*) malloc(100);
        auto ptr2 = cast(ubyte*) malloc(2); // class 8
        memset(ptr1, 'X', 100);
        version (MemoryDebug) {
            auto ret = memmove(ptr2, ptr1, 5);
            assert(ret is null);
        } else {
            assert(memmove(ptr2, ptr1, 5) is ptr2);
            assert(memmove(ptr2, ptr1, 9) is null);
        }

        checkHeapInvariants();
    });

    memTest("memmove through a freed pointer is rejected", {
        auto a = cast(ubyte*) malloc(16);
        auto b = cast(ubyte*) malloc(16);
        auto keep = malloc(16); // keeps the page alive
        assert(a !is null && b !is null && keep !is null);
        free(a);
        assert(memmove(b, a, 4) is null); // src freed
        assert(memmove(a, b, 4) is null); // dest freed
        free(b);
        free(keep);
    });

    memTest("memmove rejects writes into allocator metadata", {
        auto src = cast(ubyte*) malloc(16);
        assert(src !is null);
        auto mapPtr = pagesBase + cast(size_t) mapStartPage * PageSize;
        assert(memmove(mapPtr, src, 4) is null);
        free(src);
    });

    memTest("memmove works with non-heap pointers", {
        // D string literals are in static memory, not on this allocator's heap
        string str = "Hello";
        auto dest = cast(ubyte*) malloc(5);
        auto ret = memmove(dest, cast(const void*) str.ptr, 5);
        assert(ret is dest);
        assert(dest[0] == 'H');
        assert(dest[1] == 'e');
        assert(dest[2] == 'l');
        assert(dest[3] == 'l');
        assert(dest[4] == 'o');
    });

    memTest("memmove resolves interior pointers to their allocation", {
        auto ptr = cast(ubyte*) malloc(100); // class 112
        auto dest = cast(ubyte*) malloc(200);
        assert(ptr !is null && dest !is null);
        memset(ptr, 0x11, 100);

        // Within bounds from an interior offset: allowed.
        assert(memmove(dest, ptr + 90, 10) is dest);
        // Offset-relative check: 10 bytes fit from offset 90, but more than
        // capacity - offset does not.
        version (MemoryDebug) {
            assert(memmove(dest, ptr + 90, 11) is null); // 90 + 11 > 100
        } else {
            assert(memmove(dest, ptr + 90, 23) is null); // 90 + 23 > 112
        }

        free(ptr);
        free(dest);
    });

    memTest("heapAllocationInfo resolves interior pointers of small slots", {
        auto ptr = cast(ubyte*) malloc(100); // class 112
        assert(ptr !is null);
        auto info = heapAllocationInfo(ptr + 5);
        assert(info.kind == HeapPointerKind.live);
        assert(info.base is ptr);
        version (MemoryDebug) {
            assert(info.capacity == 100);
        } else {
            assert(info.capacity == 112);
        }

        free(ptr);
    });

    memTest("heapAllocationInfo resolves interior pointers of large runs in O(1)", {
        auto size = 3 * PageSize - 96;
        auto ptr = cast(ubyte*) malloc(size);
        assert(ptr !is null);
        auto info = heapAllocationInfo(ptr + 2 * PageSize + 5); // lands on a largeCont page
        assert(info.kind == HeapPointerKind.live);
        assert(info.base is ptr);
        version (MemoryDebug) {
            assert(info.capacity == size);
        } else {
            assert(info.capacity == 3 * PageSize);
        }

        auto stackLocal = 42;
        assert(heapAllocationInfo(&stackLocal).kind == HeapPointerKind.notHeap);
        assert(heapAllocationInfo(&staticProbeByte).kind == HeapPointerKind.notHeap);
        free(ptr);
    });

    version (MemoryDebug) {
        memTest("a write past the requested size trips the slack canary on free", {
            auto ptr = cast(ubyte*) malloc(100); // class 112: 12 bytes of slack
            assert(ptr !is null);
            auto violationsBefore = canaryViolations;
            ptr[100] = 0xDD; // one byte past the requested size
            free(ptr);
            assert(canaryViolations == violationsBefore + 1);
            checkHeapInvariants();
        });
    }

    memTest("growing past the map capacity relocates the map and keeps the heap intact", {
        auto probe = cast(ubyte*) malloc(48);
        assert(probe !is null);
        memset(probe, 0xBE, 48);

        auto mapStartBefore = mapStartPage;
        auto capacityBefore = mapCapacity;
        allocateAllFreeSpace();

        // Demand more pages than the current map can describe.
        auto extraPages = capacityBefore - numPages + PagesPerWasmPage;
        auto big = malloc(cast(size_t) extraPages * PageSize);
        assert(big !is null);
        assert(mapCapacity > capacityBefore);
        assert(mapCapacity >= numPages);
        assert(mapStartPage != mapStartBefore);
        assert(pageMap[mapStartPage].kind == PageKind.metadata);

        // Pointers handed out before the relocation stay valid.
        foreach (i; 0 .. 48) {
            assert(probe[i] == 0xBE);
        }

        free(probe); // the range check and slot math still hold after the move
        free(big);
        checkHeapInvariants();
    });

    memTest("calloc returns all-zero memory from every recycled region after a map relocation", {
        allocateAllFreeSpace();

        // Leave a dirty free run: with nothing else free, the map must
        // relocate into it (branch 1) when it outgrows its capacity.
        auto dirty = cast(ubyte*) malloc(8 * PageSize);
        assert(dirty !is null);
        memset(dirty, 0xFF, 8 * PageSize);
        free(dirty);

        auto mapStartBefore = mapStartPage;
        auto capacityBefore = mapCapacity;

        // Demand more pages than both the dirty run and the map capacity
        // cover: the map relocates first, then the user grow happens.
        auto extraPages = capacityBefore - numPages + 2 * PagesPerWasmPage + 16;
        auto big = malloc(cast(size_t) extraPages * PageSize);
        assert(big !is null);
        assert(mapStartPage != mapStartBefore);
        free(big);

        // Sweep every free run — the released old map region, the dirty
        // leftovers, the fresh pages — and demand zeros from calloc.
        while (firstFreeRun != NoPage) {
            auto length = pageMap[firstFreeRun].runLength;
            auto bytes = cast(size_t) length * PageSize;
            auto ptr = cast(ubyte*) calloc(1, bytes);
            assert(ptr !is null);
            foreach (i; 0 .. bytes) {
                assert(ptr[i] == 0);
            }
        }

        checkHeapInvariants();
    });

    memTest("calloc zeroes a region that held a released cell-pool page", {
        version (MemoryDebug) {
            auto skipsBefore = callocMemsetSkips;
        }

        // One small allocation claims a small page plus pool page(s); freeing
        // it releases them all with allocator bytes still inside.
        auto small = malloc(100);
        assert(small !is null);
        auto poolPage = firstCellPoolPage;
        assert(poolPage != NoPage);
        free(small);
        assert(firstCellPoolPage == NoPage);

        auto bytes = cast(size_t) 4 * PageSize;
        auto ptr = cast(ubyte*) calloc(1, bytes);
        assert(ptr !is null);
        assert(pageIndexOfPtr(ptr) <= poolPage);
        assert(poolPage < pageIndexOfPtr(ptr) + 4);
        foreach (i; 0 .. bytes) {
            assert(ptr[i] == 0);
        }

        version (MemoryDebug) {
            assert(callocMemsetSkips == skipsBefore); // recycled: never skipped
        }

        free(ptr);
    });

    memTest("re-initialization over a heap larger than one map page's coverage builds a multi-page map", {
        // Grow well past what a single map page can describe, then re-init.
        auto needed = cast(size_t)(entriesPerMapPage + 32) * PageSize;
        auto big = malloc(needed);
        assert(big !is null);
        free(big);

        auto res = initializeHeapMemory();
        assert(res.isSuccessful);
        assert(numPages > entriesPerMapPage);
        assert(mapPageCount >= 2);
        assert(mapCapacity >= numPages);
        assert(neverTouchedFrom == numPages);

        auto ptr = cast(ubyte*) malloc(100);
        assert(ptr !is null);
        memset(ptr, 0xCD, 100);
        assert(ptr[99] == 0xCD);
        free(ptr);
        checkHeapInvariants();
    });

    // The last test leaves the heap however it pleases: leaked, clobbered, or
    // based at a shifted offset. Hand the suites that follow a sane allocator.
    resetHeap();
}
