/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.data.model;

import retrograde.std.collections : Array;
import retrograde.std.stringid : StringId, sid;

alias VertexComponent = float;
alias VertexIndex = size_t;
alias TextureCoordinateIndex = size_t;

enum ModelComponentType = sid("comp_model");

struct Vertex {
    // Position
    VertexComponent x;
    VertexComponent y;
    VertexComponent z;
    VertexComponent w;

    // Color
    VertexComponent r;
    VertexComponent g;
    VertexComponent b;
    VertexComponent a;

    // Texture Coordinate
    VertexComponent u;
    VertexComponent v;
    VertexComponent tw;
}

struct Face {
    VertexIndex vA, vB, vC;
    // TextureCoordinateIndex vtA, vtB, vtC;
}

// struct TextureCoordinate {
//     VertexComponent u;
//     VertexComponent v;
//     VertexComponent w;
// }

struct Model {
    StringId name;
    Array!Vertex vertices;
    Array!Face faces; 
    //TODO: use multiple meshes instead

    this(ref return scope inout typeof(this) other) {
        this.name = other.name;
        this.vertices = other.vertices;
        this.faces = other.faces;
    }

    void opAssign(ref return scope inout typeof(this) other) {
        this.name = other.name;
        this.vertices = other.vertices;
        this.faces = other.faces;
    }
}
