# TODO: Replace the WASM block allocator with size-class pages + page map (Option C)

**Status: ready for implementation.** Before writing any code, read
"Implementation notes (toolchain and harness)" — environment facts not
derivable from this document — and follow "Implementation workflow" for the
build/test/iterate loop, both near the end of this document.

Target: `source/retrograde/wasm/memory.d`. The public `extern (C)` surface
(`malloc`, `calloc`, `realloc`, `free`, `free_sized`, `memset`, `memcmp`,
`memcpy`, `memmove`) and the module API (`initializeHeapMemory`, `wipeHeap`,
`printDebugInfo`) stay; the entire block machinery behind them is replaced.

## Problem

The current allocator stores a `MemoryBlock` header **inline, directly in front
of every allocation**:

```
[ header 20B ][ user data ][ header 20B ][ user data ] ...
```

Consequences:

1. **Metadata is trivially readable and writable by users.** Anything holding a
   `void*` can step back `MemoryBlock.sizeof` bytes and read or forge a header.
   The headers are supposed to be internal, but nothing separates them from
   user-addressable data.
2. **The most common memory bug lands on allocator metadata.** Overrunning the
   end of a buffer by even one byte writes into the *next block's header*
   (`nextBlock` sits at `blockDataEnd`). Heap walking then breaks at that point:
   `findFreeBlock` stops early and coalescing stops.
3. **Block validation is heuristic, not authoritative.** `isValidBlock()` checks
   a magic (`"BLOK"`) and a checksum that is just `blockSize ^ "CHEK"`. Both are
   trivially forgeable: user data that happens to contain (or deliberately
   constructs) the magic+checksum pattern passes, `getBlock` will bless such a
   pointer, and `free` will corrupt the heap with it. There is no way to answer
   "did the allocator hand out exactly this pointer?" with certainty.
4. **Per-allocation overhead is brutal for small objects.** On wasm32
   (`size_t` = 4) the header is 20 bytes (4 magic + 1 flag + 3 pad + 4 blockSize
   + 4 usedSize + 4 checksum). A 4-byte allocation costs 24 bytes — 500%
   overhead. `String` and `Array` make many such allocations.
5. **Allocation is O(heap).** `findFreeBlock` walks the block chain first-fit
   from `firstFreeBlock` (often from `heapStart`), coalescing as it goes. Cost
   grows with fragmentation and heap size.
6. **No alignment guarantee.** `dataStart` is `header + 20`, so returned
   pointers are at best 4-aligned, and only by accident of the header size.
7. **`realloc`-driven append is O(n²).** `blockSize` is the exact requested
   size, so growing an allocation by one byte almost always exceeds the block
   and forces malloc + memcpy + free. `String.opOpAssign!"~"(T)` reallocs on
   *every single character*.

Alternatives that were considered and rejected:

- **FAT-style cluster chains** — chaining exists so files can be
  non-contiguous; `malloc` must return contiguous memory, so chains buy
  nothing. The useful half of FAT (a table in a reserved region, one entry per
  fixed-size cell) *is* this proposal's page map.
- **Journaling** — solves crash consistency on durable storage. The heap has no
  crash-recovery story (a trapped module loses its memory), and a journal
  neither relocates metadata nor enables bounds checks; it only adds write
  amplification.
- **Side descriptor table over the existing variable-size blocks** — gets
  metadata out of band with the least redesign, but lookup becomes O(log n)
  binary search, the sorted table needs O(n) insert/remove and its own growth
  story, and none of the fragmentation/speed problems improve. Stepping stone
  at best.

## Design overview

This is the mimalloc/tcmalloc family shape, radically simplified for a
single-threaded, grow-only, contiguous linear memory.

The heap is carved into fixed **logical pages of 4 KiB** (`PageSize`). WASM
memory grows in 64 KiB units, which subdivide into exactly 16 logical pages.

- **Small allocations** (≤ `MaxSmallSize`, proposed 2048 B) are rounded up to a
  **size class** and served as fixed-size **slots** from a page dedicated to
  that class.
- **Large allocations** (> `MaxSmallSize`) take a contiguous **run of whole
  pages**, rounded up to 4 KiB.
- The only global lookup structure is the **page map**: a flat array with one
  entry per logical page, living in pages of its own (tagged `metadata`) —
  out of band for every allocation except whichever pages happen to border the
  map region itself.

Pointer → metadata is pure arithmetic:

```
pageIndex = (ptr - pagesBase) >> 12;
entry     = pageMap[pageIndex];
```

No header precedes any allocation. Nothing about an allocation is stored next
to it. The only allocator state that ever lives inside the heap pages
themselves is the intrusive free-slot list — and that is written only into
**free** slots, which by definition hold no live user data. (This is a change
in contract; see "Freed memory is no longer inert".)

One honest limit: WASM linear memory has no write protection, so the metadata
region's own edges still border ordinary heap pages — a gross overrun from
the allocation just before it can reach it. The design shrinks metadata
exposure from a boundary at *every* allocation to a handful of region
boundaries in the whole heap; it does not (and cannot) make the map
unwritable. Corruption at that scale is a caller bug to be caught at the
source — the allocator has no further tools against it, and we deliberately
do not add band-aids (e.g. guard pages) for it.

### Memory layout

```
0 ──────────────────────────────────────────────────────────────► grows
│ static data │ __heap_base │ heapOffset (default 0)           │
│ pad to 4 KiB boundary → pagesBase                             │
│ page 0..k: page map (kind=metadata)                           │
│ page k+1..N: small pages / large runs / free pages            │
│             (bitmap-pool pages, also kind=metadata, are       │
│              taken from this space on demand)                 │
```

- `pagesBase = alignUp(heapStart, PageSize)` where `heapStart` is
  `&__heap_base + heapOffset` as today. The sub-4 KiB pad is dead space paid
  once.
- `pagesBase` is 4 KiB aligned and WASM memory size is 64 KiB granular, so
  `pagesBase + numPages * PageSize` always lands exactly on the end of linear
  memory — no uncovered tail page. Bounds checks nevertheless use
  `numPages` (map coverage) rather than the memory size, so the two can never
  disagree after a partially completed grow.

### Page map entry (20 bytes, wasm32)

Plain fields, no bit packing. Map overhead is 20 / 4096 ≈ 0.5% of the heap —
a rounding error — and packing it to 8 bytes to save 0.25% was the single
largest source of implementation risk in the design (three 20-bit link fields
with no encodable sentinel, biased run lengths, pack/unpack accessors) in the
component where bugs are hardest to diagnose. If the map ever shows up in a
memory profile, the layout can be packed later behind the same accessors;
nothing else in the design depends on the width.

```d
private enum PageKind : ubyte {
    freeRun,    // first page of a run of free pages
    freeCont,   // continuation of a free run; the *last* page of a run
                // mirrors the run length (see "Free-run coalescing")
    smallPage,  // holds slots of one size class
    largeStart, // first page of a large allocation
    largeCont,  // continuation page of a large allocation
    metadata    // page map or slot-bitmap pool
}

private enum uint NoPage = uint.max;
private enum ushort NoSlot = ushort.max;
private enum uint CellIdMask = 0x03FF_FFFF; // bits 0..25
private enum uint NoCell = CellIdMask;      // 26-bit all-ones, *not* uint.max
private enum uint BumpZeroedBit = 1u << 31;

private enum MetaKind : ubyte { pageMap, cellPool } // goes in sizeClass when kind == metadata

private struct PageEntry {      // exactly 20 bytes on wasm32
    PageKind kind;              // offset  0
    ubyte sizeClass;            //         1  smallPage: index into the class table
                                //            metadata: MetaKind (pageMap or cellPool)
    ushort usedSlots;           //         2  smallPage: slots handed out
                                //            metadata/cellPool: cells handed out (0..64)
    ushort freeHead;            //         4  smallPage: first free slot, or NoSlot
                                //            metadata/cellPool: first free cell, or NoSlot
    ushort bumpIndex;           //         6  smallPage: next never-used slot
                                //            metadata/cellPool: next never-used cell
    uint next;                  //         8  smallPage: next partial page
                                //            freeRun: next free run
                                //            metadata/cellPool: next pool page with
                                //            free cells; else NoPage
    uint prev;                  //        12  smallPage: previous partial page
                                //            freeRun: previous free run
                                //            metadata/cellPool: previous such pool page;
                                //            else NoPage
    union {                     //        16
        uint slotState;         //            smallPage: bitmap cell id in bits 0..25,
                                //            bumpZeroed in bit 31; NoCell if unset
        uint runLength;         //            freeRun / largeStart: pages in the run.
                                //            freeCont: only on the run's last page.
                                //            metadata: unused (the map's extent is in
                                //            mapStartPage/mapPageCount; pool pages are
                                //            always one page).
        uint runStart;          //            largeCont: page index of the run's
                                //            largeStart page. Written when the run is
                                //            carved and when realloc absorbs pages.
    }
}
```

Every `kind` has a defined interpretation for every field, including `metadata`.
An implementation that leaves a field meaningless for some kind must say so in a
comment, because `free`, coalescing and the debug dump all read entries whose
kind they did not write.

Field order matters here — it is load-bearing, not cosmetic. The obvious
spelling (a `union` of the three `ushort`s against `uint runLength`, plus a
trailing `bool`) compiles to **28 bytes**: the union inherits `uint`'s
4-byte alignment so its 6 bytes round to 8, and the trailing `bool` costs a
padded word. Putting the `ushort`s ahead of the `uint`s and folding the
per-page flag into a spare bit of `slotState` is what makes 20 exact. Assert
`PageEntry.sizeof == 20` in the implementation so a later field addition
cannot silently inflate the map by 40%.

`slotState`, `runLength` and `runStart` never overlap in meaning: each is read
for exactly one set of kinds. `runStart` on `largeCont` is what makes interior
pointers into large runs resolve in O(1) (`heapAllocationInfo` reads it, jumps
to the `largeStart` entry, and has base + length) — without it, resolving an
interior large pointer would mean walking backwards page by page. Cell ids
occupy 26 bits (20-bit page index << 6 | 6-bit cell index), leaving bit 31
free for `bumpZeroed`.

Because `bumpZeroed` shares the word, the "no cell" sentinel **must be the
26-bit all-ones value and must be compared against the masked field**:
`(slotState & CellIdMask) == NoCell`. A `uint.max` sentinel would be
indistinguishable from "cell id all-ones with `bumpZeroed` set", and
`slotState == NoCell` as a whole-word comparison is wrong the moment
`bumpZeroed` is set on a page whose cell is not yet assigned. Never compare
`slotState` as a whole word. (The sentinel cannot collide with a real cell id:
all-ones-26 would name cell 63 of page 2^20 − 1, and page index 2^20 − 1 is
unreachable because `pagesBase > 0` keeps `numPages < 2^20` even at the wasm32
memory ceiling.)

**On sentinels.** "No page" is unavoidable as a *concept*, not just as an
encoding: at init no class owns a page yet (giving each of the 26 classes one
up front would cost 104 KiB before the first `malloc`), partial lists and the
free-run list need terminators, and the free-run list legitimately empties
when the heap is fully allocated. What the 20-byte entry buys is that the
encoding is free — page indices span at most 2^20 values while the fields are
32-bit, so `uint.max` is an unambiguous sentinel. (The 8-byte packed layout
had no spare encoding at all, since 20-bit fields cover the page index range
exactly.)

**Doubly-linked partial lists.** Because `prev` sits unused for small pages
anyway, the partial list is doubly linked at zero cost. That is what makes
eager empty-page reclamation O(1) and removes the reclamation sweep entirely
(see below).

### Slot-state bitmap (always on, all builds)

Every small page owns a 64-byte **bitmap cell**: one bit per slot, set while
the slot is handed out. 4096 / 8 = 512 is the maximum slot count, so 64 bytes
always suffices. This is not debug instrumentation — it is what keeps the
intrusive free-slot list honest, and it is enabled in release builds:

- **Exact double free.** Freeing a slot whose bit is already clear is
  detected, which the map alone cannot do.
- **Freelist corruption.** A use-after-free write into a freed slot's first
  two bytes corrupts a next-slot index. Without a check, the following
  `malloc` computes `pageBase + slot * classSize` for a wild slot and hands
  back a pointer into a *neighbouring page* — silent cross-page corruption,
  a hazard the inline-header design did not have. Every freelist pop
  validates `slot < slotsPerPage(class)` **and** that the bit is clear.

Cells live in a pool of `metadata` pages, 64 cells per page. Cell id encodes
its own location — `cellAddr = pagesBase + (id >> 6) * PageSize + (id & 63) *
64` — so the pool needs no lookup table and, unlike the page map, never has to
be contiguous and therefore **never relocates**.

**The pool reuses the small-page mechanism verbatim, one page at a time.** A
cell-pool page is a small page whose class size is 64 and whose slots are
cells, so its `PageEntry` carries `usedSlots` / `freeHead` / `bumpIndex` with
exactly the same meaning, and `next`/`prev` thread the pages **that still have
free cells** into a list headed by `firstCellPoolPage`:

- **Claim a cell:** take the head pool page; pop `freeHead` (each free cell's
  first 2 bytes hold the next free cell index *within that page*) or take
  `bumpIndex++`; `usedSlots++`; if the page is now full, unlink it. If the list
  is empty, claim a page from the free-run list, tag it `metadata` with
  `sizeClass = MetaKind.cellPool`, and push it.
  **The claimed cell must be memset to zero before use.** A recycled cell holds
  the previous owner's bits plus the freelist link, and a bump cell on a
  recycled pool page holds whatever the page held before — stale set bits mean
  spurious double-free traps, stale clear bits mean missed detection, and the
  MemoryDebug popcount cross-check reads the *whole* cell. 64 bytes, always.
- **Release a cell:** push it onto its own page's `freeHead`, `usedSlots--`;
  full → has-free means link the page back in. When `usedSlots` reaches 0,
  unlink the page and convert it to a free run, coalescing as usual.

Both are O(1) with no global cell list, no per-cell back links, and no scan to
decide whether a page is releasable — `usedSlots == 0` is the whole test. This
is the reason the earlier "intrusive global free-cell list" spelling was
dropped: releasing a page under that scheme meant finding and unlinking 64
cells scattered through one global chain, which is not O(1) unless the chain is
doubly linked, and it had nowhere to store the per-page live count.

Note that a cell-pool page's cells are *not* themselves tracked by a bitmap.
Cells are allocator-internal and never handed to a caller, so the double-free
and freelist-corruption hazards the bitmap exists to catch do not apply; a
corrupt cell index is an internal-invariant violation and traps (see "Detection
response policy").

Cost: 64 B per *small* page (1.56%), zero for large runs and free pages, plus
20 B/page of map (0.49%) — about 2.05% of the heap in an all-small-page
workload, less in anything with large runs.

Large runs need no bitmap: freeing an already-free run is caught by the kind
check alone (`freeRun`/`freeCont` is an invalid free).

### Size classes

A static table, roughly 8-byte granularity at the bottom growing ~25% per step,
capped at `MaxSmallSize = 2048` (2 slots minimum per page):

```
8, 16, 24, 32, 48, 64, 80, 96, 112, 128, 160, 192, 224, 256,
320, 384, 448, 512, 640, 768, 896, 1024, 1280, 1536, 1792, 2048
```

26 classes. `sizeToClass(size)` is a 257-entry `ubyte` table indexed by
`(size + 7) >> 3`, which covers the whole 1..2048 range exactly in 257 bytes
of static data (index 256 = 2048 B) — no branching, no search.

`slotsPerPage(class)` and the reciprocal-multiply constants used to turn
`ptr - pageBase` into a slot index are likewise static per-class tables; `free`
must not perform two runtime divisions on a non-constant class size.

**Internal fragmentation, honestly:**

| Band | Granularity | Max waste | Worst ratio | vs. today's 20 B header |
|---|---|---|---|---|
| 1–32 B | 8 | 7 B (at 25) | 700% (1 B → 8) | always better |
| 33–128 B | 16 | 15 B (at 113) | 45% (33 → 48) | always better |
| 129–256 B | 32 | 31 B (at 225) | 24% (at 129) | worse from 129 B up |
| 257–2048 B | ~25% geometric | 255 B (at 1793) | 25% (1025 → 1280) | worse |

Two things to be honest about. The worst *ratio* is at tiny requests — a 1-byte
allocation gets an 8-byte slot — but that is 7 wasted bytes against today's 20,
so it is a large ratio on a number too small to matter. And 129 B is the exact
crossover: below it, class rounding always wastes fewer bytes than today's
fixed header; at or above it, rounding costs more absolute bytes than a flat
20 B while keeping relative overhead bounded at ~25%. The 1793–2048 band
(255 B on a single allocation) is the weakest spot and is exactly what the
class-table tuning open question is for.

**A second, separate cost: page tail waste.** A class that does not divide
4096 leaves a remainder at the end of every one of its pages, on top of the
per-allocation rounding above. Most classes are fine, but the upper geometric
ones are not:

| Class | Slots/page | Tail waste | Effective cost per slot |
|---|---|---|---|
| 1536 | 2 | 1024 B (25% of the page) | 2048 B |
| 896 | 4 | 512 B (12.5%) | 1024 B |
| 1792 | 2 | 512 B (12.5%) | 2048 B |
| 320, 384, 640, 768, 1280 | 12, 10, 6, 5, 3 | 256 B (6.25%) | — |
| 8, 16, 32, 64, 128, 256, 512, 1024, 2048 | exact divisors | 0 B | — |

A 1536-byte allocation therefore occupies 2048 B of page space, which is worse
than the class rounding suggests. This is an argument for biasing the upper
half of the table toward divisors of `PageSize`; feed it into the class-table
tuning question rather than treating the table above as settled.

**Alignment guarantee:** all class sizes are multiples of 8, page bases are
4 KiB aligned → every returned pointer is at least 8-aligned (verified: no
slot in any class breaks 8-alignment, and every class that is a multiple of 16
yields 16-aligned slots throughout; only classes 8 and 24 are 8-aligned only).
This is a strict improvement and should be documented as a guarantee once
implemented.

### Global allocator state (module globals, data segment)

```d
private uint[NumSizeClasses] partialPages = NoPage; // first page with free slots per class
private uint firstFreeRun = NoPage;                 // head of the free-run list
private uint firstCellPoolPage = NoPage;            // head of the pool pages with free cells
private uint numPages;                              // pages currently covered by the map
private uint mapCapacity;                           // entries the current map region can hold
private uint mapStartPage, mapPageCount;            // where the map itself lives
private uint neverTouchedFrom;                      // pages ≥ this are provably still zero
private ubyte* pagesBase;
```

All page-index globals initialize to `NoPage`, **not** zero — zero is a valid
page index. `neverTouchedFrom` is the one exception: it is a watermark, not a
list head, and "nothing is untouched" is spelled `neverTouchedFrom == numPages`,
never `NoPage`. Two encodings of the same state is how a check ends up testing
one and missing the other, so there is only one.

Partial-page lists, the free-run list and the cell-pool page list are threaded
**through page map entries**, so list membership never touches user-visible
memory.

### Page map entries may not be cached across an allocating call

`&pageMap[i]` is valid only until the next operation that can claim a page,
because claiming a page can cascade all the way into a map relocation that
moves every entry:

```
malloc (small) → claim page from free-run list
               → claim bitmap cell
               → cell pool empty → claim pool page from free-run list
               → free-run list empty → growHeap
               → map at capacity → relocate map   ← every PageEntry* now dangles
```

So the rule is not merely "the design stores no pointers into the map"; it also
binds locals inside the allocator's own frames:

> **No `PageEntry*` (or reference, or `ref` parameter) may live across a call
> that can claim a page.** Re-index `pageMap[i]` after every such call. Page
> *indices* are stable across relocation; addresses are not.

Writing malloc's small path as `auto e = &pageMap[page];` and then claiming the
bitmap cell is the natural spelling and is wrong. The same applies to
`growHeap`, `relocateMap`, and every helper they call.

### malloc — small path (O(1))

`malloc(0)` keeps returning `null` via an explicit check, as today — class
rounding would otherwise happily serve 8 bytes.

The oversize guard is an **overflow** bound, not a capacity bound:

```d
if (size > size_t.max - PageSize + 1) { return null; }  // before any rounding
auto pages = (size + PageSize - 1) / PageSize;          // now safe
```

A request that survives the guard but is larger than the heap could ever hold
needs no special case — it fails ordinarily as an OOM out of `growHeap`. (An
earlier draft wrote this as `size > MaxLargeBytes`, "the largest run
expressible, i.e. `numPages` at the wasm32 ceiling". That value is
2^20 × 4096 = 2^32, which is not representable in a 32-bit `size_t`, so the
constant cannot exist; the overflow bound above is what actually needs
checking.)

1. `class = sizeToClass(size)`.
2. `page = partialPages[class]`; if none, carve one page off the **front** of a
   free run (see "Carving always takes from the front of a run"), claim a
   bitmap cell, and initialize its entry as `smallPage` with `bumpIndex = 0`,
   `freeHead = NoSlot`, `bumpZeroed` taken from the `wasUntouched` flag
   `carvePages` returns (**not** re-read from `neverTouchedFrom`, which the
   carve has already advanced — see calloc), then push it as the partial page.
   If no free run exists, grow the heap.
   **Order within this step:** write the page's full `smallPage` entry —
   `sizeClass`, zeroed counts, `freeHead = NoSlot`, `slotState = NoCell` with
   the `bumpZeroed` bit — *before* claiming the bitmap cell. The cell claim can
   carve a pool page, grow the heap, and relocate the map, and all of those
   walk or copy entries they did not write; the entry must already be
   self-describing when that happens. Then claim the cell and store its id.
   Claiming the bitmap cell can itself claim a page and therefore relocate the
   map — re-index `pageMap[page]` afterwards rather than holding a pointer
   across it (see the caching rule above).
3. Pop a slot: prefer `freeHead` (intrusive list — a free slot's first 2 bytes
   store the next free slot index), validating the index against
   `slotsPerPage(class)` and the bitmap; else take `bumpIndex++`. The bump
   pointer means a fresh page never needs its freelist pre-built.
4. Set the slot's bit, `usedSlots++`; if the page is now full
   (`usedSlots == slotsPerPage(class)`), unlink it from the partial list.
5. Return `pageBase + slot * classSize`.

### Failure paths must not leak or half-apply

Every step of the small path can fail with OOM, including steps that run
*after* state has already changed. The rule is that `malloc` either succeeds
or leaves the allocator exactly as it found it:

- **Cell claim fails after the page was carved** (step 2: page obtained, cell
  pool empty, no free run for a pool page, `memory.grow` refused). The carved
  page must be returned to the free-run list — coalescing as usual — before
  returning null. Leaking it is not merely wasteful: it would sit forever as a
  `smallPage` with `slotState == NoCell` and no slots, which every later
  `free`, the invariant walker and the debug dump must then treat as a
  permanent special case. Roll it back instead.
- **Map relocation fails.** Already specified under "Page map growth": the old
  map stays authoritative and the whole operation is abandoned. Nothing else
  may have been mutated before the relocation attempt.
- **`realloc` fallback `malloc` fails.** The original allocation must be left
  intact and null returned — the caller still owns its old pointer. This is
  the glibc contract and today's behaviour; do not free the old block first.

Order the small path so that as much as possible of the failure-capable work
happens before any state mutation, and roll back explicitly where it cannot.

### malloc — large path

1. `pages = ceil(size / PageSize)` (after the overflow guard above).
2. First-fit walk of the free-run list (runs, not blocks — this list is short).
   Carve the pages off the **front** of the run; tag first page `largeStart`
   with `runLength`, remaining pages `largeCont`.
3. If no run fits, grow the heap.

### Carving always takes from the front of a run

Both malloc paths, the cell pool and the map relocation take their pages from
the **low end** of the chosen free run. This is not arbitrary — back-carving is
cheaper but wrong for `calloc`:

- **List cost (favours the back).** Carving `n` pages off the front of run
  `[s..e]` moves the run's head to `s + n`, so the old head must be unlinked
  from the free-run list and the new head linked in, plus `runLength` written at
  `s + n` and the boundary mirror rewritten at `e`. Carving off the back leaves
  the head at `s` and touches no list at all — only `runLength` at `s` and the
  mirror at the new last page `e - n`.
- **`calloc` zero-skip (favours the front, and wins).** Watermark advancement is
  monotone: it can only move to one past the highest page carved. Carving `n`
  pages off the **back** of an untouched run `[s..e]` therefore forces
  `neverTouchedFrom` to `e + 1`, which marks the untouched remainder `[s..e-n]`
  as touched and permanently forfeits its zero-skip. Carving off the **front**
  advances the watermark only to `s + n` and loses nothing.

Front-carving costs a handful of field writes per carve; back-carving costs
real memsets for the rest of the session. Take the front.

The one place the direction is not free to choose is the large-`realloc`
in-place grow, which must absorb from the front of the *following* run because
that is the only run adjacent to the allocation.

### calloc — the contract first, the optimization second

The existing `nitems * size` overflow guard (`size != 0 && nitems >
size_t.max / size` → null) is part of the public contract and stays verbatim.

**`calloc` must return memory that is entirely zero, every time, without
exception.** That is the whole contract, it is what callers rely on, and it is
unconditional. Recycled memory — anything that has ever been handed to a
caller, or ever been written by the allocator itself — **must be memset before
it is returned.** The current allocator gets this right by memsetting
unconditionally; the redesign must not regress it.

Everything below is a narrow optimization *on top of* that contract, and it is
legitimate only where the memory is **provably** still in its
`memory.grow` state. The WASM spec guarantees freshly grown memory is zero, so
re-zeroing it is pure waste — and asset loading is exactly the workload that
callocs multi-MiB buffers. But the proof obligation runs one way: when in
doubt, memset. A false "already zero" is silent data corruption; a false
"needs zeroing" costs a memset nobody notices.

`neverTouchedFrom` is a monotone watermark carrying exactly one claim:

> **Every page at index ≥ `neverTouchedFrom` is still byte-for-byte as
> `memory.grow` left it: all zero.**

That claim is only maintainable if **every** path that hands out or writes a
page advances the watermark past it. Not just the two user-facing ones —
*every* one:

| Path | Advances watermark? |
|---|---|
| Large run carved for a caller | **yes** |
| Small page claimed for a size class | **yes** |
| Bitmap **cell-pool page** claimed | **yes** — cells are written into it |
| Page map pages claimed during **relocation** | **yes** — the map is copied into them |
| Initial map pages built by `initializeHeapMemory` | **yes** |

The two metadata rows are the ones that are easy to miss, and missing them is
not a lost optimization, it is a **correctness bug**: a released cell-pool page
and the old map region after a relocation both go back on the free-run list
still holding allocator bytes. If the watermark was never advanced past them
they remain "≥ watermark", and the next `calloc` large enough to land there
skips the memset and hands the caller stale map or bitmap contents. The failure
is silent, non-deterministic, and first reachable only past an 816 KiB heap —
long after any test suite has gone green.

So the watermark must not be advanced at the call sites at all. Advance it in
the **single shared helper that carves pages out of a free run**, so that no
carving path can exist that forgets to:

```d
// Sole owner of the watermark. Both page sources below call it and nothing else does.
private bool claimPages(uint firstPage, uint count) {  // returns wasUntouched
    auto wasUntouched = firstPage >= neverTouchedFrom;
    if (firstPage + count > neverTouchedFrom) {
        neverTouchedFrom = firstPage + count;
    }

    return wasUntouched;
}

private bool carvePages(uint runStart, uint count) {  // front-carve, see above
    ...                                               // unlink/split the free run
    return claimPages(runStart, count);               // relay wasUntouched
}
```

(`carvePages` returns `bool wasUntouched`, not a page index — the caller chose
the run, so it already knows the carved pages are `[runStart, runStart + count)`.)

There are exactly **two** ways a page is obtained, and both must go through
`claimPages`:

1. **`carvePages`** — carved out of a free run recorded in the current map.
   Small pages, large runs, cell-pool pages and map-relocation branch 1 all
   use this.
2. **Fresh `memory.grow` space that the current map cannot describe.** This is
   not a bug in the layering, it is unavoidable: `initializeHeapMemory` runs
   before any map exists, and map-growth branch 2 (grow to fit the new map)
   deliberately places the new map in a region the *old* map has no capacity
   to cover. In neither case is there a free run to carve from — the free-run
   list itself is being created. These paths write page entries directly and
   must call `claimPages` themselves for every page they write into (the map
   pages in both cases; the caller's large run in branch 2).

An earlier draft claimed "there is no second way to obtain a page". That is not
achievable — the bootstrap and branch 2 are exactly the second way. What *is*
achievable, and what the split above buys, is that the watermark still has one
owner. Do not attempt to route the bootstrap through `carvePages`; it has no
run to operate on and would have to fabricate one.

Because the helper advances the watermark, a caller that reads
`neverTouchedFrom` *after* calling it always sees "touched" and the skip is
dead. Rather than rely on every caller remembering to snapshot first,
`claimPages` reports it — `wasUntouched` is sampled before the update — and
`carvePages` relays that return value to its own callers. One ordering trap
removed from every call site instead of documented at each of them.

Given that, the two skips are:

- **Large:** skip the memset only if `carvePages` reported the whole run
  untouched; otherwise memset.
- **Small:** a slot obtained via the *bump* path on a page whose `bumpZeroed`
  flag is set is untouched-since-grow, so skip the memset; otherwise memset.
  Any slot obtained from `freeHead` has been handed out before and **always**
  gets memset — the freelist link alone has already dirtied its first two
  bytes. The invariant holds permanently because `bumpIndex` only moves forward
  and a slot that has been handed out once can only come back through the
  freelist, never through the bump path.

The watermark is deliberately conservative in one direction: because it is a
single monotone value, carving high out of a run strands the untouched pages
below it on the wrong side of the watermark. They get memset needlessly. That
is the safe direction and it is why front-carving matters (see above) — but a
stranded page being memset is never a bug, while the reverse always is.

`initializeHeapMemory` may only mark pages never-touched if it grew them itself
in this call **and** the initial map was not written into them; on
re-initialization over an existing heap every existing page is conservatively
marked touched (`neverTouchedFrom = numPages`). Without that rule the
`wipeHeap(); initializeHeapMemory();` test pattern and any bare re-init would
let `calloc` hand back dirty memory — `wipeHeap` zeroing the heap does *not*
license marking it untouched, because init must not depend on having been
preceded by a wipe. See the init section for the exact formula.

**Test this directly.** "calloc skips the memset on never-touched pages and does
not skip it on recycled ones" is in the migration plan, but it needs to cover
the metadata paths specifically: free a large run, force a map relocation over
it, then `calloc` the region back and assert every byte is zero. Same for a
released cell-pool page. A test that only exercises small slots and fresh
growth will pass against the broken version.

### free

0. `free(null)` stays a silent no-op (explicit check — it must not fall
   through to the range check and log as an invalid free under MemoryDebug).
1. **Range check:** `ptr` outside `[pagesBase, pagesBase + numPages * PageSize)`
   → invalid free; report and return. The bound is map coverage, not the
   memory size. The lower bound is `pagesBase`, *not* the end of the map:
   after a relocation the map can live anywhere in the heap, and pointers into
   it are rejected by the kind check in step 5 instead. This alone is a
   stronger guarantee than today's magic check.
2. `entry = pageMap[(ptr - pagesBase) >> 12]`.
3. `smallPage`: compute `slot = (ptr - pageBase) / classSize`; **require
   `(ptr - pageBase) % classSize == 0`** — exact detection of interior/bogus
   pointers, which `getBlock` can only do probabilistically today. Require the
   slot's bitmap bit to be set (exact double-free detection); clear it, push
   the slot onto `freeHead`, `usedSlots--`. Transitions: full → partial (push
   to partial-list head); `usedSlots == 0` → unlink and convert to a free run
   (see below).
4. `largeStart`: **require `(ptr - pagesBase) % PageSize == 0`** — a pointer
   into the interior of the *first* page of a large run is not the allocation
   start and must be an invalid free (report, return), exactly like an
   unaligned small pointer. The kind check alone does not catch this case:
   without the offset check, `free(base + 1)` would free the whole run. Then
   free the run, coalesce with adjacent free runs (see "Free-run coalescing").
5. `largeCont`, `freeRun`, `freeCont`, `metadata`: invalid free — report and
   return. Freeing a pointer into the middle of a large allocation is now
   *detected*, not undefined.

### Free-run coalescing (O(1))

Two entry-layout details make coalescing genuinely O(1):

- **Boundary mirror:** the last page entry of every free run duplicates the
  run length (in its `freeCont`, or in `freeRun` itself for 1-page runs).
  When pages `i..j` become free, a free `pageMap[i - 1]` yields the
  predecessor run's start directly (`i - mirroredLength`), and
  `pageMap[j + 1]` yields the successor — no walking in either direction.
  Split and merge keep the mirrors at both ends up to date.
  This rests on an invariant worth stating in the code: page `i - 1` is by
  construction always the *last* page of its run, because page `i` was not
  free before, so it always carries the mirror.
  Both probes need explicit bounds guards — skip the predecessor when
  `i == 0` (reachable once the map relocates off page 0) and the successor
  when `j + 1 == numPages`.
- **Doubly-linked free-run list:** absorbing a neighbour requires unlinking it
  from the free-run list; `prevFreeRun` makes that O(1) (singly linked it
  would be an O(#runs) predecessor search).

With neighbour lookup fully map-driven, list order is irrelevant — plain LIFO
push.

**Mirror maintenance, spelled out.** The mirror is the single easiest thing in
this design to leave stale, and a stale mirror silently mis-locates a
predecessor run — producing a "coalesce" that overlaps a live allocation. Every
operation that changes a run's extent must rewrite **both** ends. For a run
`[s..e]` of length `L`:

- **Invariant:** `pageMap[s].kind == freeRun && pageMap[s].runLength == L`, and
  `pageMap[e].runLength == L`. When `L == 1`, `s == e` and the single entry
  carries both roles.
- **Front-carve of `n` pages** (`n < L`): unlink `s` from the free-run list;
  set `pageMap[s + n]` to `freeRun` with `runLength = L - n` and link it in;
  write `runLength = L - n` at `e`. When `n == L` the run disappears — unlink
  and write no mirror. When `L - n == 1`, `s + n == e` and one entry gets both.
- **Merge** of `[a..b]` and `[b+1..c]`: unlink the successor's head from the
  list, retag `b + 1` as `freeCont`, write `runLength = c - a + 1` at `a` and
  at `c`. The old mirror at `b` becomes an interior `freeCont` and is dead —
  it must not be read again, which is guaranteed by the "page `i - 1` is always
  a run's last page" invariant above.
- **Large-`realloc` in-place grow** absorbing `n` pages from the following run
  `[b+1..c]` is the highest-risk site because it is a *partial* merge: unlink
  `b + 1`, retag `[b+1 .. b+n]` as `largeCont`, bump the `largeStart`
  `runLength`, and — if `n < c - b` — re-establish a fresh `freeRun` head at
  `b + n + 1` with the reduced length, link it in, **and rewrite the mirror at
  `c`**. Forgetting that last write is the specific bug to watch for; it leaves
  `c` claiming the pre-absorption length.

An always-on debug helper that walks the free-run list and asserts
`runLength` at head and mirror agree, and that the runs tile without overlap,
pays for itself here.

### Empty-page reclamation (eager, O(1))

When a small page's `usedSlots` reaches 0 it is unlinked from its class's
partial list, its bitmap cell is returned to the pool, and the page becomes a
free run, coalescing as usual. All of that is O(1) because the partial list is
doubly linked.

Returning the bitmap cell can empty its **pool** page, which then converts to a
free run and coalesces too — so a single `free` can perform two independent
page conversions and two coalesces. Sequence them: **read the cell id out of
`slotState` first** (converting the entry to `freeRun` overwrites the union
with `runLength`, destroying the id), then finish the small page's conversion
and coalescing completely, *then* release the saved cell, so the second
coalesce never observes a half-updated run. Both are still O(1), and the
cascade cannot go deeper than two levels (a pool page owns no bitmap cell of
its own).

This is a simplification over the earlier draft, which deferred reclamation to
a sweep under memory pressure purely because a singly-linked partial list
could not unlink an interior page cheaply. With the back link available, eager
conversion costs a handful of field writes, so:

- memory freed in one class is immediately available to every other class and
  to large runs — no "reclaimed before the heap grows, but not before that"
  caveat;
- `malloc` loses its sweep-and-retry path entirely (out of free runs → grow);
- there is no partial-list scan anywhere in the design.

Page churn (an alloc/free cycle straddling a page boundary re-converting the
same page every time) is now ~20 instructions per cycle and touches no memory.
If profiling ever shows it mattering, retaining one empty page per class as
hysteresis is a small, local addition — but it is not needed to make the
design work, and it costs up to 104 KiB of retained pages, so it is not the
default.

### realloc

There is no stored `usedSize` anymore — only the class/run capacity. Policy:

- Same class (or large run with same page count): return `ptr` unchanged.
  Shrinking within a class stays in place (allowed by the glibc contract).
- Different class / page count: `malloc` new, `memcpy min(oldCapacity,
  newSize)` bytes, `free` old, return new pointer. Copying capacity rather than
  exact used size copies some slack bytes; the read stays inside the old slot,
  so it is harmless.
- Large runs get two in-place fast paths: **shrink** by freeing tail pages,
  **grow** by absorbing an adjacent free run if one directly follows. Both
  change a run's extent and must rewrite the boundary mirrors accordingly — the
  partial-absorb case is called out under "Mirror maintenance, spelled out".
- Like `free`, `realloc` requires the exact allocation start: an interior
  pointer fails the slot-alignment check (small) or the page-offset-zero check
  on the `largeStart` page (large) → report and return null. This matches
  today's behaviour, where `getBlock` fails on interior pointers.
- **Under `MemoryDebug`, the in-place cases still have to update the shadow.**
  "Return `ptr` unchanged" is only true of the *user* bytes: the requested-size
  shadow entry and the end canary describe the old size and are now wrong. Every
  in-place path must rewrite the shadow entry and re-lay the canary over the new
  slack `[newSize, classSize)` before returning. Skipping this does not corrupt
  anything, but it silently rots the debug bounds — `free_sized` and `memmove`
  then check against a stale size, which is worse than not checking at all
  because it looks like it works.
- `ptr is null` → `malloc(newSize)`; `newSize == 0` → `free(ptr)`, return null
  (both as today).

Behavioural change to document: today `realloc` shrink can split a block and
grow can extend `usedSize` in place; under the new design a class change always
moves. Callers already must treat the returned pointer as possibly different.

### free_sized

Exact `usedSize` is gone, so the assert weakens to a **class check**:
`sizeToClass(size) == entry.sizeClass` (or, for large, `ceil(size/PageSize) ==
runLength`). This still catches the bug class free_sized exists for (freeing
with a wildly wrong size) — document the changed precision.

### memmove bounds checking

Replace `getBlock`-based checks with a private query used by `memmove` and
`realloc`:

```d
private enum HeapPointerKind {
    notHeap, // stack, static data, or outside the page area
    live,    // inside a live small slot or large run
    freed    // inside a free run, or a free slot
}

private struct AllocationInfo {
    HeapPointerKind kind;
    void* base;      // slot start or run start (live only)
    size_t capacity; // class size or run bytes (live only)
}

private AllocationInfo heapAllocationInfo(const void* ptr);
```

Kept **private**. It is a WASM-only capability with no native counterpart
(`core.stdc` offers no such query), so exposing it would invite engine code
that breaks the native build. If external introspection is wanted later, that
should be a deliberate debugging/introspection API with a native story, not
this.

- Resolves **interior pointers** (`slotStart = pageBase + (offset / classSize)
  * classSize`), which `getBlock` cannot do at all. For large runs, a pointer
  landing on a `largeCont` page resolves through that entry's `runStart` field:
  `base = pagesBase + runStart * PageSize`, `capacity = pageMap[runStart]
  .runLength * PageSize` — O(1), no backwards walk. (If `pageMap[runStart]`
  is not `largeStart`, that is a broken internal invariant — trap.) The bounds
  check is therefore offset-relative:
  `(ptr - info.base) + count <= info.capacity` — *not* `count <= capacity`,
  which is the start-relative form the current code uses and the one most
  likely to get ported over by accident.
- `notHeap` (via the range check) replaces today's "header magic didn't match
  so probably not heap" guess; memmove proceeds unchecked for stack/static
  pointers, as today.
- **`metadata` pages resolve to `freed`, not `notHeap`.** A pointer into the
  page map or a cell-pool page is inside the range check but is not an
  allocation, so the three-way enum has to say something about it. `notHeap`
  would mean "no bounds check possible, proceed" — i.e. memmove would happily
  write over the page map. Treat it as a bounds failure like `freed`: no
  legitimate caller memmoves into allocator metadata. (Naming the enum value
  `freed` for this is a slight stretch; either rename it to something like
  `notAnAllocation` or document the two cases it covers.)
- `freed` is deliberately distinct from `notHeap`: a pointer into freed heap
  memory is a use-after-free, and folding it into "no bounds check possible"
  would let memmove silently write through it. memmove treats `freed` as a
  bounds failure (return null; report). Thanks to the always-on slot bitmap,
  `freed` is exact at slot granularity in every build, not just page
  granularity.

**Behavioural change to document: `memmove` through a freed pointer flips from
accept to reject.** Today `freeBlock` leaves the block header and `blockSize`
intact, so `getBlock` *succeeds* on a freed pointer, the bounds check passes
against the stale size, and the copy proceeds — a use-after-free that the
current allocator waves through. Under the new design that same call returns
null and reports. This is the intended improvement, but it is a real contract
change: any caller (or test) that copies through a pointer it has already freed
changes from silently working to returning null, and the change is invisible
until it happens. Call it out in the module docs alongside "Freed memory is no
longer inert".

**Precision loss to accept:** without `usedSize`, `capacity` is the class size,
so bounds are class-granular in release. `malloc(2)` followed by
`memmove(dst, src, 5)` passes now (class 8) where it returns null today. Under
MemoryDebug the requested-size shadow restores byte-exact bounds. The affected
tests are listed in the migration plan.

### Freed memory is no longer inert

`free` writes the intrusive next-slot index into the first 2 bytes of the
freed slot. Freed memory therefore no longer preserves its contents
byte-for-byte, and the two existing tests that assert it does need updating
(see migration plan). Worth stating in the module docs: reading freed memory
was already undefined behaviour, but under the old allocator it happened to
be stable, and code (or tests) may have come to rely on that.

### Detection response policy

Always-on checks need an always-on response, and betterC has neither
exceptions nor `assert` under `-release`. So none of these checks may be
written as `assert`; they need explicit code, and a documented reaction:

- **Bad API input** (double free, interior pointer, non-heap pointer, wrong
  `free_sized` class, memmove bounds failure): report and reject — no-op or
  null return. Identical in all builds.
- **Broken internal invariant** (freelist index out of range, bitmap
  disagreeing with `usedSlots`, unknown page kind): the heap is already
  corrupt and continuing will spread it. `writeErrLn` and trap.

The build-to-build contract is that **accept/reject semantics are identical**;
debug builds only add forensics (below), never change whether a call succeeds.

### Heap growth

`growHeap(wantedBytes)` as today via `llvm_wasm_memory_grow`, in 64 KiB units.
New WASM pages append 16 logical pages each:

1. Ensure map capacity covers `numPages + newPages` (below).
2. Append the new pages as a free run, coalescing with a trailing free run.

`growHeap` does **not** touch `neverTouchedFrom`, and does not need to. New
pages are appended above `numPages` and are zero per the WASM spec, so the
watermark's claim ("every page ≥ `neverTouchedFrom` is still zero") survives the
append untouched in both cases: if some untouched region already existed the new
pages simply extend it, and if nothing was untouched then
`neverTouchedFrom == numPages` was already exactly the index of the first new
page. This falling-out is the payoff for having a single encoding of "nothing
untouched" — the `NoPage` spelling needed a special case here, and a special
case is somewhere to forget.

`initialHeapSize` stays at 64 KiB. The theoretical footprint floor is one page
per class in use (~104 KiB if all 26 are live) plus metadata, but that is a
worst case, growth is cheap, and no map relocation happens below an 816 KiB
heap — so a larger initial reservation is a tuning decision to make with
measurements, not a precondition of the rewrite.

### Page map growth (the one bootstrap problem)

The map is a flat array indexed by page number, stored in pages tagged
`metadata`. Growing it means **relocating** it: old and new copies must
coexist during the copy, so the new map needs a contiguous free run big
enough for the *entire* new map — not just the added entries. One 4 KiB map
page holds `PageSize / PageEntry.sizeof` entries — 204 at the release entry
width (20 B) → covers 816 KiB of heap before the map must grow; **170 under
MemoryDebug** (24 B entries, and MemoryDebug is the width the wasmtest build
runs) → 680 KiB. Every capacity computation must derive from
`PageEntry.sizeof`, never a hardcoded 204 — the illustrative numbers in this
document assume the release width. Past a 12.75 MiB heap (3264 pages) the whole map no longer fits in
a single 64 KiB grow, and a fragmented heap may have no interior run that fits
it either. The grow policy must account for this:

1. Compute the needed map pages for the *new* total page count. **Two**
   roundings feed this, and both must be folded in:

   - Adding map pages adds heap pages, which can in turn require another map
     page — the self-reference `mapPages = ceil((P + mapPages) / E)`.
   - `memory.grow` is 64 KiB-granular: the combined branch-2 request
     `userPages + mapPages` rounds up to a multiple of 16 logical pages,
     appending **up to 15 slop pages that the map must also cover**.

   Solve both in closed form, do not iterate:

   ```d
   enum entriesPerMapPage = PageSize / PageEntry.sizeof; // E: 204 release, 170 MemoryDebug
   auto P = numPages + userPages; // userPages: logical pages the pending grow must deliver
   auto mapPages = (P + 15 + (entriesPerMapPage - 2)) / (entriesPerMapPage - 1);
   // i.e. ceil((P + 15) / (E - 1))
   ```

   Derivation: `(E-1)·m ≥ P + 15` ⟹ `E·m ≥ P + m + 15 ≥ numPages +
   16·ceil((userPages + m)/16)` = the new total including slop (using
   `16·ceil(x/16) ≤ x + 15`). Verified exhaustively at both entry widths.

   Two earlier drafts got this wrong in two different ways, both of which
   write past the end of the map region — do not resurrect either:

   - *Iterating "until stable" with a claimed bound of three evaluations.* The
     bound is false (`P = 41616` needs four); an unrolled two-pass correction
     under-sizes the map.
   - *The bare closed form `ceil(P / (E-1))` without the `+15`.* It ignores
     grow-request rounding. Concrete failure at `E = 204`: `numPages = 187`,
     `userPages = 16` → `P = 203` → `m = 1`, capacity 204; the combined grow
     requests 17 logical pages → 2 wasm pages → **32** appended → new total
     219 > 204. The map is one page short and page indices 204..218 index past
     its end. (928 such `(n, u)` pairs exist below `n = 4000` alone.)

   The `+15` occasionally costs one map page that turns out unneeded —
   capacity ≥ coverage is the harmless direction (see below).
2. If an existing free run fits the new map, use it. Otherwise size the
   `memory.grow` request as `userNeed + newMapSize` and place the new map at
   the **start** of the freshly grown region — WASM growth is append-only and
   contiguous, so fresh space is always one contiguous run; there is never a
   fragmentation problem in new space, only in old space. Start-placement is
   deliberate, not cosmetic: the map pages are written immediately, so the
   watermark must advance past them; placed at the start, the pages beyond
   map + user stay above the watermark and keep their `calloc` zero-skip.
   Placing the map at the *end* of the grown region (tempting, because the
   user run would then coalesce with a trailing old free run) forces the
   watermark past the entire append and strands the slop pages — the same
   back-carve mistake in different clothes.
3. `memcpy` old map → new, tag new pages `metadata` (`sizeClass =
   MetaKind.pageMap`), retag old map pages as a free run, update
   `mapStartPage`/`mapPageCount`/`mapCapacity`. All of this is written into the
   **new** map; the old one is not modified and stays authoritative until
   `mapStartPage` is switched over.

Both branches must advance `neverTouchedFrom` over the new map region, and both
must let the freed old map region be treated as recycled. See the calloc
section — this is one of the two paths where forgetting that is a correctness
bug rather than a lost optimization. The two branches get there by different
routes, and conflating them does not work:

- **Branch 1** carves the new map out of an existing free run, so it goes
  through `carvePages` and the watermark is handled for it.
- **Branch 2 cannot.** Its pages come from fresh `memory.grow` space that the
  *old* map has no capacity to describe and that is on no free-run list —
  which is the whole reason this branch exists. It writes the new map's page
  entries directly and must call `claimPages` itself for the map pages (and
  for the caller's run carved out of the same fresh region). This is the
  second of the two legitimate page sources; see the calloc section.

Ordering in branch 2: grow first, then build the new map sized for the new
total, then copy the old entries in, then describe the fresh pages (map pages
`metadata`, remainder a free run) in the new map, then switch `mapStartPage`
over, then release the old map region as a free run.

**Call flow — who performs which grow.** This is the seam an implementation
gets wrong, so pin it down: `growHeap` is the **only** caller of the map-growth
machinery. `growHeap(wantedBytes)` computes its append as whole wasm pages
(`newPages = 16 * wasmPages`, post-rounding) and calls
`ensureMapCapacity(newPages)` first. Three outcomes:

- **Covered** — existing capacity suffices. `growHeap` performs its own
  `memory.grow` and appends the new pages as a free run.
- **Relocated (branch 1)** — the map moved into an existing free run; no
  memory was grown. `growHeap` then performs its own grow exactly as in the
  covered case (and that grow may still fail — see the branch-1 residue note
  below).
- **GrewAndAppended (branch 2)** — `ensureMapCapacity` performed the single
  combined grow itself, built the new map, and appended user pages + slop as
  a free run. `growHeap` must **not** grow again; it returns success
  immediately, and its caller's retry (malloc: no run → grow → retry carve)
  finds the pages on the free-run list.

Collapsing this into "growHeap always grows after ensuring capacity" double-
grows in branch 2; making ensure never grow re-opens the fragmentation dead
end branch 2 exists to solve. The three-outcome contract is the design.

Failure is total, never partial: the old map stays valid until the new one is
fully built, so if `memory.grow` refuses (browser limit, wasm32 4 GiB ceiling)
the relocation is simply abandoned and `malloc` returns null — the map can never
be left "stuck" mid-growth, and map-growth failure collapses into ordinary OOM.

The two branches reach that guarantee differently, and the distinction matters
when reasoning about it later:

- **Branch 2 (grow for it)** is genuinely atomic: user need and new map come
  from a single `memory.grow`, so `numPages` and the map's coverage cannot
  disagree — either both advance or neither does.
- **Branch 1 (reuse an existing free run)** is *not* one operation. The map is
  relocated first, then the user's grow happens separately and may fail
  independently. This is still safe, but for a different reason: the residue of
  a failed grow is an oversized map covering the old `numPages`, and map
  **capacity ≥ coverage** is the harmless direction. The invariant to preserve
  is `mapCapacity >= numPages`, never equality.

Do not carry branch 2's atomicity argument over to branch 1 — the conclusion
happens to hold, the reasoning does not.

Costs: the grow occasionally over-allocates by the map size (≈0.5% of heap),
and the copy is 0.5% of the heap — 80 KiB at a 16 MiB heap, 20 MiB at the
wasm32 4 GiB extreme. Relocations are rare (doubling-style frequency: each map
size is outgrown once), but a multi-MiB copy is a frame-hitch candidate at
large heap sizes; see the open question below. Relocation is trivially safe
because nothing stores pointers into the map; everything recomputes
`pageMap[i]` from `mapStartPage`. The bitmap-cell pool does not participate:
its pages are independent and never relocate.

**Rejected alternative:** a two-level radix (static root in the data segment +
per-64 KiB-chunk descriptor pages) avoids the copy but adds a level of
indirection to *every* lookup and a fixed BSS root sized for the max supported
heap. The flat growable map is simpler and the copy is negligible at realistic
heap sizes; revisit only if map relocation ever shows up in profiles.

### initializeHeapMemory / wipeHeap

- `initializeHeapMemory(heapOffset)`: compute `pagesBase`, `maybeGrowInitialHeap`
  as today, set all page-index globals to `NoPage`, compute `numPages` from the
  *current* memory size, build the map at the bottom of the page area, and set
  `neverTouchedFrom` per the calloc rule below.
- **Init must do the general multi-page map build, not a one-page shortcut.**
  A single map page covers 204 logical pages (816 KiB), and `initialHeapSize`
  is 64 KiB, so "page 0 = metadata, pages 1..N-1 = one free run" looks
  sufficient. It is not, because init is not only called on a fresh module:
  `retrograde.std.test.test()` calls `wipeHeap(); initializeHeapMemory();`
  **before every single test**, and WASM linear memory never shrinks. Once any
  one test has grown the heap past 816 KiB, every subsequent re-init starts
  with `numPages > 204`. A one-page map then covers a fraction of the heap and
  every page index past 203 reads and writes past the end of the map region —
  and an `assert` guarding it is no guard at all in a `-release` build (see
  "Detection response policy"). So:

  ```d
  auto mapPages = (numPages + (entriesPerMapPage - 1) - 1) / (entriesPerMapPage - 1);
  // pages [0 .. mapPages)        -> metadata, MetaKind.pageMap
  // pages [mapPages .. numPages) -> one free run (if any remain)
  ```

  This is the "Page map growth" closed form *without* the `+15` slop term —
  correctly so: at init `numPages` is already final (any growth happened in
  `maybeGrowInitialHeap` before the map is sized), so there is no pending
  64 KiB rounding to cover. About ten lines. The degenerate case
  `mapPages >= numPages` (a heap too small to hold its own map) must fail init
  rather than produce a heap with no free run.
- `mapStartPage = 0`, `mapPageCount = mapPages`, `mapCapacity` computed the
  same way it is indexed (see the flat-indexing note in the implementation
  notes).
- `neverTouchedFrom = max(firstNewPage, mapPages)` where `firstNewPage` is the
  first page index this call grew into, or `numPages` if it grew nothing. The
  `max` matters: the map is written into pages `[0 .. mapPages)` at the
  *bottom* of the page area, so on a first-ever init that grew from nothing
  `firstNewPage` is 0 and the map pages would otherwise be claimed untouched
  while holding map bytes. Re-initialization over an existing heap grows
  nothing and conservatively marks everything touched.
- `wipeHeap()` zeroing the heap does **not** license marking pages untouched
  (see calloc); init must not depend on having been preceded by a wipe.
- `wipeHeap` keeps its contract (zero everything from `heapStart`); the
  `WasmMemTest` harness pattern `wipeHeap(); initializeHeapMemory();` between
  tests must keep working unchanged — init must fully rebuild state from
  nothing, no assumptions about prior map contents.

## What this buys (tie-back to goals)

| Property | Today (inline blocks) | Proposed (page map) |
|---|---|---|
| Metadata location | 20 B header touching every allocation | reserved metadata pages; only region edges border live data |
| Overrun by 1 byte hits | next block's header → heap walk breaks | neighbour's data — allocator state stays consistent |
| "Is this a heap pointer?" | magic+checksum guess, forgeable | exact: range check + map entry |
| Interior pointer resolution | impossible | O(1) arithmetic |
| free validation | heuristic | exact slot-start + kind + bitmap |
| Double free | undetected | detected exactly, all builds |
| malloc small | O(heap) first-fit walk | O(1) |
| free | O(1) + heuristic | O(1) + exact |
| Metadata overhead | 20 B per allocation | ~0.5% map + 1.6% per small page |
| Small-object waste | 20 B flat | ≤45% rounding under 128 B, ~25% above |
| Alignment | accidental 4 | guaranteed ≥ 8 |
| Coalescing | during alloc walk | O(1) at free time |
| realloc append | O(n²): every growth moves | in-place within a class — implicit geometric growth to 2048 B |

That last row is worth calling out: because `blockSize` is the exact requested
size today, `String.opOpAssign!"~"(T)` — which reallocs on every appended
character — does a malloc + memcpy + free *per character*. Under size classes
those appends return the same pointer with no copy until the class boundary is
crossed, so byte-at-a-time append becomes amortized without touching a single
call site. In practice this is a bigger win than the O(1) malloc.

## Debug instrumentation (MemoryDebug)

**MemoryDebug is not an optional extra here — it is the configuration every
WASM test runs under.** `wasmtest/dub.json` builds with
`["WasmMemTest", "MemoryDebug", "UnitTesting", "NoGraphicsApi"]`, so the
shadow/canary machinery below is on the only path the test suite exercises,
and it has to be implemented in the same change, not deferred. The corollary is
uncomfortable and worth stating: **release-mode class-granular bounds behaviour
is exercised by no test by default.** The workflow section below closes this
with a two-config sweep; the requirement it imposes on test code is that every
byte-exact assertion is `version (MemoryDebug)`-guarded with a class-granular
variant in the `else` branch, so the suite passes unedited in both
configurations.

The always-on checks (range, kind, slot alignment, slot bitmap, freelist index
validation) are release-mode features and are specified above, not here.
MemoryDebug adds forensics on top, without changing whether any call succeeds:

- **Requested-size shadow + end canary:** store the **slack**
  `classSize - requested` per slot in a shadow array — *not* the requested size
  itself, which does not fit: a 2048-byte request needs 12 bits, while the
  largest slack across the whole class table is 255 (at 1793 → 2048) and fits
  in a byte exactly. Recover the requested size as `classSize - slack`. Write a
  canary in the slack `[requested, classSize)`; check on free, and use the
  recovered exact size for `memmove`/`free_sized` bounds instead of the class
  size. In-place `realloc` must refresh both the shadow entry and the canary —
  see the realloc section.
  Debug-only because the shadow costs 12.5% on the 8-byte class and the canary
  costs time proportional to the slack on every alloc and free — and because
  it only *sharpens* a bound that still exists at class granularity, protecting
  bytes that are inside the caller's own slot. (Canary coverage is inherently
  partial anyway: an exact-size request has no slack to put one in.)
- **Where the shadow lives (unspecified in earlier drafts — decide before
  coding).** "A shadow array" needs actual storage, and it is bigger than the
  bitmap: one byte per slot is up to 512 bytes per small page, versus 64 for
  the bitmap. Three workable options, in order of preference:
  1. **Widen `PageEntry` under `version (MemoryDebug)`** and keep a second
     cell pool with 512-byte cells — **8 cells per pool page**, not 64; the
     64-per-page figure is specific to 64-byte bitmap cells. Parameterize the
     pool mechanism by cell size (`cellsPerPage = PageSize / cellSize`, cell
     address `pagesBase + (id / cellsPerPage) * PageSize + (id % cellsPerPage)
     * cellSize`) rather than duplicating it. Costs one extra `uint` in the
     entry for the shadow cell id. The shadow cell needs no zeroing on claim:
     every shadow byte that `free`/`memmove` reads belongs to a slot whose
     bitmap bit is set, and setting that bit (malloc) writes the byte first.
     Zero it anyway if it simplifies the cross-checks — it is debug-only cost.
  2. One dedicated shadow page per small page — simpler, wastes up to 3.5 KiB
     per small page. Acceptable for a debug build, ugly at scale.
  3. A parallel shadow map allocated alongside the page map — has to relocate
     in lockstep with it, which is the one thing the design otherwise avoids.
  Whichever is chosen, `PageEntry.sizeof == 20` becomes a **release-only**
  static assert; state the debug size separately.
- **Large runs need their exact requested size too**, for the same
  `memmove`/`free_sized` sharpening. There is no slack byte to hide it in
  (a run's slack can be up to `PageSize - 1`), so put it in the
  MemoryDebug-only `PageEntry` extension on the `largeStart` page.
- **Cross-check the bitmap against `usedSlots`** on every page transition.
- **A `callocMemsetSkips` counter** (`__gshared uint`, MemoryDebug-only),
  incremented once per skipped memset. This exists because the zero-skip is
  **behaviourally invisible**: skipped or not, calloc returns zeros, so no
  black-box assertion can tell the paths apart — and never-touched pages
  cannot be pre-dirtied to force a difference, because dirtying them is
  touching them. Tests assert the counter moved (skip taken) or stayed
  (recycled path memset). Co-located tests read it directly; it needs no
  accessor.
- Keep `printDebugInfo`; add a `dumpPageMap()` debug dump. Printing numbers
  from inside the allocator is safe on WASM — see the implementation notes.

## Known limitations

- **Page-space fragmentation.** The allocator never moves an allocation, so a
  session that has used many size classes ends up with small pages scattered
  across the address space. Eager reclamation returns *empty* pages promptly,
  but a large-run request can still fail to find a contiguous run and grow the
  heap while plenty of total free space exists in partially-used small pages.
  This is inherent to non-moving allocators (mimalloc and friends have it too)
  and is accepted; the mitigation, if it ever matters, is class-table tuning so
  fewer classes are live at once.
- **Grow-only.** Combined with the above, a long session's footprint can drift
  upward and never come back down.

## Non-goals

- Thread safety (engine WASM target is single-threaded).
- Returning memory to the browser (`memory.grow` is one-way; free pages are
  reused, never released — same as today).
- wasm64 / heaps beyond wasm32's 4 GiB.
- Changing the native allocator (`retrograde/native/`) — this is
  `version (WebAssembly)` only. Native uses the D/betterC C-runtime allocator
  and there is no intention to share this implementation with it.

## Migration plan

1. Rewrite `source/retrograde/wasm/memory.d` internals behind the unchanged
   exported symbols. No other engine module imports block internals
   (`MemoryBlock` etc. are `private`), so blast radius is this file plus its
   tests.
2. Replace `getBlock` uses inside the module (`realloc`, `free`, `free_sized`,
   `memmove`) with the page-map paths / `heapAllocationInfo`.
3. Tests (`runWasmMemTests`):
   - Keep every test that exercises the public contract (malloc/calloc/
     realloc/free/free_sized semantics, memset/memcmp/memcpy/memmove) —
     assertions on `MemoryBlock` fields get rewritten against `PageEntry` /
     `heapAllocationInfo`.
   - **Tests that must change because the behaviour genuinely changed:**
     - "free frees previously allocated memory" and the freed-memory sanity
       check inside "calloc clears memory after allocation" both assert that
       freed bytes keep their old contents; the freelist link now occupies the
       first 2 bytes. Rewrite to assert from offset 2, or drop the assertion.
     - "memmove returns null when count exceeds src block bounds" and "…dest
       block bounds" use `malloc(2)` with `count == 5`, which is now within
       the 8-byte class in *release* but still rejected under `MemoryDebug`
       (the requested-size shadow restores byte-exact bounds). Per the
       two-config rule: keep the `count == 5` assertion under
       `version (MemoryDebug)`, and assert the class-granular behaviour
       (`count == 5` succeeds, count past the class size fails — e.g. 9
       against class 8) in the `else` branch.
   - Drop block-mechanics tests (`splitBlock`, `combineBlocks`,
     `findFreeBlock`, checksum tests); add equivalents for: size-class
     rounding, slot reuse order, page full→partial transitions, eager
     empty-page reclamation (last free of a page converts it to a free run and
     coalesces), free-run coalescing including boundary-mirror updates on
     split/merge and the `i == 0` / `j + 1 == numPages` edges, large-run
     alloc/free, in-place large realloc grow/shrink (asserting the trailing
     mirror is rewritten on a *partial* absorb), map growth/relocation
     (and the `free` range check staying correct after the map moves),
     cell-pool page alloc/release including the page dropping out of
     `firstCellPoolPage` when it fills and returning when a cell frees,
     **calloc returning all-zero memory on every path** — skipping the memset
     on never-touched pages, and *not* skipping it on recycled small slots, on
     a recycled large run, on a released cell-pool page, and on the old map
     region after a relocation (the last two are the paths a naive
     implementation gets wrong and a naive test misses),
     memmove through a freed pointer returning null,
     interior-pointer resolution, contract edges (`malloc(0)` → null,
     oversized `malloc` → null, `free(null)` silent no-op, interior-pointer
     `realloc` → null), invalid-free detection (interior small pointer,
     `largeCont` pointer, non-heap pointer, pointer into a free page, double
     free — now detected in release too).
   - Mind the known WASM test pitfall: no struct definitions inside test
     lambdas (call_indirect trap) — keep test helper structs at module scope.
     See `docs/wasm-pitfalls.md`.
   - **The harness re-inits before every test, which makes the calloc
     zero-skip unreachable by default.** `retrograde.std.test.test()` runs
     `wipeHeap(); initializeHeapMemory();` first, and re-init over an existing
     heap marks *everything* touched. So a test that merely callocs sees the
     memset path, always. Any test of the zero-skip must **grow the heap
     inside its own body first** (allocate past the current memory size), then
     calloc into the fresh pages. And because skip-vs-memset is behaviourally
     invisible (both return zeros), the assertion medium is the
     `callocMemsetSkips` counter from the debug section: skip tests assert it
     incremented, recycled-path tests assert zeros **and** that it did not.
   - Add a test that re-inits over a heap larger than one map page's coverage
     (grow past `entriesPerMapPage` logical pages — 170 under the wasmtest
     build's MemoryDebug entry width, 204 in release — then
     `initializeHeapMemory()`), which is the case the one-page-map shortcut
     got wrong. The harness reaches this state naturally the moment any single
     test allocates that much, so it should be pinned down deliberately rather
     than discovered.
   - Note that the existing "Initial heap size is usable" test writes 42 over
     `heapStart[0 .. heapSize]`, which now clobbers the page map. That stays
     harmless only because the next `test()` re-inits — the test must not make
     any allocator call after the fill.
4. Verify with the wasmtest suite (`wasmtest/`, headless Node runner) and
   `make test-native` for the modules that consume the allocator indirectly.
5. Docs: delete `docs/wasm-allocator-current.html` and
   `docs/wasm-allocator-proposed.html`. They exist to explain the change from
   the block design; once the block design is gone there is nothing to compare
   against and the page allocator is described here and in the module docs.
6. Afterwards, revisit `realloc`-heavy call sites (`Array` growth) — with size
   classes, growth doubling already lands on class boundaries; check the growth
   factor complements the class table. `Array` currently grows by a flat 8
   elements (`defaultChunkSize`), which crosses a class boundary on almost
   every resize and keeps the O(n²) behaviour the class table would otherwise
   amortize away.

## Implementation notes (toolchain and harness)

Environment facts that are not derivable from the design and that will cost a
day each if rediscovered the hard way.

### Trapping

"Report and trap" needs a mechanism, and the codebase currently has none.
`assert` is not it: betterC has no `Throwable`, and asserts vanish under
`-release`, which is precisely the build where an internal-invariant violation
must still stop the program. Use:

```d
version (LDC) {
    import ldc.intrinsics : llvm_trap;
}
```

Confirmed present in the toolchain in use (`ldc2-1.42.0`, `ldc/intrinsics.di`).
It lowers to the WASM `unreachable` instruction. The headless Node runner
(`wasmtest/run-tests-headless.mjs`) surfaces that as a non-zero exit with a
stack trace, so trapping is CI-visible.

### Diagnostics do not allocate on WASM

Always-on reporting means `writeErrLn` moves out of the current
`version (MemoryDebug)` import block in `retrograde/wasm/memory.d`. That is
safe: on WASM, `writeln`/`writeErrLn` of integers dispatch straight to
`extern (C)` imports (`writeErrLnUint`, `writeErrLnStr`, …) that hand the raw
value or a pointer+length to JS, which does the formatting. **No allocation, so
no re-entry into `malloc` from inside the allocator** — including from
`dumpPageMap`, which can print freely.

This is a WASM-only property. The native path formats via
`retrograde.std.conv.to!String`, which allocates. Do not copy allocator
diagnostics into shared code on that assumption.

### LLVM turns byte loops into calls to the functions being defined

`memset` and `calloc` carry `version (LDC) @optStrategy("none")` for a reason:
wasmtest builds at `-O3`, and LLVM recognizes byte-copy/fill loops and rewrites
them into calls to `memset`/`memcpy` — which are these very functions.
Consequences for the rewrite:

- Keep the existing attributes. Do not "clean them up".
- Any new byte loop (page zeroing, map relocation copy, canary fill) must
  either call the existing exported `memset`/`memcpy` or carry
  `@optStrategy("none")` itself.
- `memcpy` currently lacks the attribute and survives by luck of the current
  optimizer's decisions; treat it as fragile and do not restructure its loop.

Related performance note: `memset`/`memcpy` are byte-at-a-time. `calloc` of a
*recycled* multi-MiB large run pays that in full, and the zero-skip does not
help there. A word-wise loop with a byte tail is a bigger win for that workload
than anything else in this design; worth doing as part of the rewrite.

### Module globals: use `__gshared`

D module-level variables are thread-local by default. The current allocator's
globals are zero-initialized, which is why this has never mattered. The new
globals have **non-zero initializers** (`= NoPage`), which places them in a
`.tdata` segment whose initialization depends on TLS setup that a betterC WASM
module does not perform. Declare them `__gshared`, and — since
`initializeHeapMemory` must fully rebuild state from nothing on every call
anyway — assign every one of them explicitly in init rather than relying on a
declaration-site initializer.

### Page-map indexing: pick flat, and make capacity agree

4096 / 20 = 204.8, so entries do not tile a page evenly. Two consistent
choices exist: index flat over the contiguous region (`mapBase + i *
PageEntry.sizeof`, entries may straddle a page boundary — harmless, the region
is contiguous), or index per page and waste the remainder per map page. Take
the flat form. Define `enum entriesPerMapPage = PageSize / PageEntry.sizeof`
**once** and derive everything from it — it is 204 in release and **170 under
MemoryDebug** (24-byte entries), and the wasmtest build is MemoryDebug, so a
hardcoded 204 anywhere is a bug in the tested configuration, not a latent one.
`mapCapacity = mapPageCount * entriesPerMapPage` is a *lower* bound on what
the region physically holds — safe; the only requirement is that the value
used for the bounds check is computed the same way everywhere.

`mapCapacity >= numPages` is the invariant, never equality (see "Page map
growth").

### Range checks in subtraction form

Spell pointer range checks as `cast(size_t)(ptr - pagesBase) <
numPages * PageSize`, not as a comparison against a computed end pointer.
`pagesBase + numPages * PageSize` equals the end of linear memory, which at
the wasm32 4 GiB ceiling is 2^32 and wraps to 0 as a 32-bit pointer, turning
the upper bound into nonsense. The subtraction form is immune (the product
fits: `numPages < 2^20`), and unsigned wraparound makes `ptr < pagesBase`
fail the same single comparison for free.

### Slot index computation without magic-number tables

`free` needs `(ptr - pageBase) / classSize` and the `% classSize == 0` check
without a runtime division by a non-constant. Hand-rolled reciprocal-multiply
constants are 26 chances to be subtly wrong. Prefer a `switch` over the size
class with compile-time-constant divisors per case (generate the cases with
`static foreach` over the class table) — LLVM produces the multiply-shift
itself, and the `/` and `%` in the same arm fold into one sequence. Note it
cannot be `final switch`: `sizeClass` is a raw `ubyte`, and D's `final switch`
over an integral type demands all 256 cases. A plain `switch` whose `default`
treats the unknown class as a broken internal invariant (trap) is both legal
and exactly the response policy anyway. Same technique for `slotsPerPage`.

### Interaction with `_d_array_slice_copy`

`source/retrograde/compiler/ldc.d:22` implements the compiler's array-slice
copy hook and, in debug builds, asserts `memmove(...) is dest`. Two of this
design's changes land there:

- memmove now rejects `freed` pointers, so a use-after-free slice copy that
  used to succeed silently becomes a **hard assert failure**. Intended, but
  this is the mechanism by which the behaviour change becomes visible.
- memmove now resolves **interior** pointers, so slice copies into the middle
  of an `Array`/`String` buffer — previously unchecked, because `getBlock`
  failed on them — become bounds-checked for the first time.

Both are improvements, and both mean the first green-to-red transition after
the rewrite may well be a pre-existing bug in `Array`/`String`, not in the
allocator. Budget for that rather than assuming a regression.

## Implementation workflow

The loop is: **implement → rewrite the co-located tests → run the WASM suite →
iterate until green → sweep the second config → native suite.** Concretely,
and in this order, because the order localizes failures:

1. **Read `docs/wasm-pitfalls.md` first.** Both pitfalls in it (lambda-local
   structs with template mixins; `extern (C)` variable shadowing) are directly
   relevant to this module and its tests.
2. **Scaffold with compile-time proof.** `PageEntry` + enums + globals, plus
   `static assert`s: entry size (20 release / stated size under MemoryDebug),
   `entriesPerMapPage` derived from `sizeof`, and a CTFE check that the
   `sizeToClass` table and the class-size array agree (for every size 1..2048:
   the mapped class covers the size and the next-smaller class does not).
   These cost nothing at runtime and turn table typos into build failures.
3. **Build the debug lens before the machinery that needs debugging:**
   `dumpPageMap()` and the invariant walker (free-run list ↔ mirror agreement,
   runs tile without overlap, bitmap popcount vs `usedSlots`). Every later
   step is diagnosed with these; writing them last means debugging the hard
   parts blind.
4. **Implement bottom-up:** map indexing and init → `claimPages`/`carvePages`
   → free-run convert/coalesce → cell pool → small malloc/free → large paths
   → calloc → realloc → `free_sized` → `heapAllocationInfo` + memmove → heap
   growth and map relocation → MemoryDebug shadow/canary.
5. **Rewrite `runWasmMemTests` in the same file as you go**, per the migration
   plan. Tests are co-located and may read private state (`pageMap` entries,
   `neverTouchedFrom`, `callocMemsetSkips`) directly — do not export anything
   for their benefit.
6. **Run the WASM suite and iterate:**

   ```
   cd wasmtest && make run-tests-headless
   ```

   - Exit is non-zero on any trap or failed assert, with a wasm stack trace;
     mangled D names identify the frame. There is no single-test filter — the
     suite always runs whole, `runWasmMemTests` first.
   - After the memory tests pass, the rest of the suite (String, Array,
     entity, assets) hammers the allocator as integration coverage. A failure
     there with green memory tests is often a **pre-existing caller bug
     surfaced by the new checks** (see the `_d_array_slice_copy` note), not an
     allocator regression — diagnose with `dumpPageMap` and the invariant
     walker before "fixing" the allocator.
   - Iterate here until fully green.
7. **Sweep the second configuration.** Temporarily remove `"MemoryDebug"` from
   the `versions` array in `wasmtest/dub.json`, rebuild, rerun, restore. This
   is the only exercise the release-mode paths (class-granular bounds,
   always-on bitmap checks without the shadow) get. It passes without editing
   tests only if the byte-exact assertions were `version (MemoryDebug)`-
   guarded as the migration plan requires.
8. **`make test-native`** — the allocator is version-gated out of it, but it
   guards the shared modules touched along the way (test registration, any
   facade edits). `make build-lib` does not work (missing native platform
   implementations) — do not use it to validate anything.
9. Only after both configs are green: delete the two comparison HTML docs
   (migration step 5). The `Array` growth-factor follow-up (migration step 6)
   is a separate change — do not fold it into this one.

## Open questions

- **Page size 4 KiB vs 8/16 KiB:** larger pages shrink the map but waste more
  on the last partially-used page per class and raise `MaxSmallSize` pressure.
  4 KiB is the proposed default; measure with real engine workloads (asset
  loading vs. steady-state frame allocations) before locking in.
- **Class table tuning:** the table above is a starting point; instrument
  allocation-size histograms (MemoryDebug counter per class) and adjust. Three
  known weak spots: the 33–48 band (45% rounding), the 1793–2048 band (255 B
  on one allocation), and the non-divisor classes whose page tail waste is
  worse than their rounding (1536 costs 2048 B/slot, 896 costs 1024 B/slot).
  Tuning should weigh rounding *and* tail waste together — a class is only as
  good as `PageSize / slotsPerPage`.
- **`MaxSmallSize` = 2048:** allocations of 2–4 KiB pay up to ~50% page
  rounding as large runs. If histograms show a hot spot there, add 2- or
  4-slots-per-page classes up to 4 KiB.
- **Map relocation hitch at large heaps:** the relocation copy is ~0.5% of the
  heap and lands mid-frame whenever a malloc triggers it. If profiling shows
  hitches, that is the trigger to revisit the rejected two-level radix map,
  which never relocates (each grow fills in new leaf entries) at the price of
  one extra indirection per lookup. Cheaper mitigations to try first: pre-grow
  the heap during loading screens, or over-reserve map capacity a step ahead
  so relocation happens before the heap is under frame-time pressure.
- **Empty-page hysteresis:** eager reclamation is the default. If page churn
  shows up in profiles, retaining one empty page per class is a small local
  change — but it pins up to 104 KiB, so it needs evidence first.
