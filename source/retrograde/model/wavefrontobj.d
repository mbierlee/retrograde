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

import retrograde.core.model : Mesh, Model, Vertex, VertexIndex, TextureCoordinateIndex, Face, ModelParseException,
    TextureCoordinate;
import retrograde.core.storage : File;
import retrograde.core.math : Vector3D;

import std.string : lineSplitter, strip;
import std.array : split;
import std.conv : to;
import std.exception : enforce, assertThrown;

private class ParseState {
    Mesh[] meshes;
    bool isProcessingObject = false;

    Vertex[] vertices;
    Face[] faces;
    TextureCoordinate[] textureCoordinates;
}

/**
 * A model parser for Wavefront .obj files.
 *
 * Currently supports:
 * - Vertices
 * - Faces (vertex position and texture coords, no normals, triangulated only)
 */
class WavefrontObjParser {
    /** 
     * Parse an OBJ model file
     *
     * Throws: ModelParseException when model is syntactically incorrect or elements are not supported by parser.
     */
    Model parse(File modelFile) {
        auto lines = modelFile.textData.lineSplitter();
        auto state = new ParseState();

        foreach (string line; lines) {
            auto parts = line.strip.split(" ");

            if (parts.length == 0) {
                continue;
            }

            auto objectType = parts[0];

            switch (objectType) {
            case "o":
                createNewObject(state);
                break;

            case "v":
                addVertex(state, parts[1 .. $]);
                break;

            case "vt":
                addTextureCoordinate(state, parts[1 .. $]);
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
            auto mesh = new Mesh(state.vertices, state.faces, state.textureCoordinates);
            state.meshes ~= mesh;

            state.vertices.destroy();
            state.faces.destroy();
            state.textureCoordinates.destroy();
        } else {
            state.isProcessingObject = true;
        }
    }

    private void addVertex(ParseState state, string[] parts) {
        if (parts.length >= 3) {
            auto vertex = Vertex(to!double(parts[0]), to!double(parts[1]), to!double(parts[2]), 1, 1, 1, 1, 1, 0, 0, 0);
            state.vertices ~= vertex;
        }
    }

    private void addTextureCoordinate(ParseState state, string[] parts) {
        if (parts.length >= 2) {
            auto textureCoordinate = TextureCoordinate(to!double(parts[0]), to!double(parts[1]));
            state.textureCoordinates ~= textureCoordinate;
        }
    }

    private void addFace(ParseState state, string[] parts) {
        enforce!ModelParseException(parts.length == 3, "Only triangulated faces are supported. Quads and N-poly faces must be converted to triangles.");

        VertexIndex[] vertexIndices;
        TextureCoordinateIndex[] textureCoordinatesIndices;
        foreach (string part; parts) {
            auto index = part.split("/");
            vertexIndices ~= to!VertexIndex(index[0].strip) - 1;

            if (index.length >= 2 && index[1].strip.length > 0) {
                textureCoordinatesIndices ~= to!VertexIndex(index[1].strip) - 1;
            } else {
                textureCoordinatesIndices ~= 0;
            }
        }

        if (vertexIndices.length == 3) {
            state.faces ~= Face(
                vertexIndices[0],
                vertexIndices[1],
                vertexIndices[2],
                textureCoordinatesIndices[0],
                textureCoordinatesIndices[1],
                textureCoordinatesIndices[2]
            );
        }
    }
}

version (unittest) {
    @("Parse model file")
    unittest {
        string modelData = "
            # Example model file
            o Cube
            v 1.000000 1.000000 -1.000000
            v 1.000000 -1.000000 -1.000000
            v 1.000000 1.000000 1.000000
            v 1.000000 -1.000000 1.000000
            v -1.000000 1.000000 -1.000000
            v -1.000000 -1.000000 -1.000000
            v -1.000000 1.000000 1.000000
            v -1.000000 -1.000000 1.000000
            vt 0.000000 0.000000
            vt 1.000000 0.000000
            vt 1.000000 1.000000
            vt 0.000000 0.000000
            vt 1.000000 0.000000
            vt 0.000000 1.000000
            vt 0.000000 1.000000
            vt 1.000000 0.000000
            vt 1.000000 1.000000
            vt 0.000000 0.000000
            vt 1.000000 1.000000
            vt 0.000000 1.000000
            vt 1.000000 1.000000
            vt 1.000000 0.000000
            vt 0.000000 0.000000
            vt 0.000000 1.000000
            vt 1.000000 1.000000
            vt 1.000000 0.000000
            vt 0.000000 0.000000
            vt 0.000000 1.000000
            s 0
            f 5/14 3/7 1/1
            f 3/8 8/20 4/10
            f 7/18 6/16 8/19
            f 2/5 8/20 6/15
            f 1/2 4/12 2/4
            f 5/14 2/6 6/15
            f 5/14 7/17 3/7
            f 3/8 7/17 8/20
            f 7/18 5/13 6/16
            f 2/5 4/11 8/20
            f 1/2 3/9 4/12
            f 5/14 1/3 2/6
        ";

        auto modelFile = new File("cube.obj", modelData);
        auto parser = new WavefrontObjParser();
        auto model = parser.parse(modelFile);

        assert(model.meshes.length == 1);

        auto expectedVertices = [
            Vertex(1.000000, 1.000000, -1.000000, 1, 1, 1, 1, 1, 0, 0, 0),
            Vertex(1.000000, -1.000000, -1.000000, 1, 1, 1, 1, 1, 0, 0, 0),
            Vertex(1.000000, 1.000000, 1.000000, 1, 1, 1, 1, 1, 0, 0, 0),
            Vertex(1.000000, -1.000000, 1.000000, 1, 1, 1, 1, 1, 0, 0, 0),
            Vertex(-1.000000, 1.000000, -1.000000, 1, 1, 1, 1, 1, 0, 0, 0),
            Vertex(-1.000000, -1.000000, -1.000000, 1, 1, 1, 1, 1, 0, 0, 0),
            Vertex(-1.000000, 1.000000, 1.000000, 1, 1, 1, 1, 1, 0, 0, 0),
            Vertex(-1.000000, -1.000000, 1.000000, 1, 1, 1, 1, 1, 0, 0, 0)
        ];

        auto mesh = model.meshes[0];

        assert(mesh.vertices == expectedVertices);

        auto expectedFaces = [
            Face(4, 2, 0, 13, 6, 0),
            Face(2, 7, 3, 7, 19, 9),
            Face(6, 5, 7, 17, 15, 18),
            Face(1, 7, 5, 4, 19, 14),
            Face(0, 3, 1, 1, 11, 3),
            Face(4, 1, 5, 13, 5, 14),
            Face(4, 6, 2, 13, 16, 6),
            Face(2, 6, 7, 7, 16, 19),
            Face(6, 4, 5, 17, 12, 15),
            Face(1, 3, 7, 4, 10, 19),
            Face(0, 2, 3, 1, 8, 11),
            Face(4, 0, 1, 13, 2, 5)
        ];

        assert(mesh.faces == expectedFaces);
    }

    @("Exception is thrown when model doesn't have polygonal faces")
    unittest {
        string modelData = "
            # Example model file
            mtllib cube.mtl
            o Cube
            v -1.000000 -1.000000 1.000000
            usemtl None
            s off
            f 5//6 1//6 2//6 2//6
        ";

        auto modelFile = new File("cube.obj", modelData);
        auto parser = new WavefrontObjParser();
        assertThrown!ModelParseException(parser.parse(modelFile));
    }
}
