# Authoring Retrograde materials in Blender

This guide explains how to set up materials in **Blender 5.1** so that
`rgmodelconv` classifies them into the right Retrograde [material type](rgm-fileformat.md)
when you export to glTF and convert to `.rgm`.

**`rgmodelconv` reads glTF 2.0 only** — specifically a `.gltf` text file with an
external `.bin` buffer and external image files. Binary `.glb` containers are not
supported, so in Blender's glTF exporter pick the **glTF Separate (.gltf + .bin +
textures)** format. Material classification is driven by glTF concepts such as
the `pbrMetallicRoughness` base color texture and the `doubleSided` flag.

Retrograde does not read a custom "material type" property. Instead,
`rgmodelconv` infers the type from what the material references:

| Retrograde type         | How it's recognized                                            |
| ----------------------- | -------------------------------------------------------------- |
| no material / `invalid` | No material is assigned to the mesh.                           |
| `vertexColors`          | The mesh has a color attribute + the material has no textures. |
| `unlit`                 | The material references a base color (albedo) image texture **and** declares `KHR_materials_unlit`. |
| `pbrMetallicRoughness`  | The material references a base color (albedo) image texture and is a regular lit one. |

**Only the base color texture is converted, for either type.** A regular
`Principled BSDF` material exports as glTF PBR (metallic-roughness) and becomes a
`pbrMetallicRoughness` material in the `.rgm`, but the converter currently keeps
only its **Base Color** texture and drops every other PBR *texture* input
(metallic-roughness, normal, occlusion, emissive) — the RGM format has nowhere to
put them yet. The two types therefore carry exactly the same material data today;
what differs is the shading model the engine picks for them.

Per-vertex **geometry** is the exception: normals and tangents are carried over
into the `.rgm` whenever the export supplies them, independently of the material
type. See [Exporting normals and tangents](#exporting-normals-and-tangents).

To make the material *be* unlit — in Blender's own viewport, in other glTF
viewers, and in the `.rgm` — wire your color source **directly into the
`Surface` socket of the `Material Output` node**, bypassing the
`Principled BSDF`. A surface fed by a raw color (rather than a lighting shader)
is exported with the `KHR_materials_unlit` extension, which is what the converter
keys on.

---

## No material / `invalid`

**Do not assign a material in Blender at all.**

Select the object, open the **Material Properties** tab, and make sure the
material slot list is empty (remove any slots with the `−` button). On export
the mesh carries no material, and the converter emits it as material-less
(`noMaterial`); meshes that reference an unrecognized material fall back to the
`invalid` sentinel. Either way the engine renders the mesh with the render
pass's default shader.

See `asset-examples/cube-nomat.blend` for a working example.

---

## `vertexColors`

Use this when the look of the mesh comes entirely from colors painted onto the
vertices, with no texture.

1. Add a material to the object.
2. In the **Shader Editor**, delete the `Principled BSDF`. (Feeding the Color
   Attribute into a `Principled BSDF` **Base Color** works too — the converter
   classifies lit materials the same way — but then the Blender viewport shades
   the mesh, so what you see there won't match the engine.)
3. Add an **Input ▸ Color Attribute** node. (Formerly "Vertex Color".)
   - In **Object Data Properties ▸ Color Attributes**, add a color attribute
     and select it in the node so it reads the layer you painted.
4. Connect the Color Attribute node's **`Color`** output directly to the
   **`Surface`** input of the **`Material Output`** node.
5. Paint the vertices: switch to **Vertex Paint** mode and paint the mesh as
   desired. The colors are stored on the color attribute you created.

```
[Color Attribute] --Color--> [Material Output] Surface
```

The converter only emits `vertexColors` when the mesh actually has a color
attribute **and** the material references no textures at all — so don't add an
image texture (of any kind, including a normal or roughness map) if you want
this type.

See `asset-examples/cube-vertexcolors.blend` for a working example.

---

## `unlit`

Use this for a mesh shaded by a single image texture, drawn at full brightness
with no lighting applied.

1. Add a material to the object.
2. In the **Shader Editor**, delete the `Principled BSDF`.
3. Add a **Texture ▸ Image Texture** node and load (or point it at) your image.
4. Connect the Image Texture node's **`Color`** output directly to the
   **`Surface`** input of the **`Material Output`** node.
5. Make sure the mesh is UV-unwrapped so the texture has coordinates to sample.

```
[Image Texture] --Color--> [Material Output] Surface
```

The exported texture's name becomes the `unlit` material's texture-name
reference in the `.rgm`; how that name resolves to an actual texture asset is up
to the engine/runtime.

Alternatively, keep the `Principled BSDF` and plug the Image Texture into its
**Base Color** socket:

```
[Image Texture] --Color--> [Principled BSDF] Base Color --BSDF--> [Material Output] Surface
```

This exports as a lit PBR material, so the converter writes a
`pbrMetallicRoughness` material instead — carrying the same base color texture.
The rest of the Principled inputs (Metallic, Roughness, Normal, Emission, ...)
are **not** converted — they are dropped, including any image textures plugged
into them. See `pbrMetallicRoughness` below.

> At the moment `unlit` only works when exporting as a **`.gltf`** file, because
> embedded images (as produced by `.glb`) are not supported yet.

See `asset-examples/cube-unlit-textured.blend` for a working example.

---

## `pbrMetallicRoughness`

Use this for a mesh that should be lit. Set the material up the way you normally
would in Blender:

1. Add a material to the object.
2. Keep the `Principled BSDF` and plug an **Image Texture** into its
   **Base Color** socket.
3. Make sure the mesh is UV-unwrapped so the texture has coordinates to sample.

```
[Image Texture] --Color--> [Principled BSDF] Base Color --BSDF--> [Material Output] Surface
```

Anything not declaring `KHR_materials_unlit` and referencing a base color texture
lands here, so this is what a normal Blender material converts to.

> The remaining PBR inputs (metallic, roughness, normal, occlusion, emissive) are
> dropped by the converter for now, and the engine's shader for this type still
> samples only the albedo texture. Expect a material set up this way to render
> like an `unlit` one until those inputs are stored and shaded.

The same `.gltf`-only restriction on external images applies as for `unlit`.

### Texture filtering (min/mag filter)

Blender 5.1 does not expose the glTF `magFilter` / `minFilter` sampler fields
directly. The exporter derives **both** from the **Interpolation** dropdown on
the **Image Texture** node (visible on the node itself in the Shader Editor, or
under **Sidebar ▸ Item ▸ Node** when the node is selected):

| Node Interpolation              | glTF magFilter | glTF minFilter           | `.rgm` filters (mag / min)             |
| ------------------------------- | -------------- | ------------------------ | -------------------------------------- |
| **Closest**                     | `NEAREST`      | `NEAREST_MIPMAP_NEAREST` | Nearest / Nearest Mipmap Nearest       |
| **Linear** (also Cubic / Smart) | `LINEAR`       | `LINEAR_MIPMAP_LINEAR`   | Linear / Linear Mipmap Linear          |

Pick **Closest** for crisp, blocky pixel-art textures, or **Linear** (Blender's
default) for smooth bilinear/trilinear filtering. Because both filters are driven
by the single Interpolation setting, you cannot mix them from Blender alone
(e.g. nearest magnification with a linear-mipmapped minification) — that requires
editing the glTF sampler by hand. See the [RGM format spec](rgm-fileformat.md)
for the full list of filter values `rgmodelconv` can store.

### Texture wrapping (wrap / extension mode)

Wrap modes decide how the texture is addressed when a UV coordinate falls outside
the `[0, 1]` range. As with filtering, Blender 5.1 does not expose the glTF
`wrapS` / `wrapT` sampler fields directly — the exporter derives **both** axes
from the **Extension** dropdown on the **Image Texture** node (same place as
Interpolation: on the node itself, or under **Sidebar ▸ Item ▸ Node** when the
node is selected):

| Node Extension       | glTF `wrapS` / `wrapT` | `.rgm` wrap mode  |
| -------------------- | ---------------------- | ----------------- |
| **Repeat** (default) | `REPEAT`               | Repeat            |
| **Extend**           | `CLAMP_TO_EDGE`        | Clamp To Edge     |
| **Mirror**           | `MIRRORED_REPEAT`      | Mirrored Repeat   |
| **Clip**             | `CLAMP_TO_EDGE`        | Clamp To Edge     |

Pick **Repeat** to tile the texture across a surface, **Extend** to clamp the
edge texels outward (avoids seams on a texture that shouldn't tile), or
**Mirror** to tile with every other copy flipped. Because both axes are driven by
the single Extension setting, you cannot give S and T different wrap modes from
Blender alone — that requires editing the glTF sampler by hand.

> Blender's **Clip** extension (which renders coordinates outside `[0, 1]` as
> transparent in the viewport) has no glTF equivalent — glTF lacks a border/clip
> mode — so the exporter falls back to `CLAMP_TO_EDGE`, making it behave exactly
> like **Extend** in the engine. Prefer **Extend** for clarity, and don't rely on
> Clip's transparent-border look surviving the export.

See the [RGM format spec](rgm-fileformat.md) for the full list of wrap-mode
values `rgmodelconv` can store.

---

## Exporting normals and tangents

`rgmodelconv` **does not compute normals or tangents** — it only passes through
what the glTF contains. Whether your model arrives with a usable surface basis is
therefore decided entirely by the export settings, and getting it wrong fails
silently: the `.rgm` is written without complaint, just missing the data.

Both options live in the glTF exporter's **Data ▸ Mesh** panel.

### Normals

**Data ▸ Mesh ▸ Normals** is **on by default**. Leave it on.

Blender bakes the result of *Shade Smooth* / *Shade Flat*, the Auto Smooth
modifier, and any custom split normals into what it writes out. Smoothing is
therefore decided in Blender, not at convert time — if the shading looks faceted
where you wanted it round, fix it on the mesh and re-export.

### Tangents

> **Data ▸ Mesh ▸ Tangents is off by default.** You must tick it explicitly.
> This is the single most common reason a model ends up without tangents.

Two things must be true for the option to produce anything:

- **The mesh needs a UV map.** A tangent is the direction the U axis runs across
  the surface, so Blender cannot derive one without an unwrap. `rgmodelconv`
  drops the tangents of any mesh that has no UV channel.
- **Normals must be exported too.** Per the glTF specification, tangents are
  ignored on a mesh without normals, and the converter drops them in that case as
  well.

Tangents are only needed for meshes that will be shaded with a **normal map** —
they are what lets a tangent-space normal map be interpreted correctly, and they
carry the handedness sign that keeps mirrored UV islands from lighting inside
out. Exporting them otherwise does no harm beyond file size (16 bytes per vertex,
per mesh).

To confirm what actually made it into a converted file, run `rgassetinfo` on it;
each mesh is listed as `no normals`, `normals`, or `normals + tangents`.

> **The engine does not consume normals or tangents yet.** They are stored in the
> `.rgm` so the lighting and normal-mapping work can pick them up; nothing shades
> with them today. Exporting them now means models will not have to be re-exported
> later.

---

## Backface culling

Backface culling is a **per-material** setting in Retrograde, controlled by
Blender's material backface-culling option.

In **Material Properties ▸ Settings**, enable **Backface Culling ▸ Camera**.
This marks the material as single-sided on export, and the engine will cull
back faces for any mesh using that material. Leave it **off** to keep the
material double-sided (both front and back faces rendered, the default).

> The other backface-culling checkboxes (Shadow, Light Probe Volume) do not
> affect the export — only **Camera** maps to Retrograde's per-material
> double-sided flag.

To cull back faces everywhere without touching the source model, convert with
`rgmodelconv --force-backface-culling`. Every material is then written as
single-sided, whatever the glTF's `doubleSided` flag says.
