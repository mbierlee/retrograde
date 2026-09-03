# Authoring Retrograde materials in Blender

This guide explains how to set up materials in **Blender 5.1** so that
`rgmodelconv` classifies them into the right Retrograde [material type](rgm-fileformat.md)
when you export to glTF and convert to `.rgm`.

**`rgmodelconv` reads glTF 2.0 only** — specifically a `.gltf` text file with an
external `.bin` buffer and external image files. Binary `.glb` containers are not
supported, so in Blender's glTF exporter pick the **glTF Separate (.gltf + .bin +
textures)** format. Material classification is driven by glTF concepts such as
the `pbrMetallicRoughness` base color texture and factor, and the `doubleSided` flag.

By default `rgmodelconv` infers the type from what the material references. You can
also name the type outright with an `rg_mat` custom property, which is the only way to
reach a type that no glTF material maps onto — see
[Overriding the inferred type](#overriding-the-inferred-type-with-rg_mat).

| Retrograde type         | How it's recognized                                            |
| ----------------------- | -------------------------------------------------------------- |
| no material / `invalid` | No material is assigned to the mesh. Never inferred for a material that exists — only an `rg_mat` override produces the `invalid` sentinel. |
| `vertexColors`          | The mesh has a color attribute + the material has no textures. |
| `unlit`                 | The material declares `KHR_materials_unlit` (and is not caught by the `vertexColors` rule above). |
| `lambert`               | Never inferred. Requires `rg_mat`. |
| `pbrMetallicRoughness`  | Anything else — a regular lit material, with or without textures. |

**The base color, normal, metallic-roughness, occlusion and emissive textures are all
converted.** A regular `Principled BSDF` material exports as glTF PBR (metallic-roughness)
and becomes a `pbrMetallicRoughness` material in the `.rgm`, keeping its **Base Color**,
**Normal** (with the normal map's strength), **Metallic**/**Roughness**, occlusion (with its
strength) and **Emission** textures. The **Metallic**, **Roughness**, **Emission Color** and
**Emission Strength** sliders are carried over too, and scale their map where there is one.
Which textures a type carries differs: `pbrMetallicRoughness` takes all five, `lambert` the
base color and normal maps only (it has no BRDF to feed a metallic-roughness map or
occlusion into, and no term an emitted radiance would belong in), and `unlit` only its base
color texture, since an unlit material is never shaded.

**A base color texture is optional.** A material whose **Base Color** is a plain color
rather than an image is still a real material: the color is carried over as the base
color factor and the material is drawn in it. See
[Coloring a material without a texture](#coloring-a-material-without-a-texture). Where
there *is* a texture, the base color acts as a tint over it — leave it at white to get
the texture untouched.

Note the ordering in the table: **the `vertexColors` rule is checked first**. A material
with no textures on a mesh that carries a color attribute becomes `vertexColors` even
when its Base Color is set, and that base color is dropped. If you want the flat color
instead, either remove the mesh's color attribute or set `rg_mat` explicitly.

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
what its chosen type needs — a color attribute for `vertexColors`. (`unlit`, `lambert`
and `pbrMetallicRoughness` need nothing in particular: without a base color texture they
fall back to the base color factor.) Ask for a type the material cannot back, or misspell
the name, and `rgmodelconv` prints a warning and keeps the type it inferred, rather than
writing out a material the engine cannot read.

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

This rule is checked before every other one, so it also wins over a base color: a
vertex-painted mesh whose material has a flat Base Color set is still emitted as
`vertexColors`, and the base color is dropped.

See `asset-examples/cube-vertexcolors.blend` for a working example.

---

## Coloring a material without a texture

Use this for a mesh that should be a plain, even color — no image needed.

1. Add a material to the object.
2. In the **Material Properties** tab, click the **Base Color** swatch of the
   `Principled BSDF` and pick your color.
3. Leave the mesh's **Color Attributes** list empty (in **Object Data Properties**).
   A color attribute would make the converter emit `vertexColors` instead and drop
   the color you just picked.

That is the whole setup — there is no node wiring to do:

```
[Principled BSDF] Base Color = a flat color --BSDF--> [Material Output] Surface
```

The color exports as glTF's `baseColorFactor` and lands in the `.rgm` as the material's
base color, giving a `pbrMetallicRoughness` material with no albedo texture. Wire the
color straight into `Material Output` instead of through the `Principled BSDF` (as in
[`unlit`](#unlit)) to get an `unlit` material in the same flat color.

The same field doubles as a **tint** when the material *does* have a base color texture:
the engine multiplies the two. Leaving Base Color at white is what gives an untinted
texture, which is why every textured example in this guide leaves it alone.

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
plus a **Normal** map if you plug one in, and the **Metallic** and **Roughness**
slider values. The rest of the Principled inputs (Emission, Specular, ...) are
**not** converted — they are dropped, as are any image textures plugged into
Metallic or Roughness. See `pbrMetallicRoughness` below.

> `unlit` only works when exporting as a **`.gltf`** file, because embedded images
> (as produced by `.glb`) are not supported.

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
and the remaining Principled inputs are dropped. Being purely diffuse, `lambert` has no
use for the **Metallic** and **Roughness** sliders — or a texture plugged into them —
so unlike `pbrMetallicRoughness` it stores neither. See
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

The **Metallic** and **Roughness** sliders are carried over as single values for the
whole material, and the engine shades with them: a Cook-Torrance metallic-roughness
BRDF, so **Metallic** decides whether the base color is the surface's diffuse color or
the tint of its reflection, and **Roughness** how tight the highlight is. To vary either
across the surface, plug in a map as well — see
[Adding a metallic-roughness map](#adding-a-metallic-roughness-map). Occlusion and
emission are carried over too, maps and all — see
[Adding an occlusion map](#adding-an-occlusion-map) and
[Making a material glow](#making-a-material-glow).

> **Watch the Metallic slider.** glTF defaults an unset `metallicFactor` to `1.0`, so
> a material exported without touching it is a *full metal*: no diffuse color at all,
> lit only by reflections. Blender's own default is `0.0`, which exports explicitly —
> but a material assembled by other means may not say, and will render dark and
> mirror-like. Set the slider deliberately.

> Reflections come from the hemispherical ambient light, not from the scene: there is
> no environment map, so a smooth metal reflects the sky/ground gradient rather
> than what is actually around it. Highlights from point lights are real.

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

A normal map does not need a base color texture beside it: a material with nothing but
a normal map still converts, colored by its base color factor. An `unlit` material never
carries one, since it is not shaded at all.

### Adding a metallic-roughness map

**`pbrMetallicRoughness` only** — `lambert` is purely diffuse and has no BRDF to feed
one into, so it drops the map along with the sliders.

Where the **Metallic** and **Roughness** sliders describe the whole material, a
metallic-roughness map varies both across the surface. It is a single **packed** image —
roughness in its green channel, metalness in its blue one — which is how glTF stores the
pair and how the `.rgm` keeps it:

1. Add a **Texture ▸ Image Texture** node and load the packed map. Set its **Color
   Space** to **Non-Color**: the map is data, not color.
2. Add a **Converter ▸ Separate Color** node and connect the image's **`Color`** output
   to its **`Color`** input.
3. Connect **`Green`** to the `Principled BSDF`'s **Roughness** socket and **`Blue`** to
   its **Metallic** socket.

```
                              /--Green--> [Principled BSDF] Roughness
[Image Texture (Non-Color)] --Color--> [Separate Color]
                              \--Blue---> [Principled BSDF] Metallic
```

Wired this way the exporter recognises the channel split and writes the image straight
out as the glTF `metallicRoughnessTexture`, so the map you painted is the map that ends
up in the `.rgm`. Two separate grayscale maps plugged into the two sockets also work, but
the exporter then packs them into a *new* combined image at export time — check which
file the `.gltf` ends up referencing before converting.

The **Metallic** and **Roughness** sliders are still written alongside the map, and the
engine multiplies them into it. Blender leaves them at `1.0` when a texture drives the
socket, which passes the map through untouched; a value below that scales the whole map
down.

The map is sampled with UV channel 0, so the mesh needs to be UV-unwrapped — the same
coordinates the base color and normal maps use. Unlike a normal map it needs no tangents.

As with the normal map, a metallic-roughness map on its own is a complete material: with
no base color texture the surface takes its color from the base color factor and its
shading from the map.

### Adding an occlusion map

**`pbrMetallicRoughness` only** — like the metallic-roughness map, `lambert` drops it.

An occlusion map is baked shadowing: the creases, crevices and contact points that stay
dark because the surface around them blocks most of the light reaching them. It lives in
the image's **red** channel — the channel the metallic-roughness map leaves free — so one
image can carry all three inputs. That combination is usually called an **ORM** map
(occlusion, roughness, metalness), and it is what most texture libraries ship.

The wrinkle is that `Principled BSDF` has **no occlusion socket**. Blender's glTF exporter
picks occlusion up from a separate node group instead:

1. Add a **Group** node named **`glTF Material Output`** (called **`glTF Settings`** in
   Blender 3.x and earlier). If it does not exist yet, create a new node group with a
   single input socket named exactly **`Occlusion`**. The name is what the exporter
   matches on.
2. Add a **Texture ▸ Image Texture** node and load the map. Set its **Color Space** to
   **Non-Color**: like the metallic-roughness map, it is data rather than color.
3. Add a **Converter ▸ Separate Color** node and connect the image's **`Color`** output to
   its **`Color`** input.
4. Connect **`Red`** to the group's **`Occlusion`** input.

With an ORM map the same **Separate Color** node feeds all three sockets:

```
                              /--Red----> [glTF Material Output] Occlusion
[Image Texture (Non-Color)] --Color--> [Separate Color]
                              |--Green--> [Principled BSDF] Roughness
                              \--Blue---> [Principled BSDF] Metallic
```

The `.rgm` stores occlusion as a texture reference of its own, so the two slots may point
at one image (as above) or at two separate ones. Where they share an image the converter
writes a single texture entry and the renderer uploads it once, so packing costs nothing
either way.

#### Seeing it in the viewport

That node group is **export-only** — Blender's viewport ignores it, so the occlusion you
just wired up will not show up in Material Preview or Rendered mode. To preview it,
additionally multiply the map into the base color with a **Color ▸ Mix** node set to
**Multiply**, feeding the result into **Base Color**:

```
[Base Color image]  --> A --\
                             [Mix (Multiply)] --> [Principled BSDF] Base Color
[Occlusion (Red)]   --> B --/
```

**The socket order matters for the export, not just the look.** Put the base color texture
in slot **A** and the occlusion in slot **B**. The exporter walks the chain into **Base
Color** and takes the *first* image it finds as the material's `baseColorTexture`, so
wiring them the other way round exports the **occlusion map as the albedo** — a material
that converts without complaint and comes out grey and wrong.

Note this is a preview convenience only. The engine applies occlusion itself, so a map
multiplied into the base color *and* exported through the group is applied twice — once
baked into the albedo, once by the shader. If you want the viewport and the engine to
match exactly, mute the **Mix** node before exporting.

#### What it affects

Occlusion attenuates **indirect (ambient) light only**, which is what glTF specifies. Light
from a scene light is left alone, so a crease a lamp shines straight into still lights up —
that is the difference between baked occlusion and a shadow. In a scene lit purely by
bright point lights the effect is therefore subtle; it shows up most on surfaces facing
away from every light, where the ambient hemisphere is all the light there is.

The **strength** (glTF `occlusionTexture.strength`, exposed by Blender on the group input's
default value) dials the map back toward no occlusion at all: `1.0` is full strength, `0.0`
ignores the map. Values in between fade it rather than darkening it further.

The map is sampled with UV channel 0, so the mesh needs to be UV-unwrapped. Like the
metallic-roughness map, it needs no tangents.

### Making a material glow

A `pbrMetallicRoughness` material carries the `Principled BSDF`'s emission, which is
light the surface gives off by itself:

1. Set **Emission Color** to the color it should glow in.
2. Raise **Emission Strength** above `0` — at `0` the material emits nothing, which is
   Blender's default for everything except a material built from an emission preset.

On their own the two are per-material values, so the surface glows evenly across its whole
area. To pick out *which parts* glow, plug an image into **Emission Color** — see
[Adding an emissive map](#adding-an-emissive-map).

Blender splits the value it exports in two. Emission Color goes to glTF's
`emissiveFactor`, which is capped at `1.0` per component; a strength above that is
exported separately as `KHR_materials_emissive_strength`, with the color normalized to
fit. `rgmodelconv` stores both, and the engine multiplies them back together — so the
number to reach for when a surface should read as a *source of light* rather than a
brightly tinted object is **Emission Strength**, not a brighter color.

#### Adding an emissive map

**`pbrMetallicRoughness` only** — `lambert` has no term to add emitted light to, so it
drops the map along with the factor.

An emissive map says *where* a surface glows: the lit windows on a building, the display
on a panel, the runes on a blade. Plug a **Texture ▸ Image Texture** node into the
`Principled BSDF`'s **Emission Color** socket and the exporter writes it as glTF's
`emissiveTexture`, which `rgmodelconv` carries over.

Unlike the metallic-roughness and occlusion maps, leave its **Color Space** at **sRGB**:
this map is color the eye sees directly, not data fed into the BRDF.

The map is sampled with UV channel 0, so the mesh needs to be UV-unwrapped. Like the
metallic-roughness and occlusion maps, it needs no tangents.

> **Emission Strength gates the map too.** Blender writes an image on Emission Color as
> the texture plus a white `emissiveFactor`, and the engine multiplies the two — so a
> material left at Blender's default **Emission Strength** of `0` emits *nothing at all*,
> map or no map. Raise it above `0` or the map will not show. The same applies to a black
> Emission Color: the factor multiplies the map rather than being replaced by it.

#### What it affects

Emission is added to the surface **after all shading**, and answers to nothing else in
the scene:

- It is **not lit**, so it shows at full brightness on faces turned away from every
  light — which is exactly what makes it read as a glow.
- It is **not attenuated by the occlusion map**, unlike the ambient terms: a surface that
  emits is a source, not a receiver.
- It **lights nothing around it**. There is no global illumination, so a glowing panel
  does not brighten the wall beside it. Put an actual light there as well when the scene
  needs that.
- It does **not** affect opacity: transparency still comes from the base color factor's
  alpha.

Nothing tone-maps the result either, so a large enough strength simply clips to white.

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
