# WebAssembly Pitfalls

Gotchas that only surface in the WASM build. Code that is technically wrong in
the same way on native often passes there by ABI luck, so "native tests are
green" is not proof that the WASM build is fine.

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
