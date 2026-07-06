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

    /// Number of active UV channels (0..maxUvChannels).
    ubyte uvChannelCount;

    /// Index of the material to use for this mesh. `noMaterial` (0) means no material is assigned.
    MaterialIndex materialIndex = noMaterial;

    mixin CopyConstructors!Mesh;
}

/**
 * Identifies how a material should be interpreted by the renderer.
 */
enum MaterialType : ubyte {
    invalid = 0, /// Sentinel for an unrecognized or missing material type. Renderers treat this like `noMaterial`, falling back to the render pass shader.
    vertexColors = 1, /// Use only the per-vertex RGB colors. No payload.
    unlit = 2 /// Passthrough material — references a single texture (by index) from the model's texture list.
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
 * Represents a material referenced by one or more meshes.
 *
 * Materials are stored in a flat list on `Model` and looked up by their
 * unique 1-based `index` field. Index `0` is reserved (see `noMaterial`).
 */
struct Material {
    MaterialIndex index; /// 1-based unique index used by meshes to reference this material.
    MaterialType type;
    bool doubleSided; /// Common property (decoded from `MaterialFlags.doubleSided`): render both faces. Always false for `MaterialType.invalid`.
    TextureIndex textureIndex; /// Populated when `type == MaterialType.unlit`: the index of the referenced `Texture`. 0 otherwise.

    mixin CopyConstructors!Material;
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
