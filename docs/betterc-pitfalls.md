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
