/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2022 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.model;

import retrograde.core.storage : File;

alias VertexComponent = double;

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

alias VertexIndex = size_t;
alias TextureCoordinateIndex = size_t;

struct Face {
    VertexIndex vA, vB, vC;
    TextureCoordinateIndex vtA, vtB, vtC;
}

struct TextureCoordinate {
    VertexComponent u;
    VertexComponent v;
    VertexComponent w;
}

/** 
 * A data object containing a representation of a multi-dimensional geometric object
 * and its properties/metadata.
 */
class Model {
    private const(Mesh)[] _meshes;

    this(const(Mesh)[] meshes) {
        this._meshes = meshes;
    }

    const(Mesh)[] meshes() const {
        return _meshes;
    }
}

/**
 * A mesh that contains geometry data.
 */
class Mesh {
    private const(Vertex)[] _vertices;
    private const(Face)[] _faces;
    private const(TextureCoordinate)[] _textureCoordinates;

    this(const(Vertex)[] vertices, const(Face)[] faces, const(TextureCoordinate)[] textureCoordinates) {
        this._vertices = vertices;
        this._faces = faces;
        this._textureCoordinates = textureCoordinates;
    }

    const(Vertex)[] vertices() const {
        return _vertices;
    }

    const(Face)[] faces() const {
        return _faces;
    }

    const(TextureCoordinate)[] textureCoordinates() const {
        return _textureCoordinates;
    }

    void forEachVertex(void delegate(size_t, Vertex) fn) const {
        foreach (size_t i, const(Face) _face; _faces) {
            Vertex a = _vertices[_face.vA];
            Vertex b = _vertices[_face.vB];
            Vertex c = _vertices[_face.vC];

            TextureCoordinate vtA = TextureCoordinate(a.u, a.v, a.tw);
            TextureCoordinate vtB = TextureCoordinate(b.u, b.v, b.tw);
            TextureCoordinate vtC = TextureCoordinate(c.u, c.v, c.tw);
            if (textureCoordinates.length > 0) {
                vtA = _textureCoordinates[_face.vtA];
                vtB = _textureCoordinates[_face.vtB];
                vtC = _textureCoordinates[_face.vtC];
            }

            fn(i * 3, Vertex(a.x, a.y, a.z, a.w, a.r, a.g, a.b, a.a, vtA.u, vtA.v, vtA.w));
            fn(i * 3 + 1, Vertex(b.x, b.y, b.z, b.w, b.r, b.g, b.b, b.a, vtB.u, vtB.v, vtB.w));
            fn(i * 3 + 2, Vertex(c.x, c.y, c.z, c.w, c.r, c.g, c.b, c.a, vtC.u, vtC.v, vtC.w));
        }
    }

    void forEachFace(void delegate(size_t, Vertex, Vertex, Vertex) fn) const {
        foreach (size_t i, const(Face) _face; _faces) {
            //TODO: remove duplication
            Vertex a = _vertices[_face.vA];
            Vertex b = _vertices[_face.vB];
            Vertex c = _vertices[_face.vC];

            TextureCoordinate vtA = TextureCoordinate(a.u, a.v, a.tw);
            TextureCoordinate vtB = TextureCoordinate(b.u, b.v, b.tw);
            TextureCoordinate vtC = TextureCoordinate(c.u, c.v, c.tw);
            if (textureCoordinates.length > 0) {
                vtA = _textureCoordinates[_face.vtA];
                vtB = _textureCoordinates[_face.vtB];
                vtC = _textureCoordinates[_face.vtC];
            }

            fn(
                i,
                Vertex(a.x, a.y, a.z, a.w, a.r, a.g, a.b, a.a, vtA.u, vtA.v, vtA.w),
                Vertex(b.x, b.y, b.z, b.w, b.r, b.g, b.b, b.a, vtB.u, vtB.v, vtB.w),
                Vertex(c.x, c.y, c.z, c.w, c.r, c.g, c.b, c.a, vtC.u, vtC.v, vtC.w)
            );
        }
    }

    private void setVertextTextureCoordinateFromIndex(ref Vertex vertex, const TextureCoordinateIndex index) {
        auto coordinate = _textureCoordinates[index];
        vertex.u = coordinate.u;
        vertex.v = coordinate.v;
        vertex.tw = coordinate.w;
    }
}

/** 
 * Typically thrown when a model loader fails to parse model data.
 */
class ModelParseException : Exception {
    this(string message, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
        super(message, file, line, nextInChain);
    }
}

/** 
 * Common interface for model loaders.
 */
interface ModelLoader {
    public Model load(File modelFile);
}

version (unittest) {
    @("Iterate over vertices")
    unittest {
        Face[] faces = [Face(0, 1, 2), Face(2, 1, 0)];
        auto vertices = [
            Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1, 1, 0, 0),
            Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1, 0, 1, 0),
            Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1, 0, 0, 1)
        ];
        auto mesh = new Mesh(vertices, faces, []);
        auto model = new Model([mesh]);
        bool hasIterated = false;

        auto expectedVertices = [
            Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1, 1, 0, 0),
            Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1, 0, 1, 0),
            Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1, 0, 0, 1),
            Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1, 0, 0, 1),
            Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1, 0, 1, 0),
            Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1, 1, 0, 0)
        ];

        model.meshes[0].forEachVertex((size_t index, Vertex vert) {
            assert(vert == expectedVertices[index]);
            hasIterated = true;
        });

        assert(mesh.vertices.length == 3);
        assert(mesh.faces.length == 2);
        assert(hasIterated);
    }

    @("Iterate over faces")
    unittest {
        Face[] faces = [Face(0, 1, 2), Face(2, 1, 0)];
        auto vertices = [
            Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1, 1, 0, 0),
            Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1, 0, 1, 0),
            Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1, 0, 0, 1)
        ];
        const auto mesh = new Mesh(vertices, faces, []);
        const auto model = new Model([mesh]);
        bool hasIterated = false;

        auto expectedFaces = [
            [
                Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1, 1, 0, 0),
                Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1, 0, 1, 0),
                Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1, 0, 0, 1)
            ],
            [
                Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1, 0, 0, 1),
                Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1, 0, 1, 0),
                Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1, 1, 0, 0)
            ]
        ];

        model.meshes[0].forEachFace((size_t index, Vertex vertA, Vertex vertB, Vertex vertC) {
            assert(expectedFaces[index][0] == vertA);
            assert(expectedFaces[index][1] == vertB);
            assert(expectedFaces[index][2] == vertC);

            hasIterated = true;
        });

        assert(hasIterated);
    }
}
