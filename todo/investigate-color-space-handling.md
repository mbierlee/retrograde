# Investigate color space handling across the rendering pipeline

**Files:** `source/retrograde/api/opengles3.d`, `source/retrograde/shaders/opengles3/*.glsl`,
`source/retrograde/engine/rendering/package.d`

The engine performs no sRGB/linear conversion anywhere. Textures are uploaded with `GL_RGB` /
`GL_RGBA` internal formats, colors are multiplied raw in the fragment shaders, and nothing
converts on the way out to the framebuffer.

This became visible while adding the base color factor to RGM materials (`docs/rgm-fileformat.md`,
"Base Color Factor"). glTF defines `baseColorFactor` as **linear**, while `baseColorTexture` is
**sRGB-encoded**. The shader multiplies them directly:

```glsl
vec4 albedo = texture(albedoTexture, vertexTextureCoords) * baseColorFactor;
```

Strictly speaking that multiplies a linear value by a non-linear one. It was written that way
deliberately — being consistently naive is better than being half-corrected — but it is worth
settling properly.

## Questions to answer

- Should albedo textures be uploaded as `GL_SRGB8` / `GL_SRGB8_ALPHA8` so the sampler linearizes
  them, leaving the shader working in linear space throughout? The **emissive** map would go with
  them: it is radiance the eye sees directly, and glTF specifies it as sRGB-encoded exactly like
  the base color. The normal, metallic-roughness and occlusion maps must **stay** linear: they are
  data, not color. Today nothing distinguishes any of them, since every texture is uploaded the
  same way. The occlusion map makes this concrete rather than hypothetical: it commonly shares one
  image with the metallic-roughness map, so whatever decides a texture's internal format cannot
  key off the material slot alone — the same texture object is bound to two of them. With the
  emissive map added, the split is no longer "albedo versus the rest" but a genuine per-slot
  property that two slots can disagree about for one shared upload.
- Is a gamma or tonemap step wanted at the end of the frame, and where would it live given there
  is no post-process pass today? Emission makes this pressing rather than academic: the emissive
  strength exists precisely to carry a factor past `1.0`, so a `pbrMetallicRoughness` material
  with an emitter already hands the framebuffer values it can only clip to white.
- Does the emissive factor belong with the linear inputs? glTF defines it as linear, like the base
  color factor, and it is added straight to the shaded color — so whatever the answer is for one,
  it has to be the same for the other. The factor now multiplies the emissive map as well, which
  puts it in the same factor-times-sRGB-texture bind as the base color factor above.
- Do the other color inputs need the same treatment: `Color` (`engine/rendering/package.d`), the
  clear color, `Light.color`, and the hemispherical ambient sky/ground colors? They are authored
  as if they were sRGB but consumed as if they were linear.
- Does anything need to change in `rgimageconv` / the RGI format, or is the internal format
  chosen at upload time enough?
- What do the authoring docs (`docs/blender-material-guide.md`) need to say once the answer is
  known — Blender authors in linear and exports sRGB textures, so the round trip should be
  described.

Nothing here is urgent: with everything uniformly untreated, output is self-consistent and only
subtly darker/lighter than a color-managed renderer would produce.
