# Investigate replacing hardcoded vertex attribute locations with shader-queried locations

**File:** [source/retrograde/api/opengles3.d:285-287](source/retrograde/api/opengles3.d#L285-L287)

Currently the renderer pins vertex attribute locations to fixed indices:

```d
private enum PositionAttribLocation = 0;
private enum ColorAttribLocation = 1;
private enum UvAttribLocationBase = 2;
```

Shaders are expected to declare matching `layout(location = N)` qualifiers. This couples the renderer to a single shader convention and breaks if a shader author forgets a location qualifier or uses a different layout.

## Questions to answer

- Can we drop the hardcoded enums and instead query attribute locations via `glGetAttribLocation` once per shader program, caching the results next to `GlRenderPassInfo` (alongside `mvpMatrixUniformLocation`)?
- What is the right cache shape — a small struct of named `GLint` locations per render pass, or a `StringId`-keyed map for extensibility?
- How does this interact with `UvAttribLocationBase` and the per-channel UV buffers (`uvBufferObjects[maxUvChannels]`)? We'd need to query `uv0`, `uv1`, … by name and store an array of locations.
- What should happen when a shader doesn't declare an attribute the renderer wants to bind? `glGetAttribLocation` returns `-1` — treat as "skip this VBO bind" rather than an error?
- Same question applies to uniform locations: `mvpMatrixUniformLocation` is already queried, but is there a wider set of conventional uniforms (lights, textures, time, etc.) we should formalize as a queried bundle per shader?
- Performance: queries happen once at shader load, so cost is negligible — the real question is API ergonomics for shader authors and engine extensibility.

## Why

Hardcoded locations make the renderer brittle to shader edits and prevent third-party shaders from working without matching the engine's convention. Querying decouples the renderer from any specific layout and lets shader authors order their attributes freely.
