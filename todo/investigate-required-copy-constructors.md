# TODO: Investigate why explicit copy constructors are required when String members are introduced

## Problem

Structs across the codebase hand-roll three boilerplate members as soon as they gain a member of a
non-trivially-copyable type such as `retrograde.std.string.String`:

```d
this(ref return scope inout typeof(this) other) { ... }
void opAssign(ref return scope inout typeof(this) other) { ... }
void opAssign()(typeof(this) other) { ... }
```

`OperationResult` and `Result(T)` in `source/retrograde/std/result.d` grew these once `_errorMessage`
changed from a D `string` to a `String`.

**The stated premise turns out to be mostly wrong** — see findings below. A single `String` member
does not require any of this, and the boilerplate is actively harmful in at least one case.

## Findings (2026-08-05, LDC 1.42, `-betterC`, native)

All of the below were verified by compiling minimal reproductions.

### The actual trigger

The compiler stops auto-generating a usable copy constructor only when a struct has **two or more
members that each have an `inout` copy constructor**. One such member is fine; a second breaks it.

| struct members | auto-generated copy works? |
| --- | --- |
| `String s;` | yes |
| `bool f; String s;` | yes |
| `String s; void* p;` | yes |
| `String s; int i;` | yes |
| `String a; String b;` | **no** |

The failure message is:

```
Error: generating an `inout` copy constructor for `struct S` failed, therefore instances of it are uncopyable
```

For `Result(T)` this means the boilerplate is only needed when `T` itself has an `inout` copy
constructor (e.g. `Result!String`), because `_errorMessage` is then the second such member.

### The boilerplate is not merely unnecessary — it breaks pointer payloads

With all three hand-rolled members removed from a `Result(T)`-shaped struct, `Result!int`,
`Result!Event` and `Result!(struct holding a void*)` all copy-construct, lvalue-assign, rvalue-assign
and pass by value correctly on the compiler's own generated functions.

The hand-written `this(ref return scope inout typeof(this))` is what made `Queue!Event` fail to
compile: its `static if (is(T == struct)) { this._value = other._value; }` branch forces an
`inout(Event)` -> `Event` conversion, which is illegal because `Event.eventData` is a `void*` (a
mutable indirection). The compiler's generated copy constructor never attempts that conversion.

So `result.d`'s hand-rolled members are strictly worse than the default for any payload with mutable
indirections. Narrowing them to only the case that needs them is the real fix; see Tasks.

### Why the third form exists

`void opAssign()(typeof(this) other)` is needed purely for **rvalue assignment** (`x = Result!T(...)`)
— a `ref` parameter cannot bind an rvalue. It is a template so that the non-template `ref` overload
wins for lvalues; otherwise the two are ambiguous.

The `inout`-vs-`const` question for the first two forms was not investigated.

### How far `CopyConstructors` can go

`retrograde.std.dlang.CopyConstructors` was extended (this session) with a cast fallback for members
that have mutable indirections:

```d
static if (__traits(compiles, mixin("this." ~ member ~ " = other." ~ member))) {
    mixin("this." ~ member ~ " = other." ~ member ~ ";");
} else {
    mixin("this." ~ member ~ " = cast(typeof(this." ~ member ~ ")) other." ~ member ~ ";");
}
```

With that in place the mixin covers copy-construction, lvalue assignment and pass-by-value for both
the two-`String` case and the pointer case. Members that already handle `inout` themselves (`String`
and friends) keep taking the first branch untouched.

Caveat: the cast branch is a **shallow** copy. The copy shares the pointee and neither instance owns
it. Correct for `Event.eventData`; wrong for any pointer field the struct is expected to own.

The third form **cannot** move into the mixin. Adding `void opAssign()(typeof(this) other)` there
yields:

```
Error: overloads `void(ref return scope inout(S) other)` and `(S other)` both match argument list for `opAssign`
```

As direct struct members the non-template beats the template; introduced through a mixin that
preference does not apply. A struct needing rvalue assignment still hand-rolls that one method.

### Already applied

- `source/retrograde/std/dlang.d` — cast fallback in both `CopyConstructors` methods.
- `source/retrograde/engine/event.d` — `Event` now uses `mixin CopyConstructors!Event;`.
- Verified: `make test-native` (495 tests) and `wasmtest` `make run-tests-headless` (557 tests) pass;
  the sandbox `wasm` release build compiles.

## Tasks

- [x] Reproduce the failure modes in a minimal test (struct with a single `String` member, try
      copying / assigning / passing by value, with and without `const` / `inout`).
- [ ] Document the root cause in a short note (likely in `docs/betterc-pitfalls.md` or alongside
      `CopyConstructors`), including the two-inout-member trigger table above.
- [ ] Narrow the hand-rolled members in `result.d`. `Result(T)`'s `inout` copy constructor should not
      exist for payloads that don't need it — it is what breaks `Result!Event`. Consider gating on
      `__traits(compiles, ...)` or dropping the copy constructor and `ref` `opAssign` entirely and
      keeping only the rvalue `opAssign`.
- [ ] Audit existing hand-rolled copy constructors elsewhere in the codebase and drop them where the
      compiler's generated ones suffice (single inout-copyable member), or replace with the mixin.
- [ ] Decide whether the mixin's shallow-copy cast branch should be opt-in, so an owning pointer
      field cannot be aliased by accident.
- [ ] Decide what to do about the `!__traits(isStaticArray, ...)` guard in both mixin methods.
      It dates from the mixin's first commit (`107cb4ac`) with no recorded reason, and it makes
      the mixin **silently drop static array members**: the copy keeps whatever the field's
      default initializer says, with no error at compile time or run time. Hit for real while
      adding a `float[4] baseColorFactor` to `Material` (2026-08-26) — every copy reset it to
      `[1,1,1,1]`, which surfaced only as a failing assert in an RGM loader test. Worked around
      by making it a `BaseColorFactor` struct of four named floats
      (`source/retrograde/assets/model.d`). Establish whether static arrays actually break the
      `inout` copy (a `float[4]` copies fine by hand), and if not, drop the guard — a plain
      `this.member = other.member` covers them.
