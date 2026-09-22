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
(construction) already works — via NRVO, which elides the copy entirely rather
than going through the copy constructor; only *re-assignment* of a temporary
into an existing variable is blocked. The asymmetry is surprising.

Note the compile error only appeared in the sandbox's `release`/`wasm` build,
not the earlier debug `wasmtest` build, because that config was the first to
actually instantiate the offending template path.

## Questions to answer

All of the below were checked against DMD 2.112.1 and LDC 1.42.0 with a
throw-away prototype on `Array`, since removed from the working tree.

- Should we add `void opAssign(typeof(this) other)` (by-value sink) or an
  explicit `void opAssign(ref ... other)` + rvalue overload pair? In betterC
  with no druntime, what does LDC actually generate for a by-value struct
  parameter here — a real move, or a copy-construct of the temporary followed
  by a destructor?

  **Neither pair form is possible — D has no rvalue references, so the two
  overloads cannot be told apart.** Adding `void opAssign(typeof(this))` beside
  the existing `ref inout` overload makes *every existing lvalue assignment* a
  hard error:

  ```
  Error: overloads `void(ref return scope inout(Arr))` and `void(Arr)`
         both match argument list for `opAssign`
  ```

  Making the sink a template (`void opAssign()(Arr other)`) does not break the
  tie either — same ambiguity.

  **Replacing the `ref` overload with a by-value copy-and-swap sink compiles for
  lvalues but regresses `const` sources.** `const Array!int c; Array!int a;
  a = c;` then fails with "none of the overloads of `opAssign` are callable
  using argument types `(const(Array!int))`" — the `inout` copy constructor
  cannot produce a *mutable* by-value parameter from a `const` lvalue. The
  current `ref inout` overload accepts it fine, so this would be a real loss.

  **What does work is a single `auto ref` template replacing the `ref`
  overload**, with the copy and move bodies selected at compile time:

  ```d
  void opAssign()(auto ref inout typeof(this) other) {
      static if (!__traits(isRef, other)) {
          // `other` is a temporary that dies at the end of this expression, so take
          // its buffer and hand ours over for its destructor to free.
          typeof(this)* source = cast(typeof(this)*) &other;
          T* oldItems = items;
          size_t oldLength = _length;
          size_t oldCapacity = _capacity;

          items = source.items;
          _length = source._length;
          _capacity = source._capacity;

          source.items = oldItems;
          source._length = oldLength;
          source._capacity = oldCapacity;
          return;
      } else {
          ... existing deep-copy body, unchanged ...
      }
  }
  ```

  The `cast` away of `inout` in the move branch is needed to write back into the
  temporary; it matches what the copy branch already does with
  `cast(T*) other.items`.

  As for codegen: **it is a real move.** With instrumented `malloc`/`free`
  counters, the rvalue branch performs zero copy-constructor calls and zero
  extra allocations, on DMD (debug) and `ldc2 -O3` alike. The temporary is
  constructed straight into the parameter slot; there is no copy-construct +
  destruct pair to optimise away.

- If we add a move-assign, it must **free `this`'s current `items`** before
  taking ownership of `other`'s buffer, then leave `other` in a destructible
  empty state (`items = null; _length = _capacity = 0;`) so its destructor
  doesn't double-free the buffer we just stole. Is that safe given how
  temporaries are destroyed at end of the full expression?

  **Yes, and a plain swap is simpler and strictly better than free-then-clear.**
  Rather than freeing our buffer and zeroing the source, hand our old buffer
  *to* the temporary: its destructor runs `clear()`, which destroys every live
  element in `[0 .. _length]` and then frees the block. The moved-from
  temporary is left holding a perfectly valid array, so it is destructible by
  construction — no "empty state" invariant to remember, and no window in which
  two owners share a pointer.

  Timing is not a hazard: the parameter is destroyed on callee exit, which is
  after the swap either way.

  Verified with an `Array!T` whose `T` counts live instances: assigning a
  5-element temporary over a live 3-element array leaves exactly 5 live (the 3
  overwritten elements are destroyed exactly once, not zero times and not
  twice), and 0 after scope exit. No double free, no leak.

- Does adding an rvalue overload create ambiguity with the existing
  `opAssign(ref inout typeof(this))` for ordinary lvalue assignment? D's
  overload resolution should prefer the `ref` for lvalues and the value/rvalue
  overload for temporaries, but confirm it doesn't silently change which
  overload existing call sites bind to.

  **It does not silently rebind — it refuses to compile** (see the first
  question). The `auto ref` form has no ambiguity at all, because there is only
  one identity overload left. Confirmed to still take the copy branch for:
  mutable lvalues, `const` lvalues, self-assignment (`a = a`), struct fields,
  and static-array elements; and the separate `opAssign(scope inout T[])` slice
  overload still wins for slices. The `CopyConstructors` mixin is unaffected —
  it filters template *members* of the struct it is mixed into, and an `Array`
  field is still a plain variable.

  Both suites pass with the prototype in place: **864 native tests, 926 WASM
  tests**, including the existing `InnerArrayOwner` / `CopyConstructors` cases
  and the `opAssign` capacity regression tests.

- Same treatment for the other hand-rolled value containers? Every owning
  container has the identical lvalue-ref-only shape and fails on rvalue
  assignment the same way, so whatever is decided here is a six-type change:
  - `Array` — [collections.d:267](source/retrograde/std/collections.d#L267)
  - `SlotList` — [collections.d:1114](source/retrograde/std/collections.d#L1114)
  - `LinkedList` — [collections.d:1587](source/retrograde/std/collections.d#L1587)
  - `HashMap` — [collections.d:2015](source/retrograde/std/collections.d#L2015)
  - `Queue` — [collections.d:2662](source/retrograde/std/collections.d#L2662)
  - `String` — [string.d:41](source/retrograde/std/string.d#L41)

  **Yes, same treatment, but each swap has to list that container's own
  fields**: `SlotList` also carries `serials` / `nextSerial`, `LinkedList` its
  node chain, `HashMap` its buckets, `Queue` its head/tail indices, `String` its
  buffer.

  Only `Array` was prototyped, and its single flat buffer is the easy case.
  **`HashMap` and `LinkedList` are the open risk.** Before swapping either,
  confirm all of their owning state is reachable from their fields and that
  nothing points *back* into the container — a node chain whose nodes hold a
  pointer to their owning list, or a bucket table storing anything derived from
  the container's own address, would survive a field swap as a dangling
  reference, and the move would be silently wrong rather than failing to
  compile. `Queue` needs the same check on its head/tail indices: they must
  index into the swapped buffer, not point into the old one.

  `String` is the one with the same urgency as `Array` — returning a built-up
  `String` by value is just as natural as returning an `Array`, and it fails
  identically today.

- Would a free `move()` helper (à la `core.lifetime.move`) be a cleaner,
  more explicit answer than an implicit rvalue `opAssign`, given the codebase
  already avoids hidden copies elsewhere?

  **It works and needs no overload surgery at all** — a *uniquely named*
  function can take the container by value, because there is nothing for it to
  be ambiguous with:

  ```d
  void moveInto(ref Array!T dest, Array!T source) { ...swap... }
  pixels.moveInto(expandGrayscaleToRgb(*image));
  ```

  Verified copy-free and balanced (no leak, no double free) on the same
  instrumented harness.

  **Recommendation: the `auto ref` `opAssign`, not the helper.** The complaint
  in this ticket is precisely that plain `=` surprises people; a helper swaps
  one unwritten rule ("never return an `Array`") for another ("assign a
  returned `Array` only via `moveInto`"), and gives a worse error when it is
  forgotten. The move is also not an observable behaviour change: deep-copy
  semantics are preserved for every lvalue, and a temporary has no other
  observer to notice its buffer was taken. A `moveInto` helper is still worth
  having separately for moving *between lvalues* (`a.moveInto(b)`), which
  `opAssign` deliberately will not do.

## Incidental finding (belongs to a different ticket)

While instrumenting element lifetimes, the **existing lvalue copy path was found
to leak elements with non-trivial destructors**, independently of anything
proposed here. `opAssign` `realloc`s the buffer and `memset`s it to zero without
destroying the elements already living there, so assigning a 4-element array
over a live 2-element `Array!T` leaves those 2 `T`s never destructed. Confirmed
pre-existing: the counts are identical with the unmodified `opAssign`.

This is the same class of defect as
[investigate-collection-destructors.md](investigate-collection-destructors.md)
and should be fixed there. Note the move path proposed above does *not* have
this problem — it routes the overwritten buffer through a destructor.

## Why this matters

Returning an owning `Array` by value is the natural way to write a builder /
transform function. Forcing every such function into an out-param signature
spreads a non-obvious constraint across the codebase and makes the API read
worse than it needs to. Fixing the assignment path once removes a whole class
of "why won't this compile / why did it crash in release" papercuts.

## Tasks

- [x] Reproduce in isolation: confirmed, and confirmed fixed by the `auto ref`
      overload.
- [x] Prototype the move-assign overload; verified no double-free and no leak
      of the overwritten buffer, using an element type that counts live
      instances. (`MemoryDebug` is WASM-allocator-only, so it does not apply to
      the native run; the element counter covers both targets.)
- [x] Check overload-resolution impact on existing lvalue `opAssign` call sites:
      no silent rebinding possible — the naive pair form simply does not
      compile, and the `auto ref` form keeps every lvalue on the copy branch.
- [x] Decide: `auto ref` `opAssign`, with an optional `moveInto` helper for
      lvalue-to-lvalue moves.
- [x] Apply the `auto ref` `opAssign` to `Array`, with unit tests covering the
      move path.
- [x] Apply the same to `String`, `SlotList`, `LinkedList`, `HashMap` and
      `Queue`, swapping each container's own fields.
- [x] Revisit the opengles3 texture helpers — they now return `Array!ubyte`
      again instead of taking a `ref` out-param.

## Resolution — implemented

- `swapFields` added to [dlang.d](source/retrograde/std/dlang.d) as the shared
  move primitive; each container's `opAssign` became an `auto ref` template
  dispatching to a private `copyAssign` (the previous body, unchanged) for
  lvalues and to a field swap for rvalues.
- Applied to all six: `Array`, `SlotList`, `LinkedList`, `HashMap`, `Queue`,
  `String`. The `HashMap` / `LinkedList` risk noted above was checked and is
  not real: `LinkedListNode` is value/next/prev and `BucketNode` is
  key/value/next, neither points back at its container, `HashMap` derives
  bucket indices from the hash and `_bucketCount`, and `Queue.head` is an index
  into the buffer. All owning state is reachable from the fields alone.
- Tests: a `runMoveAssignmentTests()` section covering all six. Moves are
  proven by buffer identity — the destination ends up owning the exact buffer
  the temporary built — with the lvalue test asserting the opposite as a
  counterpart, plus live-element counts showing the overwritten elements are
  destroyed exactly once.
- Verified: 872 native tests, 934 WASM tests, and both sandbox WASM builds
  (release and debug), which are what compile `api/opengles3.d` and what the
  original compile error came from.

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
