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

import retrograde.core.math : Vector, Vector3D;

alias Vertex = Vector3D;
alias VertexIndex = size_t;
alias Face = Vector!(VertexIndex, 3);

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
            fn(i * 3, _vertices[_face.x]);
            fn(i * 3 + 1, _vertices[_face.y]);
            fn(i * 3 + 2, _vertices[_face.z]);
        }
    }
}

version (unittest) {
    @("Iterate over meshes")
    unittest {
        Face[] faces = [Face(0, 1, 2), Face(2, 1, 0)];
        auto vertices = [Vertex(1, 0, 0), Vertex(1, 1, 1), Vertex(2, 2, 2)];
        const auto mesh = new Mesh(vertices, faces);
        const auto model = new Model([mesh]);
        bool hasIterated = false;

        auto expectedVertices = [
            Vertex(1, 0, 0),
            Vertex(1, 1, 1),
            Vertex(2, 2, 2),
            Vertex(2, 2, 2),
            Vertex(1, 1, 1),
            Vertex(1, 0, 0)
        ];

        model.meshes[0].forEachVertex((size_t index, Vertex vec) {
            assert(vec == expectedVertices[index]);
            hasIterated = true;
        });

        assert(mesh.vertices.length == 3);
        assert(mesh.faces.length == 2);
        assert(hasIterated);
    }
}
