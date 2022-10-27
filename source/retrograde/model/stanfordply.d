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

module retrograde.model.stanfordply;

import retrograde.core.storage : File;
import retrograde.core.model : Model, Vertex, Mesh, Face, VertexComponent, VertexIndex, ModelParseException;

import std.exception : enforce, assertThrown;
import std.string : lineSplitter, strip, startsWith;
import std.array : split;
import std.conv : to;

private enum Section {
    magicNumber,
    header,
    vertices,
    faces
}

private enum Element {
    vertex,
    face
}

private class ParseState {
    Mesh[] meshes;
    Vertex[] vertices;
    Face[] faces;
    bool breakParsing = false;
    bool encounteredFormat = false;
    Section section = Section.magicNumber;
    Element element = Element.vertex;
    uint vertexCount = 0;
    uint faceCount = 0;
    size_t[string] vertexPropertyLocations;
    string[string] vertexPropertyType;
}

/**
 * A model parser for Stanford .ply files.
 *
 * Currently supports:
 * - Vertices
 * - Faces (vertex position only, no normals/texture coords, triangulated only)
 */
class StanfordPlyParser {

    /** 
     * Parse a PLY model file
     *
     * Throws: ModelParseException when model is syntactically incorrect or elements are not supported by parser.
     */
    Model parse(File modelFile) {
        auto lines = modelFile.textData.lineSplitter();
        auto state = new ParseState();

        foreach (line; lines) {
            if (state.breakParsing) {
                break;
            }

            auto sanitizedLine = strip(line);

            if (sanitizedLine.length == 0) {
                continue;
            }

            if (state.section == Section.magicNumber) {
                enforce!ModelParseException(sanitizedLine.startsWith("ply"), "Model file is not a ply model (doesn't start with ply header)");
                state.section = Section.header;
            }

            auto parts = sanitizedLine.split(" ");
            if (parts.length == 0) {
                continue;
            }

            if (state.section == Section.header) {
                parseHeader(parts, state);
            } else if (state.section == Section.vertices) {
                parseVertex(parts, state);

                if (state.vertices.length == state.vertexCount) {
                    state.section = Section.faces;
                }
            } else if (state.section == Section.faces) {
                parseFace(parts, state);

                if (state.faces.length == state.faceCount) {
                    state.breakParsing = true;
                    break;
                }
            }
        }

        return new Model([
                new Mesh(state.vertices, state.faces)
            ]);
    }

    private void parseHeader(string[] parts, ParseState state) {
        auto headerType = parts[0];
        switch (headerType) {
        case "format":
            enforce!ModelParseException(parts[1] == "ascii", "Only ASCII format is supported");
            enforce!ModelParseException(parts[2] == "1.0", "Only ASCII format version 1.0 is supported");
            state.encounteredFormat = true;
            break;

        case "end_header":
            if (!state.encounteredFormat) {
                // Break parsing to not accidentaly read garbage binary data.
                state.breakParsing = true;
            }

            state.section = Section.vertices;
            break;

        case "element":
            auto elementType = parts[1];
            if (elementType == "vertex") {
                state.vertexCount = to!uint(parts[2]);
                state.element = Element.vertex;
            } else if (elementType == "face") {
                state.faceCount = to!uint(parts[2]);
                state.element = Element.face;
            }
            break;

        case "property":
            if (state.element == Element.vertex) {
                auto vertexPropertyType = parts[1];
                auto propertyName = parts[2];
                state.vertexPropertyLocations[propertyName] = state.vertexPropertyLocations.length;
                state.vertexPropertyType[propertyName] = vertexPropertyType;
            }
            break;

        default:
            break;
        }
    }

    private void parseVertex(string[] parts, ParseState state) {
        auto x = getComponent("x", parts, state);
        auto y = getComponent("y", parts, state);
        auto z = getComponent("z", parts, state);

        auto r = getComponent("red", parts, state);
        auto g = getComponent("green", parts, state);
        auto b = getComponent("blue", parts, state);
        auto a = getComponent("alpha", parts, state);

        auto u = getComponent("s", parts, state);
        auto v = getComponent("t", parts, state);

        state.vertices ~= Vertex(x, y, z, 1, r, g, b, a, u, v, 0);
    }

    private void parseFace(string[] parts, ParseState state) {
        // The following face format is assumed:
        // property list uchar uint vertex_indices
        // Because it is the most common.
        // TODO: Make flexible too

        auto verticesInFace = to!uint(parts[0]);
        enforce!ModelParseException(verticesInFace == 3, "Only triangulated faces are supported. Quads and N-poly faces must be converted to triangles.");

        auto a = to!VertexIndex(parts[1]);
        auto b = to!VertexIndex(parts[2]);
        auto c = to!VertexIndex(parts[3]);
        state.faces ~= Face(a, b, c);
    }

    private VertexComponent getComponent(string name, string[] parts, ParseState state) {
        auto vertexPropertyType = name in state.vertexPropertyType;
        if (vertexPropertyType) {
            if ((*vertexPropertyType).startsWith("float") || (*vertexPropertyType) == "double") {
                return to!VertexComponent(parts[state.vertexPropertyLocations[name]]);
            } else if ((*vertexPropertyType) == "uchar") {
                return to!ubyte(parts[state.vertexPropertyLocations[name]]) / 255.0;
            } else {
                throw new ModelParseException(
                    "Data type '" ~ *vertexPropertyType ~ "' not supported.");
            }
        } else {
            return 1;
        }
    }
}

version (unittest) {
    import std.math.operations : isClose;

    @("Parse model file")
    unittest {
        string modelData = "
            ply
            format ascii 1.0
            comment Created by Blender 3.0.1 - www.blender.org
            element vertex 8
            property float x
            property float y
            property float z
            property float nx
            property float ny
            property float nz
            property uchar red
            property uchar green
            property uchar blue
            property uchar alpha
            property float s
            property float t
            element face 12
            property list uchar uint vertex_indices
            end_header
            1.000000 1.000000 1.000000 0.577349 0.577349 0.577349 128 183 255 255 1.000000 0.000000
            -1.000000 1.000000 -1.000000 -0.577349 0.577349 -0.577349 255 89 86 255 1.000000 0.000000
            -1.000000 1.000000 1.000000 -0.577349 0.577349 0.577349 252 255 210 255 1.000000 0.000000
            1.000000 -1.000000 -1.000000 0.577349 -0.577349 -0.577349 251 255 182 255 1.000000 0.000000
            -1.000000 -1.000000 -1.000000 -0.577349 -0.577349 -0.577349 143 255 156 255 0.000000 1.000000
            1.000000 1.000000 -1.000000 0.577349 0.577349 -0.577349 143 255 156 255 0.000000 1.000000
            1.000000 -1.000000 1.000000 0.577349 -0.577349 0.577349 255 88 92 255 0.000000 1.000000
            -1.000000 -1.000000 1.000000 -0.577349 -0.577349 0.577349 137 187 255 255 0.000000 1.000000
            3 0 1 2
            3 1 3 4
            3 5 6 3
            3 7 3 6
            3 2 4 7
            3 0 7 6
            3 0 5 1
            3 1 5 3
            3 5 0 6
            3 7 4 3
            3 2 1 4
            3 0 2 7
        ";

        auto modelFile = new File("cube.ply", modelData);
        auto parser = new StanfordPlyParser();
        auto model = parser.parse(modelFile);
        auto mesh = model.meshes[0];

        auto expectedVertices = [
            Vertex(1.000000, 1.000000, 1.000000, 1, 0.501961, 0.717647, 1, 1, 1.000000, 0, 0),
            Vertex(-1.000000, 1.000000, -1.000000, 1, 1, 0.34902, 0.337255, 1, 1.000000, 0, 0),
            Vertex(-1.000000, 1.000000, 1.000000, 1, 0.988235, 1, 0.823529, 1, 1.000000, 0, 0),
            Vertex(1.000000, -1.000000, -1.000000, 1, 0.984314, 1, 0.713725, 1, 1.000000, 0, 0),
            Vertex(-1.000000, -1.000000, -1.000000, 1, 0.560784, 1, 0.611765, 1, 0, 1.000000, 0),
            Vertex(1.000000, 1.000000, -1.000000, 1, 0.560784, 1, 0.611765, 1, 0, 1.000000, 0),
            Vertex(1.000000, -1.000000, 1.000000, 1, 1, 0.345098, 0.360784, 1, 0, 1.000000, 0),
            Vertex(-1.000000, -1.000000, 1.000000, 1, 0.537255, 0.733333, 1, 1, 0, 1.000000, 0)
        ];

        import std.stdio;

        foreach (index, vertex; mesh.vertices) {
            assert(isClose(vertex.x, expectedVertices[index].x, 1e-3));
            assert(isClose(vertex.y, expectedVertices[index].y, 1e-3));
            assert(isClose(vertex.z, expectedVertices[index].z, 1e-3));
            assert(isClose(vertex.w, expectedVertices[index].w, 1e-3));
            assert(isClose(vertex.r, expectedVertices[index].r, 1e-3));
            assert(isClose(vertex.g, expectedVertices[index].g, 1e-3));
            assert(isClose(vertex.b, expectedVertices[index].b, 1e-3));
            assert(isClose(vertex.a, expectedVertices[index].a, 1e-3));
            assert(isClose(vertex.u, expectedVertices[index].u, 1e-3));
            assert(isClose(vertex.v, expectedVertices[index].v, 1e-3));
            assert(isClose(vertex.tw, expectedVertices[index].tw, 1e-3));
        }

        auto expectedFaces = [
            Face(0, 1, 2),
            Face(1, 3, 4),
            Face(5, 6, 3),
            Face(7, 3, 6),
            Face(2, 4, 7),
            Face(0, 7, 6),
            Face(0, 5, 1),
            Face(1, 5, 3),
            Face(5, 0, 6),
            Face(7, 4, 3),
            Face(2, 1, 4),
            Face(0, 2, 7)
        ];

        assert(mesh.faces == expectedFaces);
    }

    @("Exception is thrown when model is not a ply model")
    unittest {
        string modelData = "
            notply
        ";

        auto modelFile = new File("cube.ply", modelData);
        auto parser = new StanfordPlyParser();
        assertThrown!ModelParseException(parser.parse(modelFile));
    }

    @("Exception is thrown when model is not using ASCII format")
    unittest {
        string modelData = "
            ply
            format binary_big_endian 1.0
        ";

        auto modelFile = new File("cube.ply", modelData);
        auto parser = new StanfordPlyParser();
        assertThrown!ModelParseException(parser.parse(modelFile));
    }

    @("Exception is thrown when model is not using ASCII format version 1.0")
    unittest {
        string modelData = "
            ply
            format ascii 987.0
        ";

        auto modelFile = new File("cube.ply", modelData);
        auto parser = new StanfordPlyParser();
        assertThrown!ModelParseException(parser.parse(modelFile));
    }

    @("Exception is thrown when model doesn't have polygonal faces")
    unittest {
        string modelData = "
            ply
            format ascii 1.0
            element vertex 1
            property float x
            property float y
            property float z
            property float nx
            property float ny
            property float nz
            property uchar red
            property uchar green
            property uchar blue
            property uchar alpha
            element face 1
            property list uchar uint vertex_indices
            end_header
            -1.000000 -1.000000 1.000000 -0.577349 -0.577349 0.577349 137 187 255 255
            4 0 0 0 0
        ";

        auto modelFile = new File("cube.ply", modelData);
        auto parser = new StanfordPlyParser();
        assertThrown!ModelParseException(parser.parse(modelFile));
    }
}
