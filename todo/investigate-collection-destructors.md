# TODO: Investigate destructor handling in collections

## Problem

The containers in `source/retrograde/std/collections.d` (`Array`, `SlotList`,
`LinkedList`, `HashMap`, etc.) hold values by value. When an item is removed,
overwritten, or the container shrinks/clears, the slot occupied by the dropped
element must have its destructor run — otherwise any `T` that owns memory via
`~this` (e.g. `String`, nested `Array`, `UniquePtr`, `SharedPtr`) silently leaks.

A concrete example was spotted in `Array.remove(size_t index)`
(`source/retrograde/std/collections.d:159`):

- **Last-element case** (`index == _length - 1`): just decrements `_length`. The
  trailing slot still holds a fully constructed `T`; its destructor never fires.
- **Shift case**: `items[i] = items[i + 1]` invokes `opAssign` on the
  intermediate slots, which (for well-behaved types like `String`) frees the old
  buffer before copying — that part is fine. But after the shift, the slot at
  the *new* `items[_length]` still holds a duplicate of the previous last
  element, with its own allocated resources. `_length--` makes the container
  "forget" it without running `~this`.

This currently does not bite `Array!Component` in `entity.d` because `Component`
is POD-ish, but it would leak for `Array!EntityEntry` (holds `String name`) and
any other container of types with non-trivial destructors. See also the related
`SlotList!EntityEntry` storage in `entity.d` — slot reuse / removal paths there
need the same audit.

## Plan

Audit every removal / overwrite / shrink path in
`source/retrograde/std/collections.d` and ensure the dropped slot's destructor
runs exactly once. Prefer `destroy(items[i])` over calling `__dtor` /
`__xdtor` directly — `destroy()` lets the compiler pick the right thing based
on `T` (struct vs. class, with/without postblit, etc.) and handles edge cases
like elaborate destructors automatically.

Watch for double-destruction: if a slot is moved out via `opAssign` and the
source slot is then destroyed, you may end up freeing the same resource twice
unless the source is reset to `T.init` first (or the move uses
`core.lifetime.move` semantics).

## Containers / methods to audit

At minimum:

- `Array(T)`
  - `remove(size_t index)` — last-element decrement and post-shift tail slot.
  - `replace(size_t index, T newItem)` — `opAssign` handles it for well-behaved
    `T`, but worth confirming.
  - `clear()` — claims in the docstring to call destructors; verify it actually
    does for every `T`.
  - Any `pop` / `removeLast` / `shrink` / capacity-shrinking paths.
  - Destructor of `Array` itself — does it destroy the live `[0 .. _length]`
    range before freeing the backing buffer?
- `SlotList(T)`
  - `remove(size_t)` / `remove(Slot)` — when a slot is freed, the stored `T`
    needs `~this`.
  - Slot reuse on `add` — the old occupant of a reused slot must be destroyed
    before the new value is placed (or the placement must go through `opAssign`
    which destroys for you).
  - Container destructor.
- `LinkedList(T)`
  - `removeFirst`, `removeLast`, `removeAll`, `removeWhere`, `removeFirst(T)`,
    `removeItems`, plain `remove()` on iterators.
  - Node freeing paths — the `T` inside the node needs destruction before the
    node memory is freed.
  - Container destructor.
- `HashMap(K, V)`
  - `remove(K)` — both `K` and `V` slots need destruction.
  - Rehash / resize paths — moving entries between buckets must not leak the
    old slot.
  - Container destructor.

## Tasks

- [ ] Read each container's removal / overwrite / shrink / clear / destructor
      paths and document which ones currently skip `~this`.
- [ ] Write a small reusable test helper `struct DtorCounter { static int count;
      ~this() { count++; } }` (or similar) and add unit tests per container that
      assert the destructor fires exactly once per dropped element across all
      removal paths.
- [ ] Fix each leak by inserting `destroy(items[i])` (or the equivalent for the
      container's storage) at the right point. Prefer `destroy()` over
      `__dtor`/`__xdtor` so the compiler picks the right call.
- [ ] Watch for double-destruction after fixes: if a shifted-from slot is
      destroyed *and* its resources were already moved via `opAssign`, you'll
      double-free. Reset moved-from slots to `T.init` or use a real move
      primitive.
- [ ] Re-check the call sites that motivated this investigation:
      `Array!Component.remove` in `entity.d:264`, and `SlotList!EntityEntry`
      removal in `entity.d`.
- [ ] Confirm `clear()` and the `Array` destructor actually destroy
      `[0 .. _length]` before releasing the backing buffer — the existing
      docstring on `clear()` claims so; verify.
