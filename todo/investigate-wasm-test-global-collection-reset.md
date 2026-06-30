# TODO: Audit test suites that reset module-global collections under WasmMemTest

## Problem

Several modules keep their state in module-level global collections (`HashMap`,
`LinkedList`, `Array`, `SlotList`, …) and provide a test-only `resetState()` that
`clear()`s them at the start of every test. Under the **WASM** test build this
pattern can crash or spam the log, because the WASM test harness wipes the heap
between tests but the globals (which live in the data segment) keep their stale
pointers.

## Findings

The WASM unit test config (`wasmtest/dub.json`) enables `WasmMemTest`. With that
flag, `retrograde.std.test.test()` runs before **every** test:

```d
version (WasmMemTest) {
    wipeHeap();             // memset(heapStart, 0, heapSize) — zeroes the whole heap
    initializeHeapMemory();
}
```

Module-global collections are **not** in the heap — they live in the data
segment — so after a wipe their internal pointers (`buckets`, `head`/`tail`,
`items`) still point into heap memory that has just been zeroed/reset. The next
test's `resetState()` then operates on those dangling pointers:

- **`HashMap.clear()`** bottoms out in `free()` on a stale pointer. The WASM
  allocator (`source/retrograde/wasm/memory.d`) handles this gracefully: with
  `MemoryDebug` it logs `Failed to get block: pointer does not point to the start
  of valid block data` and returns. **Benign**, but it spams the test log.
- **`LinkedList.clear()`** walks the chain via `node = node.next`
  (`source/retrograde/std/collections.d`, `LinkedList.clear`). On a wiped chain
  that read yields a bad address and the loop keeps following it →
  `memory access out of bounds`, a **fatal** `RuntimeError`. This is what first
  surfaced the issue (the asset library's `fetchingModels` / `fetchingTextures`
  were the first `LinkedList` globals cleared in a `resetState`).

Native tests never hit this: the native config does not set `WasmMemTest`, so no
inter-test heap wipe happens and `clear()` frees live memory normally.

### The fix that was applied

In the affected `resetState()`s, branch on `version (WasmMemTest)`:

- **Native** (no wipe): keep `clear()` so memory is actually freed (no leaks).
- **WasmMemTest** (heap already wiped): reset each global to its zero/`.init`
  state with `memset(&g, 0, g.sizeof)` instead of `clear()`. This drops the
  dangling references without walking or freeing freed nodes — which both avoids
  the `LinkedList` OOB crash and silences the benign `HashMap` free warnings.

`memset` is fine here because `.init` for these collections is all-zero
(null pointers, zero lengths). It does **not** run destructors, which is exactly
what we want: the memory it would free is already gone.

Already done:

- `source/retrograde/assets/assetlibrary.d` — `resetState()` (models + textures
  bookkeeping; the `LinkedList` globals here caused the original crash).
- `source/retrograde/std/assets.d` — `resetState()` (silences the benign
  warnings that several asset tests were emitting).

## Action items

Go through the other test suites that reset module-global collections and apply
the same `WasmMemTest` branch where needed (prioritise any with `LinkedList`
globals, which crash rather than just warn):

- [ ] `source/retrograde/engine/entity.d` — entity/component/processor/hook
  globals are cleared in its reset path. Check the collection types involved.
- [ ] Grep for other `resetState`/`clear()`-in-tests patterns over module
  globals: `rg "void resetState" source/` and inspect each.
- [ ] Audit any suite using `LinkedList` or `SlotList` module globals in
  particular — those walk node chains on clear and will fault, not just warn.

## Possible better fix (consider instead of per-suite branching)

Rather than special-casing every `resetState()`, consider one of:

- A shared test helper, e.g. `resetGlobal(ref T collection)` in
  `retrograde.std.test`, that does the `version (WasmMemTest)` memset / else
  clear, so suites call one thing.
- Making `LinkedList.clear()` (and friends) tolerant the way `HashMap.clear()`
  is — though this only downgrades the crash to a benign warning; it does not
  remove the need to avoid freeing wiped memory.
- Having the WasmMemTest harness itself null out registered globals after a
  wipe, so `resetState()` never sees dangling pointers.

See also [investigate-collection-destructors.md](investigate-collection-destructors.md)
for related destructor/cleanup concerns in the collections themselves.
