# Retrograde Engine — Copilot Instructions

## Overview

Retrograde is a D language game engine compiled with **`-betterC`** (no GC, no D runtime). It targets both **native** (Windows/Linux via DMD/LDC) and **WebAssembly** (via LDC). All standard library functionality is reimplemented from scratch in `source/retrograde/std/`.

## Build & Test

- **Build:** `make build-lib` (uses `dub build --config=library`)
- **Test:** `make test-native` (uses `dub test --config=unittest-native`, enables `Native` + `UnitTesting` versions)
- **WASM build:** from `wasmtest/`, `make build-wasm` (requires LDC2, targets `wasm32-unknown-unknown-wasm`)

## Critical Constraints (betterC)

- **No garbage collector.** All memory via `malloc`/`realloc`/`free` from `retrograde.std.memory`.
- **No D runtime features:** no `new`, no built-in arrays (`~` operator), no `Throwable`/exceptions, no `TypeInfo`, no `format`, no `writeln` from `std.stdio`.
- **No Phobos imports.** Only `core.stdc.*` on native. Use the engine's own `retrograde.std.*` modules.
- Use smart pointers: `UniquePtr`, `SharedPtr`, `ResultPtr` from `retrograde.std.memory`.
- Use `retrograde.std.string.String` (not D `string` literals for dynamic strings), `Array(T)` from `retrograde.std.collections` (not built-in slices for dynamic arrays).

## Platform Abstraction Pattern

Platform-specific code lives in parallel module trees, selected via `version`:

```
retrograde/native/  → version (Native)
retrograde/wasm/    → version (WebAssembly)
```

Facade modules in `retrograde/std/` re-export the correct platform implementation. Example: `retrograde.std.conv` publicly imports either `retrograde.native.conv` or `retrograde.wasm.conv`. Follow this pattern when adding platform-specific functionality.

## WASM Interop

On WebAssembly, functions that need OS or browser APIs are declared `extern (C)` in D and implemented in JavaScript via `webruntime/retrograde-runtime.js`. The runtime class provides:

- **IO bridge:** `writelnStr`, `writeErrLnStr`, etc. — typed print functions that map to `console.log`/`console.error`. D passes string pointers + lengths; JS reads from WASM linear memory via `TextDecoder`.
- **Number conversion:** `integralToString`, `scalarToString` — JS converts numbers to strings and writes back into D-allocated buffers via `writeString()`.
- **Math functions:** `powf`, `cosf`, `sinf`, `tan`, etc. — delegate to `Math.*`.
- **WebGL2 / GLES3 API:** `glCreateBuffer`, `glBindBuffer`, `glDrawElements`, `compileShaderProgram`, etc. — thin wrappers around `WebGLRenderingContext` methods. GL object handles are 1-based indices into JS-side arrays (`shaderPrograms`, `buffers`, `vertextArrayObjects`, `uniformLocations`).
- **Engine lifecycle:** `initWasmModule()` fetches and instantiates the `.wasm` binary, `startWasmModule()` calls `_start()`, `initEngine()` and `executeEngineLoopCycle(elapsedTimeMs)` drive the game loop from browser `requestAnimationFrame`.

When adding new `extern (C)` functions on the D/WASM side, you must also add matching implementations in `retrograde-runtime.js` under the `imports` object. Memory is shared via WASM linear memory — use pointer + length pairs for strings/arrays.

## Version Flags

Use D `version` conditions (not `#ifdef`). Key flags: `Native`, `WebAssembly`, `UnitTesting`, `MemoryDebug`, `OpenGLES3`, `DoublePrecision`, `Windows`. See README.md for full list.

## Entity Component System

- Components are identified by `StringId` (compile-time hashed `uint` via `sid("comp_name")`), not by type.
- Component data is stored as `void*` — use `getComponentData!T(entityId, componentType)` to retrieve typed `Option!(T*)`.
- Entity/component state is module-level globals in `retrograde.engine.entity`.
- Define new component types as: `enum MyComponentType = sid("comp_my_thing");`

## Testing Conventions

- Tests are **co-located** in the same file, after `version (UnitTesting) :` (trailing colon makes the rest of the file conditional).
- Each module provides a `run*Tests()` function (e.g., `runCollectionsTests()`).
- Register new test modules in `source/retrograde/test.d` by importing and calling the `run*Tests()` function.
- Use `test("description", () { ... })` from `retrograde.std.test` with `assert()` for validation.
- Group related tests with `writeSection("-- Section name --")`.

## Naming & Style

- Types: `PascalCase`. Functions/variables: `camelCase`.
- Component type constants: `enum XxxComponentType = sid("comp_xxx");`
- Math type aliases use suffixes: `F` (float), `D` (double), `I` (int), `U` (uint) — e.g., `Vector3F`, `Vector4I`.
- `scalar` type alias is `float` by default, `double` with `DoublePrecision`.

## Key Patterns

- **`CopyConstructors` mixin** (`retrograde.std.dlang`): Auto-generates copy constructor + `opAssign` via compile-time reflection. Mix into structs that need deep copy semantics.
- **Error handling:** Use `Result(T)` / `OperationResult` for fallible operations, `ResultPtr(T)` for heap allocations that can fail. Never use exceptions.
- **Optionals:** Use `Option(T)` with `some(val)` / `none!T`. Check `.isDefined()` before `.value()`.
- **Operator overloading:** Types extensively use `opIndex`, `opSlice`, `opApply`, `opEquals`, `opBinary`, `opOpAssign`, `opDispatch`. Follow existing patterns when extending.
- **Right-handed coordinate system**, Y-up, row-major matrices, negative-Z forward.
- **Asset formats:** See `docs/` for specifications of custom file formats (e.g., RGM model format).
