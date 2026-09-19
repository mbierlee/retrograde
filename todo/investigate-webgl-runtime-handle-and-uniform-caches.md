# TODO: Fix the WebGL runtime's handle table and uniform location cache

**File:** `webruntime/retrograde-runtime.js`

Two defects found while adding shadow mapping (2026-09-20). Neither is caused by it and neither
is known to have broken anything yet; both are the kind that stay harmless until something
starts doing at runtime what has so far only happened at startup.

## Handles are never recycled

GL objects are handed to D as 1-based indices into JS arrays — `textures`, `buffers`,
`vertextArrayObjects`, `shaderPrograms` and now `framebuffers` — and looked up through
`getGlObject`. The delete wrappers delete the GL object but leave the array slot occupied:

```js
glDeleteTexture: (texture) => {
  const textureObject = this.getTextureObject(texture);
  this.glContext.deleteTexture(textureObject);
},
```

So the arrays only ever grow, and a deleted handle still resolves to a stale, deleted GL object
rather than failing. For a game that loads its models once this is invisible. It stopped being
purely theoretical with shadow maps: changing `ShadowSettings.mapSize` deletes the array texture
and creates a new one, so a game that puts that on a settings slider leaks a slot per step.

The fix is to null the slot on delete and reuse nulled slots on create, which also makes
`getGlObject` able to tell "never existed" from "deleted".

## The uniform location cache is never written

`glGetUniformLocation` builds a cache key and checks the cache, but nothing ever populates it:

```js
const dictKey = `${program}|${name}`;
if (this.uniformLocationDict.hasOwnProperty(dictKey)) {
  return this.uniformLocationDict[dictKey];
}

const programObject = this.getProgramObject(program);
const location = this.glContext.getUniformLocation(programObject, name);
this.uniformLocations.push(location);
return this.uniformLocations.length;
```

So the cache never hits, and every call pushes another entry onto `uniformLocations`. It is
harmless today only because every lookup happens once at init; any per-frame lookup would grow
that array without bound. The engine is written not to do that, which is a constraint nothing
states.

## The location that is never absent

The same function never returns -1. `getUniformLocation` returns `null` for a name the program
does not have, and that `null` is pushed and its index returned like any other, so D receives a
valid-looking handle. Every `location >= 0` check in `drawModel` and `initMaterialShader` is
therefore vacuous, and setting a uniform the shader does not have is a silent no-op inside
`uniform*` rather than something the D side skips.

That is mostly benign — a shader whose compiler stripped an unused uniform should not be an
error — but it means a misspelled uniform name fails silently and looks exactly like a shader
that optimized the uniform away.

## Tasks

- Null deleted slots and reuse them on create, for all five handle tables.
- Populate `uniformLocationDict`, or delete it and the check that reads it.
- Decide whether D should be able to tell that a uniform is absent. Returning -1 for a `null`
  location would make the existing checks mean what they look like they mean; the cost is that
  a stripped uniform and a typo stay indistinguishable unless something also warns.
- Check whether any of this wants a test. `wasmtest` builds with `NoGraphicsApi` and never
  touches these wrappers, so there is nowhere obvious for one to live today.
