# Authoring Retrograde materials in Blender

This guide explains how to set up materials in **Blender 5.1** so that
`rgmodelconv` classifies them into the right Retrograde [material type](rgm-fileformat.md)
when you export to glTF and convert to `.rgm`.

**`rgmodelconv` reads glTF 2.0 only** — specifically a `.gltf` text file with an
external `.bin` buffer and external image files. Binary `.glb` containers are not
supported, so in Blender's glTF exporter pick the **glTF Separate (.gltf + .bin +
textures)** format. Material classification is driven by glTF concepts such as
the `pbrMetallicRoughness` base color texture and the `doubleSided` flag.

By default `rgmodelconv` infers the type from what the material references. You can
also name the type outright with an `rg_mat` custom property, which is the only way to
reach a type that no glTF material maps onto — see
[Overriding the inferred type](#overriding-the-inferred-type-with-rg_mat).

| Retrograde type         | How it's recognized                                            |
| ----------------------- | -------------------------------------------------------------- |
| no material / `invalid` | No material is assigned to the mesh.                           |
| `vertexColors`          | The mesh has a color attribute + the material has no textures. |
| `unlit`                 | The material references a base color (albedo) image texture **and** declares `KHR_materials_unlit`. |
| `lambert`               | Never inferred. Requires `rg_mat` on a material that references a base color texture. |
| `pbrMetallicRoughness`  | The material references a base color (albedo) image texture and is a regular lit one. |

**The base color and normal textures are converted; the other PBR texture inputs are
not.** A regular `Principled BSDF` material exports as glTF PBR (metallic-roughness) and
becomes a `pbrMetallicRoughness` material in the `.rgm`, keeping its **Base Color** and
**Normal** textures (with the normal map's strength) and dropping the rest
(metallic-roughness, occlusion, emissive) —
the RGM format has nowhere to put those yet. The lit types (`lambert`,
`pbrMetallicRoughness`) carry the normal map; `unlit` keeps only its base color texture,
since an unlit material is never shaded.

A **base color texture is still what makes a material textured**: a material carrying
only a normal map and no base color is not recognized as a textured type and falls back
to the `invalid` sentinel.

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

## Overriding the inferred type with `rg_mat`

A material can state which Retrograde type it wants instead of letting the converter
work it out, by carrying a **custom property named `rg_mat`** whose string value is the
type name.

In Blender:

1. Select the object and open the **Material Properties** tab.
2. Scroll to the bottom to the **Custom Properties** panel and click **New**.
3. Click the gear/edit icon on the new property, set **Type** to `String`, set the
   **Property Name** to `rg_mat`, and set the value to the type you want — for example
   `lambert`.
4. **In the glTF exporter, tick `Include ▸ Data ▸ Custom Properties`.** Without it
   Blender writes no `extras` at all and the override silently does nothing.

The property lands in the glTF material's `extras`, which is where the converter looks:

```json
"materials": [
  {
    "name": "Material",
    "extras": { "rg_mat": "lambert" },
    "pbrMetallicRoughness": { "baseColorTexture": { "index": 0 } }
  }
]
```

Accepted values are the material type names, matched case-insensitively: `invalid`,
`vertexColors`, `unlit`, `lambert`, `pbrMetallicRoughness`.

**The override picks a type; it does not invent data.** A material still has to supply
what its chosen type needs — a base color texture for `unlit`, `lambert` and
`pbrMetallicRoughness`, a color attribute for `vertexColors`. Ask for a type the
material cannot back, or misspell the name, and `rgmodelconv` prints a warning and
keeps the type it inferred, rather than writing out a material the engine cannot read.

See `asset-examples/cube-lambert.blend` for a working example.

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
`pbrMetallicRoughness` material instead — carrying the same base color texture,
plus a **Normal** map if you plug one in. The rest of the Principled inputs
(Metallic, Roughness, Emission, ...) are **not** converted — they are dropped,
including any image textures plugged into them. See `pbrMetallicRoughness` below.

> At the moment `unlit` only works when exporting as a **`.gltf`** file, because
> embedded images (as produced by `.glb`) are not supported yet.

See `asset-examples/cube-unlit-textured.blend` for a working example.

---

## `lambert`

Use this for a mesh that should be lit, but only diffusely — no specular highlights,
no metallic or roughness response. It is the cheaper of the two lit materials, and
what you want for surfaces that are meant to read as plain matte.

There is **no glTF material that maps onto it**, so it is never inferred. Set the
material up exactly as for `pbrMetallicRoughness` below, then name the type explicitly:

1. Add a material to the object.
2. Keep the `Principled BSDF` and plug an **Image Texture** into its
   **Base Color** socket.
3. Make sure the mesh is UV-unwrapped so the texture has coordinates to sample.
4. Add the `rg_mat` custom property with the value `lambert`, as described in
   [Overriding the inferred type](#overriding-the-inferred-type-with-rg_mat).

```
[Image Texture] --Color--> [Principled BSDF] Base Color --BSDF--> [Material Output] Surface
```

Without step 4 this is an ordinary lit Blender material and converts to
`pbrMetallicRoughness`. Blender has no way to preview the difference — its viewport
knows nothing of Retrograde's shading models — so the two look identical until the
engine draws them.

Like the other lit type, the **Base Color** and **Normal** textures are carried over
and the remaining Principled inputs are dropped. See
[Adding a normal map](#adding-a-normal-map) under `pbrMetallicRoughness`.

See `asset-examples/cube-lambert.blend` for a working example.

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

> The remaining PBR inputs (metallic, roughness, occlusion, emissive) are dropped
> by the converter for now. The engine's shader for this type lights the albedo
> texture, but with a plain Lambert diffuse term standing in for the
> metallic-roughness BRDF, so a material set up this way currently renders exactly
> like a `lambert` one until those inputs are stored and shaded.

The same `.gltf`-only restriction on external images applies as for `unlit`.

### Adding a normal map

Both lit types (`pbrMetallicRoughness` and `lambert`) can carry a tangent-space
normal map alongside their base color texture:

1. Add a second **Texture ▸ Image Texture** node and load your normal map. Set its
   **Color Space** to **Non-Color** so the exporter does not treat it as sRGB.
2. Add a **Vector ▸ Normal Map** node and connect the image's **`Color`** output to
   its **`Color`** input.
3. Connect the Normal Map node's **`Normal`** output to the `Principled BSDF`'s
   **Normal** socket.
4. Export the mesh **with tangents** — the normal map is resolved against the mesh's
   tangent attribute. See [Exporting normals and tangents](#exporting-normals-and-tangents).

```
[Image Texture (Non-Color)] --Color--> [Normal Map] --Normal--> [Principled BSDF] Normal
```

The Normal Map node's **Strength** is exported as the glTF `normalTexture.scale` and
carried into the `.rgm`, so you can dial the intensity on the node rather than baking
it into the map. `1.0` (Blender's default) is the map at full strength, `0.0` is a flat
surface, and above `1.0` deepens the relief. Blender omits the value from the export
when it is exactly 1.0, which glTF and the converter both read as full strength.

A normal map on its own is not enough to make a material textured: without a base
color texture the material still converts to the `invalid` sentinel. An `unlit`
material never carries one, since it is not shaded at all.

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

> **Both are consumed by the lit material types.** Normals are what the `lambert` and
> `pbrMetallicRoughness` shaders light a surface with, and tangents are what they
> resolve a normal map against. A mesh without normals is lit as if it faced nowhere;
> a mesh without tangents ignores its material's normal map and shades from the
> vertex normal instead.

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
