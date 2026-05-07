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

alias VertexComponent = float;
alias VertexIndex = size_t;
alias TextureCoordinateIndex = size_t;
alias UvChannelIndex = ubyte;

enum ModelComponentType = sid("comp_model");
enum maxUvChannels = 8;

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

    /// Number of active UV channels (0..maxUvChannels).
    ubyte uvChannelCount;

    /// Flat channel-major UV data: channel c, vertex i lives at index `c * vertices.length + i`.
    Array!UvCoord uvCoords;

    mixin CopyConstructors!Mesh;
}

/**
 * Represents a 3D model, consisting of multiple meshes.
 */
struct Model {
    StringId name;
    Array!Mesh meshes;

    mixin CopyConstructors!Model;
}
