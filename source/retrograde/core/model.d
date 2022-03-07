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
}

alias VertexIndex = size_t;

struct Face {
    VertexIndex a, b, c;
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

    this(const(Vertex)[] vertices, const(Face)[] faces) {
        this._vertices = vertices;
        this._faces = faces;
    }

    const(Vertex)[] vertices() const {
        return _vertices;
    }

    const(Face)[] faces() const {
        return _faces;
    }

    void forEachVertex(void delegate(size_t, Vertex) fn) const {
        foreach (size_t i, const(Face) _face; _faces) {
            fn(i * 3, _vertices[_face.a]);
            fn(i * 3 + 1, _vertices[_face.b]);
            fn(i * 3 + 2, _vertices[_face.c]);
        }
    }

    void forEachFace(void delegate(size_t, Vertex, Vertex, Vertex) fn) const {
        foreach (size_t i, const(Face) _face; _faces) {
            fn(i, _vertices[_face.a], _vertices[_face.b], _vertices[_face.c]);
        }
    }
}

class ModelParseException : Exception {
    this(string message, string file = __FILE__, size_t line = __LINE__, Throwable nextInChain = null) {
        super(message, file, line, nextInChain);
    }
}

version (unittest) {
    @("Iterate over vertices")
    unittest {
        Face[] faces = [Face(0, 1, 2), Face(2, 1, 0)];
        auto vertices = [
            Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1),
            Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1),
            Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1)
        ];
        const auto mesh = new Mesh(vertices, faces);
        const auto model = new Model([mesh]);
        bool hasIterated = false;

        auto expectedVertices = [
            Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1),
            Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1),
            Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1),
            Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1),
            Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1),
            Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1)
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
            Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1),
            Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1),
            Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1)
        ];
        const auto mesh = new Mesh(vertices, faces);
        const auto model = new Model([mesh]);
        bool hasIterated = false;

        auto expectedFaces = [
            [
                Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1),
                Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1),
                Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1)
            ],
            [
                Vertex(2, 2, 2, 1, 0.3, 0.4, 0.33, 1),
                Vertex(1, 1, 1, 1, 0.5, 0.3, 0.7, 1),
                Vertex(1, 0, 0, 1, 0.5, 0.8, 1, 1)
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
