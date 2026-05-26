# TODO: Investigate Array.opAssign / copy-construction crash under release optimization

## Problem

In release builds, iterating an `Array!T` of structs that themselves own inner
`Array` fields and copying each element by value caused heap/stack corruption
that manifested as a segfault in unrelated code (typically a `0x10` jump
target). The exact same code path ran cleanly in debug.

Concrete reproducer that triggered this:

```d
// In source/retrograde/data/assets/rgm.d, removed in commit XXXX:
private OperationResult validateMeshMaterialReferences(Model* model) {
    for (size_t m; m < model.meshes.length; m++) {
        MaterialIndex meshIndex = model.meshes[m].materialIndex;
        ...
    }
}
```

`model.meshes[m]` returns a `Mesh` by value, which the `CopyConstructors` mixin
turns into per-field assignment. For `Mesh`'s three inner `Array` fields, that
runs `Array.opAssign`, which does:

```d
T* newItems = cast(T*) realloc(items, T.sizeof * other._length);
```

`realloc(items, ...)` is only safe if `items` is either `null` or a valid heap
pointer. The mixin relies on `this.items` being `null` at this point because
D's spec says struct fields are default-initialized to `.init` before a
constructor body runs.

Under release-mode inlining the whole chain collapses
(`opIndex` → Mesh copy ctor → three `Array.opAssign` calls → Mesh dtor → three
`Array` destructors). If the optimizer ever reuses the temporary's stack slot
or elides the default-initialization it considers redundant, `this.items` is
read as garbage and handed to `realloc`. That's enough to corrupt unrelated
heap blocks and the caller's stack frame.

The bug was worked around in `validateMeshMaterialReferences` by iterating
through `model.meshes.arr()` and using `foreach (ref ...)` so no Mesh copy is
ever made. The underlying issue in `Array` / `CopyConstructors` is unfixed.

## Why this matters beyond this one call site

Every container of structs-with-inner-Arrays is one careless `opIndex` away
from the same crash. The current "fix" — "always use `arr()` for iteration" —
is the kind of rule that gets forgotten exactly when it matters. The pattern
should be safe regardless of how the caller chooses to access elements.

## Questions to answer

- Is the optimizer actually skipping the default-init of `this` in the copy
  constructor, or does the corruption come from a different spot in the
  copy/destroy chain (e.g. `Array.opAssign`'s `_capacity = other._capacity`
  even though it only allocates `other._length` slots)?
- Does the `if (this is other) return;` short-circuit in `Array.opAssign` do
  what's intended? `is` on struct lvalues compares bits, not addresses — for a
  freshly default-initialized `this` and a populated `other` they'd differ, but
  it's worth confirming this doesn't accidentally match under inlining.
- Does the bug reproduce with a postblit (`this(this)`) instead of the
  `CopyConstructors` `this(ref ...)` mixin? Postblit gets a bitwise-copied
  `this` rather than a default-initialized one — opposite assumption.
- Does it reproduce with LDC as well as DMD? Different optimizers, same
  language spec — useful for distinguishing "compiler bug" from "fragile but
  legal" code.

## Tasks

- [ ] Write a minimal reproducer outside the engine: a struct with one
      `Array!ubyte` field, a `CopyConstructors` mixin, and a loop that does
      `arr[i]` by value in a release build. Confirm it crashes.
- [ ] Bisect what fixes it in isolation: explicit `this.items = null;` at the
      top of `Array.opAssign`, replacing the mixin with a hand-rolled
      `this(ref)` that explicitly nulls inner fields first, switching to
      postblit, etc.
- [ ] If the root cause is in `Array.opAssign`, harden it: treat `this` as
      possibly-uninitialized on entry (don't trust `items` to be `null` or
      valid). Probably means doing the allocation into a local first and only
      writing `items = newItems` at the end, never calling `realloc` on
      `items`.
- [ ] If the root cause is in `CopyConstructors`, make it explicit. Either zero
      out `this` via `memset` at the top of the mixin's `this(ref)`, or switch
      the mixin to postblit semantics where the bitwise copy of inner pointers
      is then re-allocated (similar to how D's classic `this(this)` handles
      reference-typed members).
- [ ] Add a regression test that exercises the previously-broken pattern:
      iterate an `Array!Mesh` (or equivalent) with `meshes[i].field` in a
      release build and confirm no crash.
- [ ] Audit other places in the engine that use the same `container[i].field`
      pattern over a struct with inner `Array`/`String` members. Likely
      candidates: anywhere we touch `model.meshes`, `model.materials`,
      `entity.d` storage, anything iterating `LinkedList`/`SlotList` by value.
- [ ] Decide on a convention: either fix the copy path so by-value is safe, or
      document loudly that iterating containers of non-trivial structs **must**
      go through `arr()` / a `ref` iterator. The current state — works in
      debug, crashes in release — is the worst of both.

## Related

- [investigate-collection-destructors.md](investigate-collection-destructors.md)
  — adjacent concern. If `clear()` and the `Array` destructor don't reliably
  run `~this` on every live element, that interacts badly with anything that
  fixes copy semantics here. The two should probably be audited together.
- [investigate-required-copy-constructors.md](investigate-required-copy-constructors.md)
  — same `CopyConstructors` mixin, different fragility. If the mixin gets
  reworked for one, both should be revisited.
