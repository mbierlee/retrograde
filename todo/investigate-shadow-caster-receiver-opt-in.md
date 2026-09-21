# Let entities opt in to casting and receiving shadows

**Files:** `source/retrograde/engine/rendering/renderpass.d`,
`source/retrograde/engine/rendering/package.d`, `source/retrograde/engine/rendering/shadow.d`,
`source/retrograde/api/opengles3.d`, `source/retrograde/shaders/opengles3/`

Two different things "cast" shadows, and this note is only about the second:

- A **light** with `Light.castsShadows` set gets a shadow map. That flag decides whether a light
  produces shadows at all, and it is the only shadow control that exists today.
- An **entity** is a *caster* when its geometry is drawn into a light's shadow map, so it blocks
  that light, and a *receiver* when the lit shaders test its surface against the map, so it can
  be darkened. Throughout this note, "caster" and "receiver" always mean entities, never lights.

Shadow mapping (2026-09-20) gave lights the first control and entities neither: every entity
the shadow pass draws is a caster in every map of every shadowed light, and every lit entity is
a receiver. The shadow pass is gathered like every other pass, on `RenderableComponentType` plus
`ModelComponentType`, so "is it drawn" and "is it a caster" are the same question today.

That is not always what a scene wants:

- A glass pane, a flame, a particle effect or a decal is drawn but should block nothing. Its
  depth in the map is a solid wall as far as the comparison is concerned.
- A skybox or a ground plane too big to be a caster costs a full pass over its geometry for
  every map, and shadows nothing that was not already shadowed.
- An entity may want to be a caster without being a receiver, or the other way round - a
  character whose own self-shadowing looks wrong at the resolution in use, say.

The cost of the missing control is not just looks: a caster is re-drawn once per map, so six
times over for a point light, and the largest meshes in a scene are often the ones that least
need to be there.

## Decision

Casting and receiving become **opt-in per entity**, with a **global switch for each** that makes
every eligible entity take part without being given anything.

- Two tag components, carrying no data, in `rendering/shadow.d` beside the rest of the shadow
  state:

  ```d
  /// Given to entities whose models block shadow-casting lights.
  enum ShadowCasterComponentType = sid("comp_shadow_caster");

  /// Given to entities whose surfaces are darkened by the shadows others cast on them.
  enum ShadowReceiverComponentType = sid("comp_shadow_receiver");
  ```

- Two module-level switches in `rendering/package.d`, beside `frustumCullingEnabled` and
  `RenderableComponentType`, which is where a user looks for renderer-wide settings:

  ```d
  /// Every model is a caster, whether or not it has a ShadowCasterComponentType.
  bool allModelsCastShadows = false;

  /// Every lit model is a receiver, whether or not it has a ShadowReceiverComponentType.
  bool allModelsReceiveShadows = false;
  ```

  Both default to `false`: an entity takes part only when it is given the component, so a
  scene pays for exactly the casters it asked for. This is a breaking change - a scene written
  against the current behaviour loses every shadow until it either tags its entities or sets
  the switches to `true`, which restores what ships today in two lines. The shadow pass and
  `Light.castsShadows` are opt-in already, so a scene that turned shadows on was already making
  choices at the same point.

- An entity is a **caster** when it has `ModelComponentType` and either has
  `ShadowCasterComponentType` or `allModelsCastShadows` is set. `RenderableComponentType` is no
  longer required: whether an entity is drawn and whether it blocks light are now separate
  questions, which also lets a scene place an invisible caster (a stand-in for geometry that is
  off screen, or cheaper than what it stands in for).
- An entity is a **receiver** when it is drawn by a lit pass, so it still has
  `RenderableComponentType` and `ModelComponentType`, and either has
  `ShadowReceiverComponentType` or `allModelsReceiveShadows` is set. Receiving only means
  anything for a surface that is drawn, so the renderable requirement stays on this side.
- **Per entity only.** A model with a solid body and a glass window is one entity with two
  meshes and two materials, so a component cannot exempt the window; for now the window is
  split into its own entity. Per-material control - a flag in RGM, so glass is marked where it
  is defined - is the natural next step, and fits on top of this without changing it.
- **Opt-in only.** There is no opt-out component. A scene that sets `allModelsCastShadows` and
  wants one glass pane out of it turns the switch off and tags everything else instead.
- The sandbox and any other scene that shows shadows today set both switches to `true`, or tag
  their entities, as part of the same change.

## What it takes

- **Per-pass entity selection.** The renderable check is not in the shadow pass today; it is in
  the gather loop in `rendering/package.d` that every pass shares, which keeps entities that
  have `RenderableComponentType` and the pass's `componentType`. The shadow pass needs to
  replace that test rather than add to it. An optional `bool delegate(EntityId) acceptsEntity`
  on `RenderPass`, used instead of the default test when set, keeps every other pass as it is
  and lets the shadow pass say "model, and caster or `allModelsCastShadows`". Filtering there
  means a non-caster is dropped once per frame when the pass gathers its entities, not once per
  map, which is what the culling in `drawModelDepth` would otherwise cost.
- **Receiving in the lit shaders.** Receiving is decided per draw, so the lit material shaders
  need a uniform - a `bool` or a `float` that scales the shadow term to nothing - set by
  `drawModel` for each entity. When `allModelsReceiveShadows` is set it can be set once per pass
  instead. The branch sits inside the `#if MAX_SHADOW_VIEWS > 0` blocks, so a build without
  shadows pays nothing; validate every `maxLights` x `maxShadowViews` combination after the
  change, as the shader instructions in `CLAUDE.md` describe.
- **Docs.** The `shadowMapRenderPass` comment in `renderpass.d` says what the pass draws and has
  to name the new rule, and the component and switch declarations need doc comments that point
  at each other.
- **Tests.** Cover the four cases of each rule: switch on or off, component present or absent;
  plus a caster without `RenderableComponentType`, and a receiver without it (which receives
  nothing, because it is not drawn).

## Related

- `investigate-shadow-catcher.md` covers the other side of an invisible caster: a surface that
  is never drawn but shows the shadows cast onto it. It depends on the caster rule decided here.
- `shadow-caster-receiver-per-material.md` is the per-material step that follows this one.
