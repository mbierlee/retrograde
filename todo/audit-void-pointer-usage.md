# TODO: Audit remaining `void*` usage across the codebase

## Status

The risky type-erasure sites have been resolved:

- `UniquePtr!void`, `SharedPtr!void`, `ResultPtr!void` — now rejected
  at compile time via `static assert` in `source/retrograde/std/memory.d`.
- `Component.data` (`source/retrograde/engine/entity.d`) — erasure
  kept, but `addComponent` is now templated and stores a per-`T`
  destructor function pointer alongside the data. Destructor firing on
  `removeEntity` / `removeComponent` / replace is covered by tests.
- `RenderPass.apiData` (`source/retrograde/engine/rendering.d`) —
  removed. The OpenGL backend now owns a
  `HashMap!(StringId, GlRenderPassInfo)` keyed by `passName.sid`.

What remains is the formal audit of the remaining `void*` sites, which
on a spot-check fall into two shapes:

- **Allocator / C ABI surface** — `extern (C)` signatures shaped like
  libc (`malloc`, `memcpy`, etc.) and the WASM allocator's internal
  block bookkeeping. Expected to stay `void*`; the audit just confirms
  the boundary.
- **Libc-interop casts inside typed code** — short-lived
  `cast(void*)` around `memcpy` / `free` / `strcmp` calls in otherwise
  typed APIs (notably `std/string.d`). Expected to stay too, but
  worth checking whether a small typed helper would reduce the noise.

These look standard but have not been classified and signed off in
writing.

## Remaining tasks

- [ ] Run a fresh `grep` for `void*` / `cast(void*)` across `source/`
      and produce a table classifying each hit as allocator/C-ABI or
      libc-interop. The previously-identified clusters are
      `source/retrograde/wasm/memory.d` (allocator internals) and
      `source/retrograde/std/string.d` (`memcpy` / `free` / `strcmp`
      casts) — confirm there is nothing else.
- [ ] Spot-check each allocator/C-ABI site to confirm it is genuinely
      an `extern (C)` / allocator surface and that no internal D code
      is leaking `void*` through it unnecessarily.
- [ ] For dense libc-interop patterns (e.g. the repeated
      `copyFrom(cast(void*) other.ptr, ...)` calls in
      `std/string.d`), decide whether a small typed helper would
      reduce the `cast(void*)` noise without hiding meaningful API.
- [ ] Close this todo with the classification table inline, or spawn
      concrete follow-up todos for any libc-interop cleanup that's
      worth doing.
