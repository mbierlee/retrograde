# TODO: Investigate why explicit copy constructors are required when String members are introduced

## Problem

As soon as a struct gains a member of a non-trivially-copyable type such as
`retrograde.std.string.String` (or any other type with its own copy constructor / postblit /
destructor), the compiler stops auto-generating a usable copy constructor and `opAssign` for the
enclosing struct. Until explicit ones are added, copies/assignments either fail to compile,
silently bitwise-copy and break ownership semantics, or trigger `-betterC` errors.

Concrete example: `OperationResult` and `Result(T)` in `source/retrograde/std/result.d` had to
grow three boilerplate members each once `_errorMessage` was changed from a D `string` to a
`String`:

```d
this(ref return scope inout typeof(this) other) { ... }
void opAssign(ref return scope inout typeof(this) other) { ... }
void opAssign()(typeof(this) other) { ... }
```

The same pattern shows up across the codebase wherever a struct contains a `String`, `Array`,
`UniquePtr`, `SharedPtr`, etc.

## Questions to answer

- Why does DMD/LDC require all three of these forms? Is it `inout` interaction with `const`/
  mutable callers, rvalue vs lvalue handling, or `-betterC` specifically?
- Can the `CopyConstructors` mixin in `retrograde.std.dlang` be extended to cover this case so
  every struct that holds a `String` doesn't need the same three-method boilerplate copy-pasted?
- Are there cases where the auto-generated copy constructor *would* work and we're adding these
  unnecessarily? If so, document the precise trigger.
- Is there a way to express "just memberwise-copy each field, invoking each member's own copy
  constructor" without writing it out by hand?

## Tasks

- [ ] Reproduce the failure modes in a minimal test (struct with a single `String` member, try
      copying / assigning / passing by value, with and without `const` / `inout`).
- [ ] Document the root cause in a short note (likely in `docs/` or alongside `CopyConstructors`).
- [ ] If feasible, extend `CopyConstructors` so structs like `OperationResult`, `Result(T)`, and
      friends can just `mixin CopyConstructors;` instead of hand-rolling three methods.
- [ ] Audit existing hand-rolled copy constructors and replace with the mixin where it applies.
