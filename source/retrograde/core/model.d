/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.model;

import retrograde.core.math;

/** 
 * A data object containing a representation of a multi-dimensional geometric object
 * and its properties/metadata.
 */
class Model(Vector) {
    private const(Mesh!Vector)[] _meshes;

    this(const(Mesh!Vector)[] meshes...) {
        this._meshes = meshes;
    }

    const(Mesh!Vector)[] meshes() const {
        return _meshes;
    }
}

alias Model2D = Model!Vector2D;
alias Model3D = Model!Vector3D;
//TODO: All other vector types

/**
 * A data object containing a polygonal, geometric shape.
 *
 * The base class Mesh does not contain actual data; different kinds 
 * subclasses exist that store mesh data in particular ways.
 *
 * See_Also: VertexMesh
 */
interface Mesh(Vector) {

    /**
     * Iterates over each vertex of the mesh in a way that makes
     * sense for a specific kind of mesh, executing fn() for every
     * vertex.
     *
     * For example, for simple vertex meshes each vertex is iterated but
     * for an indexed-vertex each index item is iterated, not neccesarily each
     * vertex.
     *
     * Params: 
     *  fn = Delegate that is executed for each logical vertex.
     *  index = Linear, arbitrary index of the vector.
     *  Vertex = Vertex data.
     */
    void forEachVertex(void delegate(size_t index, Vector Vertex) fn) const;
}

/**
 * A Mesh that is made up of a continuous array of vertices.
 */
class VertexMesh(Vector) : Mesh!Vector {
    private const(Vector)[] _vertices;

    this(const(Vector)[] vertices...) {
        this._vertices = vertices;
    }

    const(Vector)[] vertices() const {
        return _vertices;
    }

    void forEachVertex(void delegate(size_t, Vector) fn) const {
        foreach (size_t i, const(Vector) vertex; _vertices) {
            fn(i, vertex);
        }
    }
}

alias VertexMesh3D = VertexMesh!Vector3D;
alias VertexMesh2D = VertexMesh!Vector2D;
//TODO: All other vector types

version (unittest) {
    @("Iterate over vertex meshes")
    unittest {
        auto vertices = [Vector3D(1, 0, 0), Vector3D(1, 1, 1)];
        const auto mesh = new VertexMesh3D(vertices);
        const auto model = new Model3D(mesh);
        bool hasIterated = false;

        model.meshes[0].forEachVertex((size_t index, Vector3D vec) {
            assert(vec == vertices[index]);
            hasIterated = true;
        });

        assert(hasIterated);
    }
}
