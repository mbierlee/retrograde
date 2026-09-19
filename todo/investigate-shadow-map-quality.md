# Investigate sharpening and steadying shadow maps

**Files:** `source/retrograde/engine/rendering/shadow.d`,
`source/retrograde/shaders/opengles3/material_lambert_fragment.glsl`,
`source/retrograde/shaders/opengles3/material_pbr_metallic_roughness_fragment.glsl`

Shadow mapping (2026-09-20) shipped with three known gaps in how the maps look. All three were
left deliberately: each is a real technique with its own decisions, and none of them stops
shadows working. Nothing below is known to be visible in a real scene yet — the sandbox is
small enough that the first one in particular may not show at all.

## One ortho box over the whole shadow distance is coarse far away

A directional light gets a single map fitted to the camera's frustum out to
`ShadowSettings.distance`, so its texels are spread evenly over that whole volume. Near the
camera, where a shadow is looked at closely, they are much bigger than a pixel; far away they
are wasted. Raising `mapSize` buys sharpness everywhere at a cost that grows with the square.

Cascaded shadow maps are the usual answer: split the view distance into a few slabs and give
each its own map, so the near slab's texels cover far less world. The structure for it is
already there — `prepareShadowViews` gives a light as many views as it asks for, and a point
light already takes six — so a cascaded directional light is "one light, K views" plus a pick
in the shader, much like the cube face pick.

What it needs decided: how the splits are chosen (uniform, logarithmic, or the usual blend of
both), how many, whether the count is another compile-time budget or a runtime setting, and
whether a fragment picks its cascade by depth or by trying each in turn. Also whether the
bands where cascades meet need blending, which costs a second lookup on those fragments.

## The directional fit crawls as the camera moves

`directionalShadowView` refits the box every frame from the camera's current corners, so the
map's texel grid slides continuously as the camera moves or turns. A shadow edge that should
be still visibly crawls, because which texel a given surface point lands in keeps changing.

The standard fix is to quantize the light-space box origin to whole texels, so the grid moves
in texel steps instead of continuously, together with sizing the box by the frustum's diagonal
so that turning the camera does not change its extent either. The latter costs resolution -
the box has to be big enough for the worst orientation - which is the trade to weigh.

## Point light cube faces seam at their edges

The six faces of a point light are separate layers, each clamped at its edges. A lookup near a
face boundary filters against the edge of its own layer rather than across into the neighbour,
so the join can show as a faint line.

The cheap remedy is to render each face slightly wider than 90 degrees and inset the lookup, so
the filter never reaches the actual edge. A cube map with seamless filtering would avoid it
outright, but it cannot be a layer of the same 2D array, which is what lets one sampler serve
every light.

## Questions to answer

- Which of the three shows up first in a scene bigger than the sandbox? That should decide the
  order, and possibly whether the last one is worth doing at all.
- Does cascading change `RenderView`, or is "K views for one light" genuinely enough? The
  shader needs to know the split distances, which is a new uniform either way.
- Is there a measurement to justify any of this? As with the rest of the renderer, the concern
  here is shape rather than an observed cost.
