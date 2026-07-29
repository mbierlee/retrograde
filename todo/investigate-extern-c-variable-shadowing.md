# TODO: Audit for other `extern (C)` variable declarations that define instead of reference

## Problem

`extern (C)` on a D variable is only a *linkage attribute* — without the bare
`extern` **storage class**, the declaration *defines* a fresh variable instead
of referencing an external one. This shadowed wasm-ld's `__heap_base` /
`__data_end` in `source/retrograde/wasm/memory.d` and made all
zero-initialized globals appear to live "on the heap"; the bogus 64 KiB
`heapOffset` workaround masked it for years (root-caused and fixed
2026-07-10). Full write-up: `docs/wasm-pitfalls.md`, section
"`extern (C)` variable declarations are *definitions*".

The same mistake may exist elsewhere, and will recur as native platform
implementations get written (bindings to `errno`, SDL/GL library globals,
symbols from other objects). It fails silently on WASM and only sometimes
loudly (duplicate symbol) on native.

## What to scan for

Any module-level **variable** declaration with a language linkage attribute
but no bare `extern` storage class, e.g.:

- `extern (C) <type> <name>;` — the memory.d bug shape.
- Also check `extern (C++)` / `extern (System)` / `extern (Windows)`
  variables if any exist.
- Functions are immune (bodyless declarations are automatically external) —
  do not flag them.

Suggested starting point (will over-match; filter out functions and
declarations that already carry the `extern` storage class):

```
rg "extern \((C|C\+\+|System|Windows)\)" source/ tools/ wasmtest/source/ --type d
```

For each hit that is a variable:

1. Decide intent: is it meant to *reference* an external symbol (linker,
   libc, JS side, another object) or to *define* engine-owned storage that C
   code links against?
2. If it references: it must be `extern extern (C) __gshared` (all three).
   Missing `__gshared` alone is also a bug — D globals default to TLS, and an
   external C symbol is one address, not one per thread.
3. If it defines on purpose: confirm nothing else (linker script, JS runtime,
   another object) is expected to provide the same symbol, and consider a
   comment stating the definition is intentional.

## Verification

- `make test-native` and `cd wasmtest && make run-tests-headless` after any
  change.
- For linker-provided symbols, `-L-Map=out.map` shows whether a symbol comes
  from an object file (shadowed) or is linker-synthesized — see the pitfalls
  doc's Diagnose section.

## Non-goals

- `source/retrograde/wasm/memory.d` is already fixed — use it as the
  reference for correct declarations.
- Do not "fix" intentional definitions (e.g. `export extern (C)` functions
  and engine-owned symbols the JS runtime imports).
