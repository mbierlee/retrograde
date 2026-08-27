# Retrograde Engine — Agent Instructions

## Overview

Retrograde is a D language game engine compiled with **`-betterC`** (no GC, no D runtime). It targets both **native** (Windows/Linux via DMD/LDC) and **WebAssembly** (via LDC). Most standard library functionality is reimplemented from scratch in `source/retrograde/std/`.

## Build & Test

- **Build:** `make build-lib` (uses `dub build --config=library`). **NOTE:** building the native lib does not currently work — several native platform implementations are still missing, so the link/build fails. Do not rely on `make build-lib` to verify changes; prefer running the native unit tests instead.
- **Test:** `make test-native` (uses `dub test --config=unittest-native`, enables `Native` + `UnitTesting` versions). This is the preferred way to verify changes.
- **WASM build:** from `wasmtest/`, `make build-wasm` (requires LDC2, targets `wasm32-unknown-unknown-wasm`)
- **WASM test:** from `wasmtest/`, `make run-tests-headless` (builds the suite and runs it under Node via `run-tests-headless.mjs`; exits non-zero on a trap or failed assert). Use this to check that a change also holds up on WASM — a green native suite does not prove it.
- **Shaders:** nothing above compiles GLSL — the shaders in `source/retrograde/shaders/` are only compiled by the browser at runtime, so a broken one passes every suite. Check them with `glslangValidator`, substituting the engine's placeholder first:

  ```
  sed 's/<%maxLights%>/8/' <shader>_vertex.glsl > /tmp/x.vert
  sed 's/<%maxLights%>/8/' <shader>_fragment.glsl > /tmp/x.frag
  glslangValidator -l /tmp/x.vert /tmp/x.frag
  ```

  `-l` links the pair, which is what catches a mismatch between the vertex shader's outputs and the fragment shader's inputs. Run it for **each** `maxLights` value (0, 4, 8, 16, 32) — the `#if MAX_LIGHTS > 0` blocks compile differently, and 0 is easy to break without noticing. Use the default OpenGL semantics, **not** `-V`: Vulkan semantics reject the plain non-opaque uniforms these shaders use.

  **Only run this when `glslangValidator` is already installed system-wide** (it is on `PATH`). Do **not** install it yourself — no `apt install`, no npm package, no downloaded binary. If it is missing, say so and leave the shaders unvalidated rather than pulling in a copy.

## Critical Constraints (betterC)

- **No garbage collector.** All memory via `malloc`/`realloc`/`free` from `retrograde.std.memory`.
- **No D runtime features:** no `new`, no built-in arrays (`~` operator), no `Throwable`/exceptions, no `TypeInfo`, no `format`, no `writeln` from `std.stdio`.
- **No Phobos imports.** Only `core.stdc.*` on native. Use the engine's own `retrograde.std.*` modules.
- Use smart pointers: `UniquePtr`, `SharedPtr`, `ResultPtr` from `retrograde.std.memory`.
- Use `retrograde.std.string.String` (not D `string` literals for dynamic strings), `Array(T)` from `retrograde.std.collections` (not built-in slices for dynamic arrays).

**Note:** The betterC constraints apply to the engine code in `source/retrograde/`. Tools in `./tools/` (e.g., `rgmodelconv`) are stand-alone D programs that are **not** compiled with `-betterC` and **can use** the standard library (Phobos) and full D runtime features.

## Known Compiler Traps

Constructs that compile clean but fail at link time or at runtime. Both docs are written as Symptom / Cause / Fix — read the relevant one before spending time debugging a mysterious build or WASM failure.

- **`docs/betterc-pitfalls.md`** — traps from `-betterC` itself, on any target. Most important: never pass a bare array literal to a parameter that takes a slice. Inside a lambda that also involves a template, the "requires the GC" error is swallowed and the lambda's body is silently dropped, so the only symptom is an `undefined reference to ...__lambda_L<line>_C<col>...` at link time. Use `static immutable T[N] x = [...];` and pass `x[]`.
- **`docs/wasm-pitfalls.md`** — traps that only surface on WASM, where native passes by ABI luck. Most important: do not declare a struct with a template mixin inside a test lambda (it makes the lambda take a hidden context pointer and `call_indirect` traps) — hoist it to module scope in the `version (UnitTesting)` section. Also: bindings to external C globals need `extern extern (C) __gshared`, since `extern (C)` alone *defines* a variable.

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

**Keep the `gl*` methods in `retrograde-runtime.js` thin.** Each should simply relay its arguments to the corresponding `glContext` method — the only extra work permitted is reading buffer/string data out of WASM linear memory (e.g. `getFloat32Array`, `getUint8Array`) and the occasional handle caching (e.g. the `uniformLocations` dict). Do not bury implicit GL state changes (extra `pixelStorei`, `bindTexture`, parameter setup, etc.) inside these wrappers: that behavior belongs in the D renderer so it stays explicit and survives a future port to native OpenGL.

**Only edit `webruntime/retrograde-runtime.js`.** The copy at `wasmtest/web/retrograde-runtime.js` is generated — the `copy-runtime` target (run automatically by `make build-wasm`) overwrites it from `webruntime/`. Editing the `wasmtest/web/` copy directly will have your changes clobbered on the next build.

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
- Always use braces for control flow and scope blocks (`if`, `else`, `while`, `for`, `scope`, etc.), even for single-statement bodies. The body must be on a separate line from the condition:
 ```d
 // correct
 if (condition) {
     doSomething();
 }

 // wrong
 if (condition) doSomething();
 if (condition) { doSomething(); }
 if (condition)
     doSomething();
```

## Key Patterns

- **`CopyConstructors` mixin** (`retrograde.std.dlang`): Auto-generates copy constructor + `opAssign` via compile-time reflection. Mix into structs that need deep copy semantics.
- **Error handling:** Use `Result(T)` / `OperationResult` for fallible operations, `ResultPtr(T)` for heap allocations that can fail. Never use exceptions.
- **Optionals:** Use `Option(T)` with `some(val)` / `none!T`. Check `.isDefined()` before `.value()`.
- **Operator overloading:** Types extensively use `opIndex`, `opSlice`, `opApply`, `opEquals`, `opBinary`, `opOpAssign`, `opDispatch`. Follow existing patterns when extending.
- **Right-handed coordinate system**, Y-up, row-major matrices, negative-Z forward. That is the 3D world only: positions over the 2D window, such as the mouse, are Y-down from its top left corner on every platform.
- **Asset formats:** See `docs/` for specifications of custom file formats (e.g., RGM model format).
