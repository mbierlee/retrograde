# Investigate letting an entity opt out of casting or receiving shadows

**Files:** `source/retrograde/engine/rendering/renderpass.d`,
`source/retrograde/engine/rendering/package.d`, `source/retrograde/api/opengles3.d`

Shadow mapping (2026-09-20) made casting a property of the light: `Light.castsShadows` picks
which lights cast, and every entity the shadow pass draws casts into every map of every one of
them. The shadow pass filters on `ModelComponentType` and `RenderableComponentType`, exactly as
the generic pass does, so "is it drawn" and "does it cast" are the same question today.

That is the right default and it is not always what a scene wants:

- A glass pane, a flame, a particle effect or a decal is drawn but should block nothing. Its
  depth in the map is a solid wall as far as the comparison is concerned.
- A skybox or a ground plane too big to be a caster costs a full pass over its geometry for
  every map, and shadows nothing that was not already shadowed.
- An entity may want to cast without receiving, or receive without casting - a character whose
  own self-shadowing looks wrong at the resolution in use, say.

The cost of the missing control is not just looks: a caster is re-drawn once per map, so six
times over for a point light, and the largest meshes in a scene are often the ones that least
need to be there.

## Where it could live

- **Its own component type.** `enum ShadowCasterComponentType = sid("comp_shadow_caster")`, with
  the shadow pass filtering on it instead of `ModelComponentType`. Fits how the pass system
  already selects entities, and needs no new code in the draw path. Against it: every existing
  entity would have to be given the component to keep casting, which is a breaking default, or
  the pass filters on "not opted out", which the component system has no way to express.
- **A field beside the model component.** Reuses the entity's existing data, but the draw path
  then has to read and branch on it per entity, and it is not obvious that a model is where a
  rendering decision of this kind belongs.
- **A material property.** The RGM format already carries material flags, so an author could
  mark glass as non-casting where the glass is defined rather than where it is placed. Against
  it: the decision is often about the instance, not the material, and the shadow pass
  deliberately never looks at materials, which is most of why a caster draw is cheap.

## Questions to answer

- Is the wanted control per entity, per mesh, or per material? A model with a solid body and a
  glass window is one entity with two meshes and two materials.
- How should the default read? "Everything drawn casts" is what ships now and is the least
  surprising, so any opt-out has to be expressible as an exception rather than a requirement.
- Is receive-side opt-out worth it? It costs a branch or a uniform in the lit shaders, which
  is the hot path, to save something a scene can usually arrange around.
- Does this want to interact with the culling that `drawModelDepth` already does per view? An
  entity that never casts is better filtered once when the pass gathers its entities than
  tested per map.
