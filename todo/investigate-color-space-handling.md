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
  them, leaving the shader working in linear space throughout? Note that normal and
  metallic-roughness maps — and any future occlusion map — must **stay** linear: they are data,
  not color. Today nothing distinguishes them, since every texture is uploaded the same way.
- Is a gamma or tonemap step wanted at the end of the frame, and where would it live given there
  is no post-process pass today?
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
