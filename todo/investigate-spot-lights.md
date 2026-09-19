# Investigate adding spot lights as a third light type

**Files:** `source/retrograde/engine/rendering/package.d`,
`source/retrograde/engine/rendering/lighting.d`, `source/retrograde/api/opengles3.d`,
`source/retrograde/shaders/opengles3/material_lambert_fragment.glsl`,
`source/retrograde/shaders/opengles3/material_pbr_metallic_roughness_fragment.glsl`

`LightType` has `point` and `directional`. A spot light - a point light restricted to a cone -
is the obvious third, and the shadow work of 2026-09-20 was shaped to leave room for it: a
shadow-casting light is described as a first map layer plus a count of layers, and a spot light
is one perspective view, exactly like one face of a point light's six. `shadowViewCountOf`
would return 1 for it and `prepareShadowViews` would need one more branch.

Shadows are in fact the cheap part. What it needs beyond them:

- `LightType.spot`, and a decision about whether it counts as a point light anywhere that
  currently branches on the two.
- Cone angle on `Light`, almost certainly two of them: an inner angle that is fully lit and an
  outer one where it falls to nothing, since a hard-edged cone looks wrong. glTF stores exactly
  that pair, so following it keeps `rgmodelconv` honest if lights are ever imported.
- A term in both lit shaders: the point light's distance attenuation multiplied by the cone
  falloff, which is a smoothstep between the cosines of the two angles.
- A place in `shadeableLightTypes` in `source/retrograde/api/opengles3.d`, which is what says
  which types the shaders have uniforms and a term for. A type not listed there is culled from
  every selection, which is the current behaviour for anything new and is the safe default.
- `addSpotLight` in `source/retrograde/engine/entityfactory.d`, beside `addPointLight` and
  `addDirectionalLight`. It is aimed by its entity's orientation like a directional light and
  placed by its position like a point light, so it is the first type that reads both.
- `collectActiveLights` filling both `position` and `direction`, which today are filled one or
  the other depending on type.

## The uniform packing question

The lit shaders pack their light data into three `vec4` arrays, plus a fourth for shadows:
`lightPositionRadius`, `lightColorIntensity`, `lightDirection` (`w` flags directional), and
`lightShadowParams` (`x` = first map, `y` = map count, `z`/`w` unused).

A spot light needs two cone cosines beyond what a point light carries. The options:

- Put them in the two unused components of `lightShadowParams`, which costs no new uniform and
  no new upload, but ties a light's cone to a field named for shadows.
- Replace `lightDirection.w`'s flag with a small type enum and add a fifth array for the cone.
  Cleaner to read, one more `glUniform4fv` per draw.
- Widen the flag: `w` could carry 0 for point, 1 for directional, 2 for spot, which the
  existing `> 0.5` test would have to become a comparison of ranges.

## Questions to answer

- Which packing? The answer should probably be whichever leaves the shading loop easiest to
  read, since the upload cost is the same order either way.
- Should a spot light's shadow map use its cone angle as the projection's field of view? It is
  the obvious choice and wastes no texels, but a very narrow cone then gets a very narrow
  frustum with the precision problems that brings.
- Does anything else in the engine assume `LightType` has exactly two values? The culling in
  `selectLights` treats "directional" specially and everything else as positional, which a spot
  light fits, but that should be checked rather than assumed.
