# betterC Pitfalls

Gotchas that come from building with `-betterC` itself, on any target. These
bite native and WASM alike. For problems that only surface in the WASM build,
see [wasm-pitfalls.md](wasm-pitfalls.md).

## GC array literals inside lambdas are silently dropped when a template is involved

### Symptom

The build compiles without a single error, then fails at link time with an
undefined reference to a *lambda*:

```
undefined reference to `_D10retrograde3std11collections13runQueueTestsFZ18__lambda_L4709_C44FNbNiZv'
Error: undefined reference to `nothrow @nogc void retrograde.std.collections.runQueueTests().__lambda_L4709_C44()`
```

The enclosing function is emitted and calls the lambda, but the lambda's body
was never generated. The line number in the mangled name (`_L4709_C44`) points
at the lambda that was dropped.

### Cause

An array literal used where a slice is expected needs the GC, which `-betterC`
forbids. Normally the compiler says so:

```
Error: this array literal requires the GC and cannot be used with `-betterC`
```

But when the literal is an argument to a member of a **template**
instantiation, *and* it sits inside a **lambda**, that error is raised while
the lambda is being analysed speculatively (attribute inference runs the body
with errors gagged). The gagged error kills the body but is never reported, so
compilation "succeeds" and the linker is left holding a declared-but-undefined
function.

```d
// silently dropped: Queue is a template, and this is inside a lambda
test("Compare a Queue with a D array", {
    Queue!(int, 4) queue;
    // ...
    assert(queue == [2, 3, 4, 5]); // <-- literal converted to const(int)[]
});
```

Both ingredients are required — verified with DMD 2.112.0:

| Construct | Result |
| --- | --- |
| Lambda + template struct's `opEquals(const T[])` + literal | **silently no body**, link error |
| Lambda + non-template struct + literal | proper "requires the GC" error |
| Named function + template struct + literal | proper "requires the GC" error |

Note that this only concerns literals that must become *slices*. Comparing two
slices (`array[0 .. 3] == [1, 5, 3]`) is fine: there the literal stays a static
array and no allocation is needed, which is why the older `Array` tests in
`collections.d` get away with it.

### Fix / rule

Give the literal storage of its own and pass a slice of it:

```d
static immutable int[4] sameItems = [2, 3, 4, 5];
assert(queue == sameItems[]);
```

`static immutable` puts the data in rodata, so nothing is allocated. See the
"Compare a Queue with a D array" test in
`source/retrograde/std/collections.d` (fixed 2026-07-31).

Rule of thumb: never hand a bare array literal to a function parameter that
takes a slice in betterC code. Inside a lambda you may not even be told.

### How to diagnose

Take the mangled name from the linker error and find the source position in
it — `__lambda_L<line>_C<column>` is literally the line and column of the
lambda whose body went missing. Then look for an array literal (or anything
else needing the GC) inside that lambda.

To confirm a symbol is undefined rather than merely misnamed, inspect the
object file:

```
nm -C <object>.o | grep -i lambda
```

A `U` in front of the lambda's name means the body was dropped. Lifting the
same code out of the lambda into a named function makes the compiler report
the real error.

## A local array of structs whose default is not all-zero needs `_memset*`

### Symptom

The module compiles, and the link fails on a symbol that is in no source file:

```
undefined reference to `_memset128'
  referenced from `Quaternion[6] cubeFaceOrientations()'
```

The number varies with the element's size in bits — `_memset128` for a 16-byte
element, and so on.

### Cause

Declaring a fixed-size array of a struct initializes every element to that
struct's default. When the default is all zero bits, the compiler emits a plain
`memset`, which is in libc and links fine. When it is not — `QuaternionT` starts
at `realPart = 1`, so its 16 bytes are `00 00 80 3F 00 ...` — there is no single
byte to fill with, so the compiler emits a call to druntime's block-fill helper
for that element width instead. `-betterC` has no druntime, so nothing defines it.

It is easy to miss which types are affected. An array of `Vector3` is fine: its
components default to 0, so the fill is a `memset`. An array of `Quaternion`,
of any struct with a non-zero default field, or of a struct holding one, is not.

### Fix / rule

Do not declare a local or return a fixed-size array of such a struct. Hand back
one element at a time instead:

```d
// Fails to link.
private Quaternion[6] cubeFaceOrientations() {
    Quaternion[6] orientations;
    orientations[0] = Quaternion.createRotation(...);
    ...
    return orientations;
}

// Links.
private Quaternion cubeFaceOrientation(const size_t face) {
    if (face == 0) {
        return Quaternion.createRotation(...);
    }
    ...
}
```

Where the values are compile-time constants, `static immutable T[N]` also works:
it lands in rodata with no fill at all. That is not an option when the elements
come from `cos`/`sin`, which do not run at compile time on every target.

Passing the array by `ref` for the callee to fill is fine too — the caller's
declaration is what needs a default, and one at the caller's own scope is under
the same rule.

### How to diagnose

The linker error names the function, which is the whole of it: look in that
function for a fixed-size array of a struct, then check whether that struct's
fields all default to 0. If any does not, that array is the one.
