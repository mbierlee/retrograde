# TODO: Investigate why explicit copy constructors are required when String members are introduced

## Problem

Structs across the codebase hand-roll copy boilerplate as soon as they gain a member of a
non-trivially-copyable type such as `retrograde.std.string.String`. Every `String`-holding struct in
the engine does this today (`Texture`, `AssetEntry`, `EntityEntry`, `ResultPtr(T)`, `Result(T)`,
`OperationResult`). `result.d` is the only one that carries all three forms:

```d
this(ref return scope inout typeof(this) other) { ... }
void opAssign(ref return scope inout typeof(this) other) { ... }
void opAssign()(typeof(this) other) { ... }
```

`OperationResult` and `Result(T)` in `source/retrograde/std/result.d` grew these once `_errorMessage`
changed from a D `string` to a `String`.

**The premise is correct.** An earlier revision of this note (2026-08-05) concluded it was "mostly
wrong" because a single `String` member copied fine in a minimal test. That test only holds for a
program containing exactly one `String`-holding struct; see below.

## Findings (2026-09-15, LDC 1.42 and DMD 2.112, `-betterC`, native)

Every claim here was verified by compiling a real file and reading the compiler's exit code and
errors. Do not verify these with `__traits(compiles, { ... })`: it swallowed errors on a bare
`R!int` that a real compile accepted, and gave the opposite answer on several other cases.

### The actual trigger

The compiler generates `this(ref return scope inout typeof(this) rhs) inout` for a struct with
copy-constructible members. To do so it needs every member's copy constructor to be callable to
construct an `inout` object. `String`'s copy constructor is not: it delegates to `copyFrom`, which
mutates `this`. DMD's `-verrors=spec` shows the underlying error:

```
Error: none of the overloads of `this` can construct a `inout` object with argument types `(inout(StringT!char))`
```

The visible error is then:

```
Error: generating an `inout` copy constructor for `struct S` failed, therefore instances of it are uncopyable
```

**Any struct with a `String` member is therefore uncopyable without its own copy constructor.**

What made the earlier note believe otherwise: with the real `String`, the *first* `String`-holding
struct analysed in a compilation does get a working generated copy, and every later one fails.
This holds regardless of member layout, whether the first struct is ever used, whether it lives in
another module, and whether the modules are compiled together or separately. A non-template
stand-in with the same constructor shape fails even for the first struct, so the first-one-wins
behaviour is a template caching quirk in the compiler, not the rule.

| program contents | generated copy works? |
| --- | --- |
| one struct `{ String s; }` | yes |
| one struct `{ String s; int i; }` or `{ String s; void* p; }` | yes |
| one struct `{ String a; String b; }` | **no** |
| `struct A { String s; }` plus `struct B { String s; }`, any layout | A yes, **B no** |

The engine always compiles far more than one such struct, so in practice the last row is the only
one that matters.

### The hand-rolled copy constructor breaks pointer payloads

`Result(T)`'s `this(ref return scope inout typeof(this))` has a
`static if (is(T == struct)) { this._value = other._value; }` branch that forces an `inout(T)` ->
`T` conversion. That is illegal when `T` has a mutable indirection: `Result!P` with
`struct P { void* p; }` still fails today with:

```
Error: cannot implicitly convert expression `other._value` of type `inout(P)` to `P`
```

`Result!Event` used to fail the same way; it now copy-constructs,
passes by value and rvalue-assigns because `Event` carries the `CopyConstructors` mixin, whose
cast fallback handles the `inout` case. Nothing in the tree instantiates `Result!Event`.

### Lvalue assignment of every `Result` and `OperationResult` is broken

With all three forms present as direct struct members, `b = a` for lvalues `a`, `b` fails on both
LDC and DMD:

```
Error: overloads `void(ref return scope inout(Result!int) other)` and `(Result!int other)` both match argument list for `opAssign`
```

Copy-construction, pass-by-value and rvalue assignment (`b = Result!int()`) work. The engine
compiles only because no code lvalue-assigns a result. The earlier note's claim that "as direct
struct members the non-template beats the template" was wrong; the two forms are ambiguous for
lvalues wherever they are declared, so the template form does not do what it was added for.

### Why the third form exists

`void opAssign()(typeof(this) other)` is needed purely for **rvalue assignment** (`x = Result!T(...)`)
— a `ref` parameter cannot bind an rvalue. It was made a template to let the non-template `ref`
overload win for lvalues, which does not happen (see above).

The `inout`-vs-`const` question for the first two forms was not investigated.

### How far `CopyConstructors` can go

`retrograde.std.dlang.CopyConstructors` has a cast fallback for members that have mutable
indirections:

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

The mixin's own copy constructor is not `inout`-qualified either, so a struct using the mixin has
the same effect on *its* enclosing structs as `String` has: they need their own copy constructor
too. This is why the boilerplate spreads outward.

The third form **cannot** move into the mixin. Adding `void opAssign()(typeof(this) other)` there
yields the same ambiguity error as above for lvalue assignment. Since the ambiguity exists for
direct members as well, this is not a mixin limitation but the same problem.

The `!__traits(isStaticArray, ...)` guard in both mixin methods dates from the mixin's first commit
(`107cb4ac`, 2024-05-16) with no recorded reason, and it makes the mixin **silently drop static
array members**: the copy keeps whatever the field's default initializer says, with no error at
compile time or run time. Verified 2026-09-14 that the guard is not needed: the mixin with the
`isStaticArray` check removed copies a `float[4]` member correctly on both copy-construction and
assignment.

### Already applied

- `source/retrograde/std/dlang.d` — cast fallback in both `CopyConstructors` methods.
- `source/retrograde/engine/event.d` — `Event` now uses `mixin CopyConstructors!Event;`.
- `source/retrograde/assets/model.d` — `BaseColorFactor` (2026-08-27) and `EmissiveFactor` are
  structs of named floats purely to dodge the static array guard; every copy of a `Material` with a
  `float[4]` member reset it to its initializer, which surfaced only as a failing assert in an RGM
  loader test.
- `source/retrograde/assets/model.d` — `Material` no longer uses the mixin (2026-09-15): all of
  its members are plain values, so the compiler's default copy handles them, `float[4]` included.
  The mixin was the only reason the factor structs existed. They are kept for now because
  `GlMeshInfo` in `api/opengles3.d` also holds them and still needs the mixin for its `HashMap`.

## Tasks

- [x] Reproduce the failure modes in a minimal test.
- [ ] Fix the root cause at the `String` level if possible: give `StringT` a copy constructor the
      compiler can use to construct an `inout` object, so enclosing structs get a generated copy
      for free. If that is not achievable (the copy has to allocate and write `ptr`), record the
      rule instead: any struct holding a `String`, or any struct using `CopyConstructors`, must
      define its own copy constructor. Apply the same conclusion to `Array(T)`, `SharedPtr` and the
      other owning types with hand-rolled `inout` copy constructors.
- [ ] Fix lvalue assignment of `Result(T)` and `OperationResult`. Options: drop the template
      rvalue `opAssign` and take the rvalue by `auto ref`, or keep only a by-value `opAssign` that
      serves both lvalues and rvalues through the copy constructor. Add a test that lvalue-assigns
      each. Do **not** drop the copy constructor: without it `Result` becomes uncopyable in the
      engine (see the trigger).
- [ ] Fix `Result(T)`'s copy constructor for struct payloads with mutable indirections. Replace the
      `static if (is(T == struct))` branch with the mixin's cast fallback, or use the mixin. Add
      `Result!(struct with a void*)` to the tests.
- [ ] Document the root cause in a short note (likely in `docs/betterc-pitfalls.md` or alongside
      `CopyConstructors`), including the `-verrors=spec` error and the first-one-wins caveat, so
      nobody re-derives the wrong conclusion from a single-struct repro again.
- [ ] Decide whether the mixin's shallow-copy cast branch should be opt-in, so an owning pointer
      field cannot be aliased by accident.
- [ ] Drop the `!__traits(isStaticArray, ...)` guard from both mixin methods — a plain
      `this.member = other.member` covers static arrays — then collapse `BaseColorFactor` and
      `EmissiveFactor` back to `float[4]` / `float[3]` (in `Material` and `GlMeshInfo`) and re-run
      the RGM loader tests.
- [ ] Audit the remaining mixin users for ones that, like `Material`, hold only plain values and
      can drop it outright. As of 2026-09-15 the others all hold a `String`, `Array` or `HashMap`
      and genuinely need it until the `String`-level task lands.
