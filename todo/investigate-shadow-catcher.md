# Investigate shadow catchers: invisible surfaces that only show shadows

**Files:** `source/retrograde/engine/rendering/renderpass.d`,
`source/retrograde/engine/rendering/shadow.d`, `source/retrograde/api/opengles3.d`,
`source/retrograde/shaders/opengles3/`

A shadow catcher is a surface that is never drawn itself, but has the shadows cast onto it
drawn: an invisible ground plane under a character standing in front of a skybox or a
background image, so the character still looks grounded. Blender and most offline renderers
have one; the engine has no way to express it.

It is not the same as an invisible caster. That one - a model that is a shadow caster (see
`isShadowCaster` in `shadow.d`) but has no `RenderableComponentType` - throws a shadow without
being seen, and the engine already supports it. A catcher is the other side: it receives without being seen.

## Why it fits

- **Blending is already on.** `opengles3.d` enables `GL_BLEND` with `SRC_ALPHA,
  ONE_MINUS_SRC_ALPHA` for every draw, so a catcher only has to write black with an alpha of
  how shadowed each fragment is, and whatever is behind it is darkened by that much.
- **The shadow term already exists.** `shadowFactor()` in the lit material shaders returns 1
  where a light reaches a surface and 0 in full shadow. A catcher weighs it across its lights
  and writes roughly `vec4(0.0, 0.0, 0.0, (1.0 - lit) * strength)`.
- **The rest is the existing pass machinery.** A catcher is a model drawn by a pass of its own,
  selected by a component of its own, the same way the generic and shadow passes select theirs.

## What it would take

- A tag component, `ShadowCatcherComponentType = sid("comp_shadow_catcher")`, and a
  `shadowCatcherRenderPass` that draws models having it.
- Registration after every opaque pass, so there is something already drawn to darken. Depth
  test on, depth write off, so a catcher neither hides nor is hidden by what is drawn after it
  depending only on draw order.
- A fragment shader that shares `shadowFactor()` with the lit materials rather than copying
  it. Today the function lives inside each material shader; it would move into a snippet the
  engine substitutes in, the way it already substitutes `<%maxLights%>` and
  `<%maxShadowViews%>`.
- Validation of the new shader pair across every `maxLights` x `maxShadowViews` combination,
  including `maxShadowViews` 0, where the catcher has nothing to show and should compile to a
  pass that writes nothing visible.

## Questions to answer

- How should several lights combine? The darkest light's shadow, the average, or each light's
  shadow weighted by how much it would have lit the surface? The last matches the lit shaders
  best but needs the catcher to evaluate lighting it then throws away.
- Should the shadow's color and strength be settable - a component with data rather than a
  tag - so a catcher can match the tint of the background it sits over?
- Should a catcher be excluded from casting outright, whatever the switches say? A ground
  plane that casts shadows onto nothing costs a full draw per map, and with
  `allModelsCastShadows` set it would. `NonShadowCasterComponentType` already lets a scene
  exclude it by hand; the question is whether a catcher should imply it.
- Should a catcher take ambient occlusion-like contact darkening too, or only what the maps
  give? Contact shadows are where a grounded look comes from and a shadow map at modest
  resolution loses them.
