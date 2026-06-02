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

module retrograde.data.model;

import retrograde.std.collections : Array;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.dlang : CopyConstructors;
import retrograde.std.string : String;

alias VertexComponent = float;
alias VertexIndex = size_t;
alias TextureCoordinateIndex = size_t;
alias UvChannelIndex = ubyte;
alias MaterialIndex = uint;
alias ImageIndex = uint;

enum ModelComponentType = sid("comp_model");
enum maxUvChannels = 8;

/// Sentinel value used by `Mesh.materialIndex` to indicate that no material is assigned.
enum MaterialIndex noMaterial = 0;

/**
 * Identifies how a material should be interpreted by the renderer.
 */
enum MaterialType : ubyte {
    invalid = 0, /// Sentinel for an unrecognized or missing material type. Renderers treat this like `noMaterial`, falling back to the render pass shader.
    vertexColors = 1, /// Use only the per-vertex RGB colors. No payload.
    unlit = 2 /// Passthrough material — references a single image (by index) from the model's image list.
}

/**
 * Identifies how an image's data is supplied.
 */
enum ImageType : ubyte {
    reference = 0, /// The payload is a path to an external image file.
    embedded = 1 /// Reserved: image data is embedded in the model. Not yet implemented.
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
    ImageIndex imageIndex; /// Populated when `type == MaterialType.unlit`: the index of the referenced `Image`. 0 otherwise.

    mixin CopyConstructors!Material;
}

/**
 * Represents an image referenced by one or more materials.
 *
 * Images are stored in a flat list on `Model` and looked up by their unique
 * 1-based `index` field. Index `0` is reserved.
 */
struct Image {
    ImageIndex index; /// 1-based unique index used by materials to reference this image.
    ImageType type;
    String path; /// Populated when `type == ImageType.reference`: the path to the external image file. Empty otherwise.

    mixin CopyConstructors!Image;
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

    // Texture Coordinates
    // VertexComponent u;
    // VertexComponent v;
    // VertexComponent tw;
}

/**
 * Represents a face in a 3D model, defined by indices of vertices.
 */
struct Face {
    VertexIndex vA; /// Index of the first vertex
    VertexIndex vB; /// Index of the second vertex
    VertexIndex vC; /// Index of the third vertex
    
    // TextureCoordinateIndex vtA, vtB, vtC;
}

/**
 * A single UV texture coordinate pair for one vertex on one channel.
 */
struct UvCoord {
    VertexComponent u;
    VertexComponent v;
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
 * Represents a 3D model, consisting of multiple meshes and the materials they reference.
 */
struct Model {
    StringId name;
    Array!Mesh meshes;
    Array!Material materials;
    Array!Image images;

    mixin CopyConstructors!Model;
}
