---
name: organize-imports
description: Reorganize D imports in Retrograde engine source files. Sorts alphabetically, groups by top-level retrograde subnamespace, places third-party imports before retrograde imports, and drops unused selective imports. Use when the user asks to "organize imports", "sort imports", "clean up imports", or "reorganize imports" in one or more `.d` files.
---

# Organize D Imports (Retrograde)

Reorganize `import` statements in Retrograde `.d` files to match project convention.

## Terminology

- **Block** — a contiguous run of `import` lines in the source, broken by any non-import line (blank line, comment, code, or a `version` brace). Each block is reorganized in place, at its own indentation. A file typically has one block at the top, plus extra blocks inside `version (...) { ... }` braces or inside functions.
- **Group** — a subset of imports *within* a block, separated from other groups by a single blank line. A block is partitioned into one third-party group (if any) followed by one group per top-level `retrograde.<segment>` namespace. Groups never span blocks.

## Scope

- **Default to a single file**: the file currently in context (the file the user is editing, the file they just referenced, or the IDE-opened file). Do not fan out across the codebase on your own.
- Reorganize multiple files **only** when the user explicitly asks for it (e.g. "organize imports in every file under `source/retrograde/std/`", "do all files in this directory", "across the whole engine"). If the request is ambiguous about scope, ask before touching more than one file.
- Targets `.d` files under `source/retrograde/`.
- Apply the same rules to every contiguous import block: top-of-file, inside `version (...) { ... }` braces, after a trailing-colon `version (...) :`, and inside functions. Do not hoist imports out of their enclosing scope.
- Leave alone:
  - `module ...;` declarations.
  - String imports `import("path/to/file.ext")` (asset loads, not symbol imports).
  - `mixin` / `static import` statements (don't reorder).
  - `public import ...;` lines (don't drop — they re-export).
  - Whole-module imports like `import retrograde.wasm.opengles3;` (no symbol list — don't drop).

## Procedure

For the file in context (or each file the user explicitly named for a bulk pass):

1. **Read the whole file.** You need the full body to check symbol usage.

2. **Identify every contiguous import block.** A block is a run of lines where each non-blank line is an `import` or `public import` statement. Blocks are separated by any non-import line. Treat each block independently. A multi-line import (one terminated by `;` that wraps across lines) is a single statement — keep its internal formatting verbatim.

3. **Drop unused selective imports.** For each `import some.module : symA, symB, aliased = original;`:
   - Use the **alias name** when one is given, otherwise the symbol name.
   - Search the rest of the file (every line outside this import block) for a word-boundary occurrence of that name. `rg -w '\bNAME\b' <file>` works well.
   - Drop unused symbols. If every symbol in the line becomes unused, drop the whole line.
   - When in doubt, keep it. A removed-but-used import breaks the build; a kept-but-unused import is harmless.
   - Special case: keep `runFooTests`-style imports in test-runner blocks if the function is called below.

4. **Drop duplicate imports.**
   - **Within the same block:** if two import lines name the same module *and* the second's symbol list is a subset of the first's (or both are whole-module imports), drop the second. If the second adds extra symbols, merge them into the first instead.
   - **Across blocks:** if a nested block (inside `version (...) { ... }` braces, after a trailing-colon `version (...) :`, or inside a function) contains an import whose module + symbols are already provided by a **top-level, unconditional** import in the same file, drop the nested one. A common case: a `version (unittest) { ... }` block re-imports `retrograde.std.string : String` that the top-level block already imports → drop from the version block.
   - **Don't dedup across sibling version blocks** (e.g. an import that appears in both `version (Native) { ... }` and `version (WebAssembly) { ... }` — they're alternative platform branches, not duplicates).
   - **Don't dedup `public import` against a plain `import`** — the `public import` re-exports, which is a different effect.

5. **Group the remaining imports** within the block, in this order:
   1. **Third-party** — any module path not starting with `retrograde.` (e.g. `core.stdc.*`, `core.sys.*`, `ldc.*`). One combined group.
   2. **Retrograde groups** — one group per second path segment (the token after `retrograde.`). Order groups alphabetically by that segment name. Examples seen in the codebase: `api`, `data`, `engine`, `native`, `std`, `wasm`. Anything deeper (e.g. `retrograde.engine.rendering.renderpass.genericmodel`) still belongs to its top-level segment (`engine`).

6. **Sort within each group** alphabetically by full module path. Also sort the symbols inside a single `import ... : a, b, c;` symbol list alphabetically. Use a **case-insensitive** sort so that mixed-case symbols interleave naturally (e.g. `s` before `String`, `EntityId` before `forEachEntity`). For aliased symbols (`aliased = original`), sort by the **alias name** (the name on the left of the `=`), since that's the name visible in the rest of the file.

7. **Emit the block** with exactly one blank line between groups and no blank lines within a group. Preserve the block's original indentation (e.g. imports inside a `version { ... }` brace are typically indented four spaces) on every emitted line. Preserve `public ` prefixes and any aliasing verbatim.

8. **Apply edits with `Edit`** — one Edit per block. Do not rewrite the file with `Write` unless creating it from scratch.

9. **Do not build or run tests.** The user verifies.

## Example

Before:

```d
module retrograde.example;

import retrograde.std.collections : Array, HashMap;
import core.stdc.stdio : printf;
import retrograde.engine.entity : EntityId, hasComponent;
import retrograde.std.memory : malloc, free, calloc;
import retrograde.data.model : Model;
import retrograde.std.math : Matrix4;

void doThing() {
    EntityId e;
    Model* m;
    auto buf = malloc(16);
    free(buf);
    printf("hi\n");
}
```

After (`Array`, `HashMap`, `hasComponent`, `Matrix4`, `calloc` are unused and dropped; `retrograde.std.math` empties out and is dropped entirely; surviving symbol lists are sorted alphabetically — `free` before `malloc`):

```d
module retrograde.example;

import core.stdc.stdio : printf;

import retrograde.data.model : Model;

import retrograde.engine.entity : EntityId;

import retrograde.std.memory : free, malloc;
```

## Version-block example

Apply the same rules at the block's indentation:

```d
version (Native) {
    import core.stdc.stdio : fclose, fopen;

    import retrograde.native.stdio;
    import retrograde.std.string : s, String;
}
```
