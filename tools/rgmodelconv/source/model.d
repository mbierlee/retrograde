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
 * Lit (PBR) materials are converted as `pbrMetallicRoughness` ones, but only the
 * base color (albedo) texture is carried over: the RGM format cannot express the
 * remaining metallic-roughness inputs yet.
 */
struct MaterialInfo {
    bool unlit; /// True when the material declares the KHR_materials_unlit extension. Decides between the `unlit` and `pbrMetallicRoughness` material types for a textured material.
    bool doubleSided; /// glTF `material.doubleSided` (defaults to false).
    bool hasAnyTexture; /// True when the material references at least one texture of any slot, including the slots that are not converted.
    TextureRef baseColorTexture; /// The externally referenced base color (albedo) texture (path + filters); `path` is "" when the material has none.
}

/**
 * A whole model in intermediate form: the flattened primitives and the material
 * list they reference by index.
 */
struct ModelData {
    Primitive[] primitives;
    MaterialInfo[] materials;
}
