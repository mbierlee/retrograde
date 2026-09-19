# Investigate batching entities per render pass instead of re-walking all entities

**File:** `source/retrograde/engine/rendering/package.d` (`renderFrame`)

Rendering walks the entire entity collection once per render pass, and filters inside the loop:

```d
foreach (ref renderPass; renderPasses) {
    useRenderPassShaderProgram(renderPass);

    //TODO: Optimize? Don't attempt each entity in each pass, but batch them.
    passEntities.truncate(0);
    forEachEntity((EntityId entity) {
        if (entity.hasComponent(RenderableComponentType) &&
        entity.hasComponent(renderPass.componentType)) {
            passEntities.add(entity);
        }
    });

    // ... the pass then draws passEntities once per view ...
}
```

So the cost per frame is `passes × entities`, and every entity pays two `hasComponent` lookups in
every pass — including entities that are not renderable at all and can never match any pass. Only a
subset of entities is renderable, and each renderable one is generally drawn by exactly one pass, so
nearly all of that work is rejection.

The entity order the frame draws in is also whatever order the entity collection happens to be in,
which is incidental rather than chosen.

## What shadow mapping changed, and what it did not

Shadow mapping (2026-09-20) made a pass draw its entities from several points of view — one per
shadow map, and a point light needs six. The walk above now collects the pass's entities into
`passEntities` once and the pass iterates its views over that list, so views do not multiply it.

That is the whole of what was fixed. It is not this todo:

- The cost is still `passes × entities` per frame, and the shadow pass is a second registered pass
  by default, so a game with shadows now pays that walk twice rather than once. The concern this
  todo is about got closer, not further away.
- Nothing maintains the list incrementally through the entity hooks; it is still rediscovered from
  scratch every frame.
- Nothing groups draws by shared GPU state, and nothing is sorted.

`passEntities` is, however, the natural place for all three: it is already a per-pass list of
exactly the entities that pass draws, built once a frame. An incremental list would replace how it
is filled, and sorting would be a step after it is filled.

## Questions to answer

- Should the set of entities per pass be maintained incrementally (built as entities are added and
  finalized, via the existing entity hooks) rather than rediscovered each frame? What invalidates
  such a list — components can presumably be added or removed after an entity is created.
- Where would such a list live: on the `RenderPass`, next to the entity storage, or in a separate
  render-side structure? `RenderPass` is currently a plain description (shaders, component type,
  draw delegate) with no per-frame state.
- Does an entity ever match more than one render pass, and is that intended? The current loop
  happily draws it once per matching pass.
- Is "batching" here only about skipping non-matching entities, or also about grouping draws that
  share GPU state (same model, same material/shader) to cut redundant binds? Those are two
  different optimizations that the one TODO conflates.
- How does this interact with the frustum culling that already happens further down in the draw
  path, and with any future sorting requirement (front-to-back for opaque, back-to-front for
  transparency)? A per-pass entity list is the natural place to sort, so the answer shapes the
  data structure.
- Is there a measurement to justify this at all? Nothing here is known to be a bottleneck yet — the
  concern is the `passes × entities` shape, not an observed frame cost.
