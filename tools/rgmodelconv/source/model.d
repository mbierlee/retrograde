/**
 * rgmodelconv - Common in-memory model representation.
 *
 * The intermediate form produced by the reader and consumed by the writer. It
 * captures exactly the data the RGM format needs — geometry, per-vertex colors,
 * UV channels and material classification inputs — decoupled from both the glTF
 * source structure and the RGM byte layout.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module model;

import retrograde.assets.model : TextureMagFilter, TextureMinFilter, TextureWrap;

/**
 * A single glTF primitive, flattened from `meshes[].primitives[]`. Each primitive
 * becomes one RGM mesh, in glTF iteration order (mesh 0's primitives first, then
 * mesh 1's, and so on).
 *
 * Geometry is read straight from the glTF accessors: `positions`, `colors`,
 * `uvChannels`, `normals` and `tangents` are indexed by vertex, and `indices` is
 * a flat triangle list. Normals and tangents are passed through as authored; the
 * converter does not generate either of them. No
 * vertex welding or re-indexing is performed — the data is kept exactly as the
 * glTF file supplies it.
 */
struct Primitive {
    uint vertexCount;
    float[] positions; /// vertexCount * 3 (x, y, z).
    bool hasColors;
    float[] colors; /// vertexCount * 3 (r, g, b); empty when hasColors is false.
    float[][] uvChannels; /// uvChannels[c] holds vertexCount * 2 (u, v) values.
    float[] normals; /// vertexCount * 3 (x, y, z); empty when the primitive has no NORMAL.
    float[] tangents; /// vertexCount * 4 (x, y, z, handedness); empty when the primitive has no usable TANGENT.
    uint[] indices; /// Triangle list; length is a multiple of 3.
    int materialIndex = -1; /// glTF material index, or -1 when the primitive has none.
}

/**
 * A material's resolved external texture: the image path plus the sampling
 * filters and wrap modes glTF associated with it. `path` is empty when the
 * material references no such external image. The filters and wrap modes use the
 * engine's `TextureMagFilter` / `TextureMinFilter` / `TextureWrap` directly;
 * `unspecified` means the source left the choice to the renderer (no glTF
 * sampler, or the sampler omitted that property).
 */
struct TextureRef {
    string path;
    TextureMagFilter magFilter = TextureMagFilter.unspecified;
    TextureMinFilter minFilter = TextureMinFilter.unspecified;
    TextureWrap wrapS = TextureWrap.unspecified;
    TextureWrap wrapT = TextureWrap.unspecified;
}

/**
 * Classification inputs extracted from a single glTF material: the shading model
 * (`KHR_materials_unlit`), the double-sided flag, and the material's texture
 * references.
 *
 * Lit (PBR) materials are converted as `pbrMetallicRoughness` ones, carrying their
 * base color (albedo), normal, metallic-roughness and occlusion textures plus the base
 * color, metallic, roughness and occlusion strength factors: the RGM format cannot
 * express the remaining metallic-roughness input (emissive) yet.
 */
struct MaterialInfo {
    bool unlit; /// True when the material declares the KHR_materials_unlit extension. Decides between the `unlit` and `pbrMetallicRoughness` material types for a textured material.
    string materialTypeOverride; /// Raw value of the material's `extras.rg_mat`, naming the RGM material type to write instead of the automatically classified one. "" when the material has none.
    bool doubleSided; /// glTF `material.doubleSided` (defaults to false).
    bool hasAnyTexture; /// True when the material references at least one texture of any slot, including the slots that are not converted.
    TextureRef baseColorTexture; /// The externally referenced base color (albedo) texture (path + filters); `path` is "" when the material has none.
    float[4] baseColorFactor = [1.0f, 1.0f, 1.0f, 1.0f]; /// glTF `pbrMetallicRoughness.baseColorFactor`: the RGBA multiplier over the base color texture, and the material's color outright when it has no texture. Defaults to opaque white, which is also what glTF means by an absent factor.
    TextureRef normalTexture; /// The externally referenced tangent-space normal map (path + filters); `path` is "" when the material has none. Only written for material types that reference one.
    float normalTextureScale = 1.0f; /// glTF `normalTexture.scale`: how strongly the normal map perturbs the surface normal. Defaults to 1 (full strength), which is also what glTF means by an absent `scale`.
    TextureRef metallicRoughnessTexture; /// The externally referenced metallic-roughness map (path + filters), packing roughness in green and metalness in blue; `path` is "" when the material has none. Only written for material types that shade with a metallic-roughness BRDF.
    float metallicFactor = 1.0f; /// glTF `pbrMetallicRoughness.metallicFactor`: how metallic the surface is, 0 being a dielectric and 1 a raw metal. Multiplies the map's blue channel where there is one. Defaults to 1, which is also what glTF means by an absent factor. Only written for material types that shade with a metallic-roughness BRDF.
    float roughnessFactor = 1.0f; /// glTF `pbrMetallicRoughness.roughnessFactor`: how rough the surface is, 0 being a perfect mirror and 1 fully diffuse. Multiplies the map's green channel where there is one. Defaults to 1, which is also what glTF means by an absent factor. Only written for material types that shade with a metallic-roughness BRDF.
    TextureRef occlusionTexture; /// The externally referenced ambient occlusion map (path + filters), read from its red channel; `path` is "" when the material has none. Commonly the same image as `metallicRoughnessTexture`, which the writer's de-duplication then collapses into one texture entry. Only written for material types that carry an occlusion payload.
    float occlusionStrength = 1.0f; /// glTF `occlusionTexture.strength`: how strongly the occlusion map attenuates indirect light. Defaults to 1 (full strength), which is also what glTF means by an absent `strength`. Only written for material types that carry an occlusion payload.
}

/**
 * A whole model in intermediate form: the flattened primitives and the material
 * list they reference by index.
 */
struct ModelData {
    Primitive[] primitives;
    MaterialInfo[] materials;
}
