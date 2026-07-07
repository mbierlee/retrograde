# Investigate adding an rvalue / move `opAssign` for `Array`

## Problem

`Array(T)` in [source/retrograde/std/collections.d](source/retrograde/std/collections.d)
only defines two `opAssign` overloads:

```d
void opAssign(ref return scope inout typeof(this) other) { ... } // lvalue copy
void opAssign(scope inout T[] other) { ... }                     // slice copy
```

There is no overload that accepts an **rvalue** `Array` (a temporary), so
assigning the result of a function that returns an `Array` by value fails to
compile:

```d
Array!ubyte pixels;
pixels = expandGrayscaleToRgb(*image); // Error: none of the overloads of
                                       // `opAssign` are callable using argument
                                       // types `(Array!(ubyte, 8u))`
```

This surfaced while wiring the unlit material texture upload in
[source/retrograde/api/opengles3.d](source/retrograde/api/opengles3.d). The
work-around was to make the helpers take a `ref Array!ubyte` out-param and
append into an already-declared lvalue instead of returning a fresh `Array`:

```d
// Instead of: expandedPixels = expandGrayscaleToRgb(*image);
private void expandGrayscaleToRgb(const ref Image image, ref Array!ubyte rgb) { ... }
expandGrayscaleToRgb(*image, expandedPixels);
```

It works, but "helpers must fill an out-param, never return an `Array`" is
another unwritten rule that will be forgotten. `auto x = makeArray();`
(construction) already works via the copy constructor; only *re-assignment* of
a temporary into an existing variable is blocked. The asymmetry is surprising.

Note the compile error only appeared in the sandbox's `release`/`wasm` build,
not the earlier debug `wasmtest` build, because that config was the first to
actually instantiate the offending template path.

## Questions to answer

- Should we add `void opAssign(typeof(this) other)` (by-value sink) or an
  explicit `void opAssign(ref ... other)` + rvalue overload pair? In betterC
  with no druntime, what does LDC actually generate for a by-value struct
  parameter here — a real move, or a copy-construct of the temporary followed
  by a destructor?
- If we add a move-assign, it must **free `this`'s current `items`** before
  taking ownership of `other`'s buffer, then leave `other` in a destructible
  empty state (`items = null; _length = _capacity = 0;`) so its destructor
  doesn't double-free the buffer we just stole. Is that safe given how
  temporaries are destroyed at end of the full expression?
- Does adding an rvalue overload create ambiguity with the existing
  `opAssign(ref inout typeof(this))` for ordinary lvalue assignment? D's
  overload resolution should prefer the `ref` for lvalues and the value/rvalue
  overload for temporaries, but confirm it doesn't silently change which
  overload existing call sites bind to.
- Same treatment for `String` and any other hand-rolled value container with
  the identical two-overload shape? If we fix `Array`, `String` almost
  certainly wants the same for consistency.
- Would a free `move()` helper (à la `core.lifetime.move`) be a cleaner,
  more explicit answer than an implicit rvalue `opAssign`, given the codebase
  already avoids hidden copies elsewhere?

## Why this matters

Returning an owning `Array` by value is the natural way to write a builder /
transform function. Forcing every such function into an out-param signature
spreads a non-obvious constraint across the codebase and makes the API read
worse than it needs to. Fixing the assignment path once removes a whole class
of "why won't this compile / why did it crash in release" papercuts.

## Tasks

- [ ] Reproduce in isolation: a function returning `Array!ubyte` by value and a
      caller that assigns it to a pre-declared `Array!ubyte`. Confirm the
      compile error, then confirm behavior once an rvalue `opAssign` is added.
- [ ] Prototype the move-assign overload; verify no double-free and no leak of
      the overwritten buffer (test with `MemoryDebug`).
- [ ] Check overload-resolution impact on existing lvalue `opAssign` call sites.
- [ ] Decide: implicit rvalue `opAssign` vs. an explicit `move()` helper.
- [ ] If adopted, revisit the opengles3 texture helpers — they could go back to
      returning `Array!ubyte` instead of taking a `ref` out-param.

## Related

- `Array.opAssign` was separately investigated (resolved, ticket removed) for a
  suspected "corrupts memory under release inlining because it trusts
  `this.items`" bug. That premise was disproven: indexing a container by value
  goes through the copy *constructor* (which allocates fresh), not `opAssign`,
  on DMD debug/release and LDC `-O3` alike. The real defect was a
  capacity/allocation mismatch — `opAssign` set `_capacity = other._capacity`
  while allocating only `other._length` slots — now fixed with regression tests.
  Still relevant to a move-assign added here: it must free `this`'s current
  buffer and leave the moved-from temporary in a destructible empty state to
  avoid a double-free.
- [investigate-required-copy-constructors.md](investigate-required-copy-constructors.md)
  — same `CopyConstructors` mixin / value-semantics area.
