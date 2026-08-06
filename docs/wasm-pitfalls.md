# WebAssembly Pitfalls

Gotchas that only surface in the WASM build. Code that is technically wrong in
the same way on native often passes there by ABI luck, so "native tests are
green" is not proof that the WASM build is fine.

For gotchas that come from `-betterC` itself and bite every target, see
[betterc-pitfalls.md](betterc-pitfalls.md).

## Structs with template mixins inside test lambdas break `call_indirect`

### Symptom

The WASM test suite traps the moment a specific test starts, before its body
runs a single statement:

```
RuntimeError: null function or function signature mismatch
    at wasmtest.wasm._D10retrograde3std4testQfFAyaPFZvZv (...)
    at wasmtest.wasm._D10retrograde3std11collections13runArrayTestsFZv (...)
```

The test's name is printed, then the crash — the top frame is `test()` itself,
not the test's lambda. The native test suite passes.

### Cause

Declaring a struct that instantiates a template mixin inside a test lambda:

```d
test("...", () {
    static struct Inner {
        Array!int values;
        mixin CopyConstructors!Inner; // <-- the trigger
    }
    // ...
});
```

makes the D frontend treat the lambda as a *nested function that needs a
context pointer*, even though `static struct` should not capture anything and
the lambda still typechecks as a plain `void function()`. This is arguably a
frontend/codegen bug: the declared type and the emitted signature disagree.
You can see it in the mangled name — the broken lambda mangles as
`__lambda_..._MFZv` (`M` = member/needs context) and is emitted with an extra
`i32` context parameter, while healthy test lambdas mangle as
`__lambda_..._FZv` and take no parameters.

`test(string, void function())` invokes the lambda through
`call_indirect (type () -> ())`. WebAssembly type-checks every indirect call
against the function table entry at runtime, sees `(i32) -> ()` instead, and
traps with "null function or function signature mismatch".

On native the same mismatch is harmless by accident: the caller passes no
context argument, the callee never reads the (garbage) register it would have
arrived in, and execution continues. That is why the native suite cannot catch
this class of bug.

### Fix / rule

Hoist the helper struct to module scope, inside the `version (UnitTesting)`
section:

```d
version (UnitTesting)  :  ///

private struct InnerArrayOwner {
    Array!int values;
    int tag;

    mixin CopyConstructors!InnerArrayOwner;
}
```

See `InnerArrayOwner` in `source/retrograde/std/collections.d` for the real
instance (fixed 2026-07-08). Plain local variables, control flow, and even
`static struct`s *without* template mixins have not shown this problem — the
observed trigger is the template mixin instantiation inside the lambda-local
struct.

### How to diagnose this class of failure

Run the WASM suite headlessly under Node instead of a browser:

```
cd wasmtest && make run-tests-headless
```

This builds the suite and runs it via `wasmtest/run-tests-headless.mjs`, which
instantiates the module with the runtime's import object and calls `_start()`.
It exits non-zero on a trap or failed assert, so it is also CI-friendly.

To inspect signatures, disassemble with the `wabt` npm package:

```js
import wabtFactory from "wabt";
const wabt = await wabtFactory();
const mod = wabt.readWasm(bytes, { readDebugNames: true });
fs.writeFileSync("out.wat", mod.toText({ foldExprs: false }));
```

Then grep the `.wat` for the suspect `__lambda_` name: an `M` before `FZv` in
the mangling, or a `(param i32)` where sibling lambdas have none, confirms the
mismatch.

## Test resets that `clear()` module globals free memory the harness already wiped

### Symptom

Under the WASM suite only, tests that reset module-level state spam the log
with allocator complaints, one per collection being reset:

```
removing the last event of a key unmaps the key
free: double free or pointer into free memory
free: double free or pointer into free memory
free: double free or pointer into free memory
  OK!
```

The tests still pass. The tell-tale shape is that the messages appear *after*
`test()` has printed the name but before the body can have allocated anything,
and that the **first** test of a section is clean while every later one warns —
so what is being freed is whatever the previous test left in the globals.

With a `LinkedList` global it is not benign: `clear()` walks `node = node.next`
through wiped memory and the suite dies with a fatal
`RuntimeError: memory access out of bounds`. That is how this was first found,
via the asset library's `fetchingModels` / `fetchingTextures`.

Native is always clean, so this cannot be caught by `make test-native`.

### Cause

`wasmtest/dub.json` enables `WasmMemTest`, which makes
`retrograde.std.test.test()` run before **every** test:

```d
version (WasmMemTest) {
    wipeHeap();             // memset(heapStart, 0, heapSize)
    initializeHeapMemory(); // hand the whole heap back to the allocator
}
```

Module-level globals are not in the heap — they live in the data segment, which
the wipe does not touch. So a global `HashMap`/`Array`/`Queue`/`LinkedList`
keeps its `buckets`/`items`/`head` pointers into heap memory that has just been
zeroed and returned to the free pool. The next test's `resetX()` then calls
`clear()` through those dangling pointers, and the allocator correctly rejects
freeing memory it considers free. The reset is doing exactly the right thing on
native and exactly the wrong thing here.

### Fix / rule

A test-only reset of module globals must not free under `WasmMemTest` — the
memory it would free is already gone. Drop the references instead:

```d
void resetInput() {
    version (WasmMemTest) {
        // The WasmMemTest harness wipes the heap before each test, so these globals already
        // hold dangling pointers. Reset them to their init state without freeing: clear()/free
        // would log benign "invalid block" errors for the already-wiped memory.
        import retrograde.std.memory : memset;

        memset(&keyEvents, 0, keyEvents.sizeof);
        memset(&eventQueue, 0, eventQueue.sizeof);
        memset(&keyMapping, 0, keyMapping.sizeof);
    } else {
        keyEvents.clear();
        eventQueue.clear();
        clearKeyMappings();
    }
}
```

`memset` is right here precisely because it runs no destructors: `.init` for
these collections is all-zero (null pointers, zero lengths). Keep the `clear()`
on the native side — there the heap is never wiped and skipping it would leak.

Existing instances: `resetInput()` in `source/retrograde/engine/input.d`,
`resetState()` in `source/retrograde/std/assets.d` and
`source/retrograde/assets/assetlibrary.d`. Not every suite has been converted
yet — see
[../todo/investigate-wasm-test-global-collection-reset.md](../todo/investigate-wasm-test-global-collection-reset.md)
for the audit and for ideas on fixing this once centrally instead of per suite.

### How to diagnose

Run `cd wasmtest && make run-tests-headless` and count the messages
(`grep -c "double free"`), rather than reading the log — a handful are
legitimate, emitted by the allocator's own tests in
`source/retrograde/wasm/memory.d` that deliberately double-free. Compare the
count against the same command on a clean checkout, and check which section the
new ones fall in:

```
awk '/-- Input tests --/,0' out.txt | grep -c "double free"
```

If they line up with test-name boundaries in a suite that has a reset helper,
it is this pitfall and not a real double free.

## `extern (C)` variable declarations are *definitions* — they shadow external symbols

### Symptom

Module-level globals appear to live "on the heap": writes to zero-initialized
D globals corrupt allocated memory, or allocations corrupt the globals. In
this engine the symptom was `initFunction`/`updateFunction`/`renderFunction`
seemingly being stored past `__heap_base`, which was masked for years by a
64 KiB `heapOffset` in `initializeHeapMemory` (removed 2026-07-10).

### Cause

C's `extern` does two jobs that D splits into two separate features:

- `extern (C)` — **linkage attribute**: sets the symbol's name/ABI only.
  It says nothing about where the variable is defined.
- bare `extern` — **storage class**: "defined elsewhere, emit no storage."

So this, which reads perfectly fine to a C programmer:

```d
private extern (C) ubyte __heap_base; // WRONG: defines a variable!
```

*defines* a fresh 1-byte variable named `__heap_base` in `.bss`. wasm-ld only
synthesizes the real `__heap_base` (the first address past all static data)
when the symbol is undefined — since the object file now defines it, the D
variable wins. It lands at the start of `.bss`, so every zero-initialized
global in the program sits *after* it: the allocator believed the heap
started in the middle of the program's own globals. Initialized globals live
in `.data` below it, which made the corruption look like it only affected
some variables.

The same mistake bites outside linker magic: any D binding to an external C
global — `errno` or library-exported state on native, symbols from another
object file — silently becomes a second, separate variable. On native it may
also surface as a duplicate-symbol link error; on WASM the linker simply
skips synthesizing its symbol and nothing warns. Functions are immune
(bodyless declarations are automatically external); only variables have this
trap.

### Fix / rule

Bindings to external C globals need all three modifiers:

```d
private extern extern (C) __gshared ubyte __heap_base;
//      ^      ^          ^
//      |      |          └─ plain global, not thread-local (D globals default to TLS)
//      |      └─ linkage: symbol is literally named "__heap_base"
//      └─ storage class: defined elsewhere — emit no storage
```

Rule of thumb: if a variable declaration is meant to *reference* something
that already exists (linker symbol, libc global, another module's export), it
must carry the bare `extern` storage class and `__gshared`. `extern (C)`
alone always defines.

### How to diagnose

Link with `-L-Map=out.map` and find the symbol in the map: if it appears as
`yourobject.o:(.bss.__heap_base)` it is your (wrong) definition; the real
linker-synthesized symbol has no object file. At runtime, a healthy
`&__heap_base` sits past *all* globals — if taking the address of any D
global returns something larger, the symbol is being shadowed. See
`source/retrograde/wasm/memory.d` for the corrected declarations.
