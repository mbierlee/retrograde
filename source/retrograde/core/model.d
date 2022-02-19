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

import retrograde.core.math : Vector3D;

alias Vertex = Vector3D;

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
 * A mesh that is made up of a list of vertices and an index
 * pointing to those vertices.
 */
class Mesh {
    private const(size_t)[] _indices;
    private const(Vertex)[] _vertices;

    this(const(size_t)[] indices, const(Vertex)[] vertices...) {
        this._indices = indices;
        this._vertices = vertices;
    }

    const(size_t)[] indices() const {
        return _indices;
    }

    const(Vertex)[] vertices() const {
        return _vertices;
    }

    void forEachVertex(void delegate(size_t, Vertex) fn) const {
        foreach (size_t i, const(size_t) index; _indices) {
            fn(i, _vertices[index]);
        }
    }
}

version (unittest) {
    @("Iterate over meshes")
    unittest {
        size_t[] indices = [1, 0, 0];
        auto vertices = [Vertex(1, 0, 0), Vertex(1, 1, 1)];
        const auto mesh = new Mesh(indices, vertices);
        const auto model = new Model([mesh]);
        bool hasIterated = false;

        auto expectedVertices = [
            Vertex(1, 1, 1),
            Vertex(1, 0, 0),
            Vertex(1, 0, 0)
        ];

        model.meshes[0].forEachVertex((size_t index, Vertex vec) {
            assert(vec == expectedVertices[index]);
            hasIterated = true;
        });

        assert(mesh.vertices.length == 2);
        assert(mesh.indices.length == 3);
        assert(hasIterated);
    }
}
