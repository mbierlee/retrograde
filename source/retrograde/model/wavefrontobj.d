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

module retrograde.model.wavefrontobj;

import retrograde.core.model : Mesh, Model, Vertex, VertexIndex, Face;
import retrograde.core.storage : File;
import retrograde.core.math : Vector3D;

import std.string : lineSplitter, strip;
import std.array : split;
import std.conv : to;

class ParseState {
    Mesh[] meshes;
    bool isProcessingObject = false;

    Vertex[] vertices;
    Face[] faces;
}

/**
 * A model parser for Wavefront .obj files.
 *
 * Currently supports:
 * - Vertices
 * - Faces (vertex position only, no normals/texture coords, triangulated only)
 */
class WavefrontObjParser {
    Model parse(File modelFile) {
        auto lines = modelFile.textData.lineSplitter();
        auto state = new ParseState();

        foreach (string line; lines) {
            auto sanitizedLine = strip(line);
            auto parts = sanitizedLine.split(" ");

            if (parts.length == 0)
                continue;

            auto objectType = parts[0];

            switch (objectType) {
            case "o":
                createNewObject(state);
                break;

            case "v":
                addVertex(state, parts[1 .. $]);
                break;

            case "f":
                addFace(state, parts[1 .. $]);
                break;

            default:
                break;
            }
        }

        createNewObject(state);
        auto model = new Model(state.meshes);
        return model;
    }

    private void createNewObject(ParseState state) {
        if (state.isProcessingObject) {
            auto mesh = new Mesh(state.vertices, state.faces);
            state.meshes ~= mesh;

            state.vertices.destroy();
            state.faces.destroy();
        } else {
            state.isProcessingObject = true;
        }
    }

    private void addVertex(ParseState state, string[] parts) {
        if (parts.length >= 3) {
            auto vector = Vector3D(to!double(parts[0]), to!double(parts[1]), to!double(parts[2]));
            state.vertices ~= vector;
        }
    }

    private void addFace(ParseState state, string[] parts) {
        if (parts.length >= 3) {
            VertexIndex[] indices;
            foreach (string part; parts) {
                auto index = part.split("/");
                auto vertexIndex = to!VertexIndex(strip(index[0])) - 1;
                indices ~= vertexIndex;
            }

            if (indices.length == 3) {
                state.faces ~= Face(indices[0], indices[1], indices[2]);
            }
        }
    }
}

version (unittest) {
    @("Parse model file")
    unittest {
        string modelData = "
            # Example model file
            mtllib cube.mtl
            o Cube
            v 1.000000 1.000000 -1.000000
            v 1.000000 -1.000000 -1.000000
            v 1.000000 1.000000 1.000000
            v 1.000000 -1.000000 1.000000
            v -1.000000 1.000000 -1.000000
            v -1.000000 -1.000000 -1.000000
            v -1.000000 1.000000 1.000000
            v -1.000000 -1.000000 1.000000
            vn 0.0000 1.0000 0.0000
            vn 0.0000 0.0000 1.0000
            vn -1.0000 0.0000 0.0000
            vn 0.0000 -1.0000 0.0000
            vn 1.0000 0.0000 0.0000
            vn 0.0000 0.0000 -1.0000
            usemtl None
            s off
            f 5//1 3//1 1//1
            f 3//2 8//2 4//2
            f 7//3 6//3 8//3
            f 2//4 8//4 6//4
            f 1//5 4//5 2//5
            f 5//6 2//6 6//6
            f 5//1 7//1 3//1
            f 3//2 7//2 8//2
            f 7//3 5//3 6//3
            f 2//4 4//4 8//4
            f 1//5 3//5 4//5
            f 5//6 1//6 2//6
        ";

        auto modelFile = new File("cube.obj", modelData);
        auto parser = new WavefrontObjParser();
        auto model = parser.parse(modelFile);

        assert(model.meshes.length == 1);

        auto expectedVertices = [
            Vertex(1.000000, 1.000000, -1.000000),
            Vertex(1.000000, -1.000000, -1.000000),
            Vertex(1.000000, 1.000000, 1.000000),
            Vertex(1.000000, -1.000000, 1.000000),
            Vertex(-1.000000, 1.000000, -1.000000),
            Vertex(-1.000000, -1.000000, -1.000000),
            Vertex(-1.000000, 1.000000, 1.000000),
            Vertex(-1.000000, -1.000000, 1.000000)
        ];

        auto mesh = model.meshes[0];

        assert(mesh.vertices == expectedVertices);

        auto expectedFaces = [
            Face(4, 2, 0),
            Face(2, 7, 3),
            Face(6, 5, 7),
            Face(1, 7, 5),
            Face(0, 3, 1),
            Face(4, 1, 5),
            Face(4, 6, 2),
            Face(2, 6, 7),
            Face(6, 4, 5),
            Face(1, 3, 7),
            Face(0, 2, 3),
            Face(4, 0, 1)
        ];

        assert(mesh.faces == expectedFaces);
    }
}