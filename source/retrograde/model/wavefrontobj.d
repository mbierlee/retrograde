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
 * - Faces (vertex position only, no normals/texture coords, triangulated only)
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
            auto sanitizedLine = strip(line);
            auto parts = sanitizedLine.split(" ");

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
                textureCoordinatesIndices ~= to!VertexIndex(index[0].strip) - 1;
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
