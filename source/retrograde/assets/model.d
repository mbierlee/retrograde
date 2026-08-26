/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.assets.model;

import retrograde.std.collections : Array;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.dlang : CopyConstructors;
import retrograde.std.string : String;

alias VertexComponent = float;
alias VertexIndex = size_t;
alias TextureCoordinateIndex = size_t;
alias UvChannelIndex = ubyte;
alias MaterialIndex = uint;
alias TextureIndex = uint;

enum ModelComponentType = sid("comp_model");
enum maxUvChannels = 8;

/// Sentinel value used by `Mesh.materialIndex` to indicate that no material is assigned.
enum MaterialIndex noMaterial = 0;

/**
 * Represents a 3D model, consisting of multiple meshes and the materials they reference.
 */
struct Model {
    StringId name;
    Array!Mesh meshes;
    Array!Material materials;
    Array!Texture textures;

    mixin CopyConstructors!Model;
}

/**
 * Represents a mesh in a 3D model, consisting of vertices and faces.
 */
struct Mesh {
    Array!Vertex vertices;
    Array!Face faces;

    /// Flat channel-major UV data: channel c, vertex i lives at index `c * vertices.length + i`.
    Array!UvCoord uvCoords;

    /// One normal per vertex, in vertex order. Empty when the mesh has no normals.
    Array!Normal normals;

    /// One tangent per vertex, in vertex order. Empty when the mesh has no tangents.
    Array!Tangent tangents;

    /// Number of active UV channels (0..maxUvChannels).
    ubyte uvChannelCount;

    /// Index of the material to use for this mesh. `noMaterial` (0) means no material is assigned.
    MaterialIndex materialIndex = noMaterial;

    mixin CopyConstructors!Mesh;
}

/**
 * Bit flags packed into a mesh's "attribute flags" byte.
 *
 * These mark which optional per-vertex attribute blocks follow the mesh's UV
 * data in the RGM file. Bits not listed here are reserved; they are written as
 * 0 and rejected on read.
 *
 * On a loaded `Mesh` the presence of an attribute is derived from the length of
 * its array, so these flags are only used while reading and writing the file.
 */
enum MeshAttributeFlags : ubyte {
    none = 0,
    normals = 1 << 0, /// A normal block follows the UV data.
    tangents = 1 << 1 /// A tangent block follows the normal data. Requires `normals` and at least one UV channel.
}

/**
 * Identifies how a material should be interpreted by the renderer.
 */
enum MaterialType : ubyte {
    invalid = 0, /// Sentinel for an unrecognized or missing material type. Renderers treat this like `noMaterial`, falling back to the render pass shader.
    vertexColors = 1, /// Use only the per-vertex RGB colors. No payload.
    unlit = 2, /// Passthrough material — an optional texture (by index) from the model's texture list, tinted by a base color factor.
    lambert = 3, /// Purely diffuse lit material. References an optional albedo texture and base color factor, plus an optional normal map (both textures by index). Has no glTF counterpart to be inferred from, so a converter only assigns it when a material asks for it by name.
    pbrMetallicRoughness = 4 /// Physically based metallic-roughness material. An upgrade of `lambert`: same albedo and normal map references for now, but shaded with a full BRDF.
}

/**
 * Bit flags packed into a material's "common flags" byte.
 *
 * These are properties shared by every material type except `invalid`. In the
 * RGM file they live in a single ubyte that follows the type byte. Bits not
 * listed here are reserved for future common properties; they are written as 0
 * and ignored on read.
 */
enum MaterialFlags : ubyte {
    none = 0,
    doubleSided = 1 << 0 /// Render both faces (disable back-face culling) for this material.
}

/**
 * An RGBA multiplier over a material's albedo.
 *
 * Named components rather than a `float[4]`: `CopyConstructors` skips static array members,
 * so one would be silently reset to its default every time a `Material` is copied.
 */
struct BaseColorFactor {
    float r = 1.0;
    float g = 1.0;
    float b = 1.0;
    float a = 1.0;
}

/**
 * Represents a material referenced by one or more meshes.
 *
 * Materials are stored in a flat list on `Model` and looked up by their
 * unique 1-based `index` field. Index `0` is reserved (see `noMaterial`).
 */
struct Material {
    MaterialIndex index; /// 1-based unique index used by meshes to reference this material.
    MaterialType type;
    bool doubleSided; /// Common property (decoded from `MaterialFlags.doubleSided`): render both faces. Always false for `MaterialType.invalid`.
    TextureIndex textureIndex; /// Populated when `type.referencesTexture`: the index of the referenced albedo `Texture`. 0 when the material has none, and is colored by `baseColorFactor` alone.
    BaseColorFactor baseColorFactor; /// Populated when `type.referencesTexture`: an RGBA multiplier over the sampled albedo texture. With no texture referenced it is the albedo outright, which is what lets a flat-colored material exist without an image asset. Stored and used as-is: no range check, no color-space conversion.
    TextureIndex normalTextureIndex; /// Populated when `type.referencesNormalTexture`: the index of the referenced tangent-space normal map `Texture`. 0 when the material has none.
    float normalTextureScale = 1.0; /// Populated when `type.referencesNormalTexture`: how strongly the normal map perturbs the surface normal. Scales the tangent and bitangent components of the sampled normal, leaving the component along the surface normal alone: 1 is full strength, 0 is flat, above 1 exaggerates.

    mixin CopyConstructors!Material;
}

/**
 * Whether materials of this type carry an albedo payload: a texture index referencing a
 * single texture from the model's texture list, plus the base color factor multiplied
 * over it.
 *
 * The texture reference is optional — an index of 0 means the material has no texture and
 * takes its color from the factor alone. The payload is still present either way, so this
 * predicate says what a material of this type stores, not whether it ended up with a texture.
 */
bool referencesTexture(MaterialType type) {
    return type == MaterialType.unlit || type == MaterialType.lambert
        || type == MaterialType.pbrMetallicRoughness;
}

/**
 * Whether materials of this type carry a second texture index payload referencing a
 * tangent-space normal map from the model's texture list.
 *
 * Unlike the albedo reference this one is optional: an index of 0 means the material
 * has no normal map. Deliberately kept apart from `isLit`, whose member list happens
 * to match: this predicate describes what the material's payload contains, `isLit`
 * describes how it is shaded.
 */
bool referencesNormalTexture(MaterialType type) {
    return type == MaterialType.lambert || type == MaterialType.pbrMetallicRoughness;
}

/**
 * Whether materials of this type are shaded by the scene's lights.
 *
 * A renderer needs vertex normals and the frame's lights to draw these; the others are
 * shaded from their own vertex data alone.
 */
bool isLit(MaterialType type) {
    return type == MaterialType.lambert || type == MaterialType.pbrMetallicRoughness;
}

/**
 * Identifies how a texture's image data is supplied.
 */
enum TextureType : ubyte {
    reference = 0, /// The payload is a path to an external image file.
    embedded = 1 /// Reserved: image data is embedded in the model. Not yet implemented.
}

/**
 * Magnification filter used when sampling a texture.
 *
 * Mirrors the option set of the glTF sampler `magFilter` (and OpenGL's
 * `GL_TEXTURE_MAG_FILTER`), but uses engine-local sequential values rather than
 * the glTF/GL constant numbers. `unspecified` means the engine picks a default.
 */
enum TextureMagFilter : ubyte {
    unspecified = 0, /// No filter stored; the renderer chooses its default.
    nearest = 1,
    linear = 2
}

/**
 * Minification filter used when sampling a texture.
 *
 * Mirrors the option set of the glTF sampler `minFilter` (and OpenGL's
 * `GL_TEXTURE_MIN_FILTER`), but uses engine-local sequential values rather than
 * the glTF/GL constant numbers. `unspecified` means the engine picks a default.
 */
enum TextureMinFilter : ubyte {
    unspecified = 0, /// No filter stored; the renderer chooses its default.
    nearest = 1,
    linear = 2,
    nearestMipmapNearest = 3,
    linearMipmapNearest = 4,
    nearestMipmapLinear = 5,
    linearMipmapLinear = 6
}

/**
 * Wrap (address) mode used when sampling a texture outside the `[0, 1]` range.
 *
 * Applied independently to the S and T axes. Mirrors the option set of the
 * glTF sampler `wrapS`/`wrapT` (and OpenGL's `GL_TEXTURE_WRAP_S`/`_T`), but uses
 * engine-local sequential values rather than the glTF/GL constant numbers.
 * `unspecified` means the engine picks a default.
 */
enum TextureWrap : ubyte {
    unspecified = 0, /// No wrap mode stored; the renderer chooses its default.
    repeat = 1,
    clampToEdge = 2,
    mirroredRepeat = 3
}

/**
 * Represents a texture referenced by one or more materials.
 *
 * Textures are stored in a flat list on `Model` and looked up by their unique
 * 1-based `index` field. Index `0` is reserved.
 */
struct Texture {
    TextureIndex index; /// 1-based unique index used by materials to reference this texture.
    TextureType type;
    TextureMagFilter magFilter; /// Magnification filter. `unspecified` (default) lets the renderer choose.
    TextureMinFilter minFilter; /// Minification filter. `unspecified` (default) lets the renderer choose.
    TextureWrap wrapS; /// Wrap mode on the S axis. `unspecified` (default) lets the renderer choose.
    TextureWrap wrapT; /// Wrap mode on the T axis. `unspecified` (default) lets the renderer choose.
    String path; /// Populated when `type == TextureType.reference`: the path to the external image file. Empty otherwise.

    mixin CopyConstructors!Texture;
}

/**
 * Represents a vertex in a 3D model.
 */
struct Vertex {
    // Position coordinates
    VertexComponent x; /// X coordinate
    VertexComponent y; /// Y coordinate
    VertexComponent z; /// Z coordinate
    VertexComponent w; /// W coordinate (for homogeneous coordinates)

    // Color components
    VertexComponent r; /// Red component
    VertexComponent g; /// Green component
    VertexComponent b; /// Blue component
    VertexComponent a; /// Alpha component (transparency)
}

/**
 * Represents a face in a 3D model, defined by indices of vertices.
 */
struct Face {
    VertexIndex vA; /// Index of the first vertex
    VertexIndex vB; /// Index of the second vertex
    VertexIndex vC; /// Index of the third vertex
}

/**
 * A single UV texture coordinate pair for one vertex on one channel.
 */
struct UvCoord {
    VertexComponent u;
    VertexComponent v;
}

/**
 * A unit-length surface normal for one vertex, in model space.
 */
struct Normal {
    VertexComponent x; /// X component
    VertexComponent y; /// Y component
    VertexComponent z; /// Z component
}

/**
 * A tangent basis vector for one vertex, in model space.
 *
 * `x`, `y` and `z` form the unit-length U direction of the first UV channel. The
 * bitangent is not stored; it is derived as `cross(normal, xyz) * w`.
 */
struct Tangent {
    VertexComponent x; /// X component
    VertexComponent y; /// Y component
    VertexComponent z; /// Z component

    /// Handedness sign, either +1 or -1. Mirrored UV islands flip the bitangent.
    VertexComponent w;
}
