# Authoring Retrograde materials in Blender

This guide explains how to set up materials in **Blender 5.1** so that
`rgmodelconv` classifies them into the right Retrograde [material type](rgm-fileformat.md)
when you export to glTF and convert to `.rgm`.

**`rgmodelconv` reads glTF 2.0 only** — specifically a `.gltf` text file with an
external `.bin` buffer and external image files. Binary `.glb` containers are not
supported, so in Blender's glTF exporter pick the **glTF Separate (.gltf + .bin +
textures)** format. Material classification is driven by glTF concepts such as
`KHR_materials_unlit` and the `doubleSided` flag.

Retrograde does not read a custom "material type" property. Instead,
`rgmodelconv` infers the type from how the material is shaded and what it
references:

| Retrograde type         | How it's recognized                                             |
| ----------------------- | --------------------------------------------------------------- |
| no material / `invalid` | No material is assigned to the mesh.                            |
| `vertexColors`          | Unlit shading + the mesh has a color attribute + no textures.   |
| `unlit`                 | Unlit shading + the material references a single image texture. |

In every case the trick to getting **unlit** shading exported is the same:
wire your color source **directly into the `Surface` socket of the `Material
Output` node**, bypassing the `Principled BSDF`. A surface fed by a raw color
(rather than a lighting shader) is exported with the `KHR_materials_unlit`
extension, which is exactly what the converter looks for.

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
2. In the **Shader Editor**, delete the `Principled BSDF`.
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

The converter only emits `vertexColors` when the material is unlit, the mesh
actually has a color attribute, **and** no textures are referenced — so don't
add an image texture if you want this type.

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

> At the moment `unlit` only works when exporting as a **`.gltf`** file, because
> embedded images (as produced by `.glb`) are not supported yet.

See `asset-examples/cube-unlit-textured.blend` for a working example.

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
