/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.data.assets.rgm;

import retrograde.data.model : Model, Vertex, Face, Mesh;
import retrograde.std.endian : toPlatformEndian, Endian;
import retrograde.std.memory : ResultPtr, failedPtr, makeRaw, successPtr;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.result : OperationResult, success, failure;

private enum byte[] rgmMagicNumber = [0x52, 0x47, 0x4D, 0x20];
private enum size_t rgmHeaderSize = 10;

ResultPtr!Model loadModel(ubyte[] data, StringId name = sid("unknown")) {
    // Check header size
    if (data.length < rgmHeaderSize) {
        return failedPtr!Model("Header is too small for a valid RGM file.");
    }

    // Check magic number
    if (data[0 .. 4] != rgmMagicNumber) {
        return failedPtr!Model("Data is not a valid RGM file.");
    }

    // Check version
    if (data[4 .. 6] != [0x01, 0x00]) {
        return failedPtr!Model("Unsupported RGM version.");
    }

    Model* model = makeRaw!Model();

    uint meshCount = toPlatformEndian!uint(data[6 .. 10], Endian.little);
    size_t offset = rgmHeaderSize;
    for (uint i; i < meshCount; i++) {
        OperationResult result = readMeshData(data, offset, model);
        if (result.isFailure()) {
            return failedPtr!Model(result.errorMessage());
        }
    }

    return successPtr(model);
}

private OperationResult readMeshData(ubyte[] data, ref size_t offset, Model* model) {
    Mesh mesh = Mesh();

    // Read vertex count
    if (data.length - offset < 4) {
        return failure("Cannot read vertex count: Unexpected end of data.");
    }

    uint vertexCount = readUInt(data, offset);
    offset += 4;

    // Read face count
    if (data.length - offset < 4) {
        return failure("Cannot read face count: Unexpected end of data.");
    }

    uint faceCount = readUInt(data, offset);
    offset += 4;

    // Read vertices
    for (uint i; i < vertexCount; i++) {
        OperationResult result = readVertexData(data, offset, mesh);
        if (result.isFailure()) {
            return result;
        }
    }

    // Read faces
    for (uint i; i < faceCount; i++) {
        OperationResult result = readFaceData(data, offset, mesh);
        if (result.isFailure()) {
            return result;
        }
    }

    model.meshes ~= mesh;
    return success();
}

private OperationResult readVertexData(ubyte[] data, ref size_t offset, ref Mesh mesh) {
    // Read X coordinate
    if (data.length - offset < 4) {
        return failure("Cannot read X coordinate: Unexpected end of data.");
    }

    float x = readFloat(data, offset);
    offset += 4;

    // Read Y coordinate
    if (data.length - offset < 4) {
        return failure("Cannot read Y coordinate: Unexpected end of data.");
    }

    float y = readFloat(data, offset);
    offset += 4;

    // Read Z coordinate
    if (data.length - offset < 4) {
        return failure("Cannot read Z coordinate: Unexpected end of data.");
    }

    float z = readFloat(data, offset);
    offset += 4;

    // Read R color
    if (data.length - offset < 4) {
        return failure("Cannot read R color: Unexpected end of data.");
    }

    float r = readFloat(data, offset);
    offset += 4;

    // Read G color
    if (data.length - offset < 4) {
        return failure("Cannot read G color: Unexpected end of data.");
    }

    float g = readFloat(data, offset);
    offset += 4;

    // Read B color
    if (data.length - offset < 4) {
        return failure("Cannot read B color: Unexpected end of data.");
    }

    float b = readFloat(data, offset);
    offset += 4;

    mesh.vertices ~= Vertex(x, y, z, 1, r, g, b, 1);
    return success();
}

private OperationResult readFaceData(ubyte[] data, ref size_t offset, ref Mesh mesh) {
    // Read vertex index 1
    if (data.length - offset < 4) {
        return failure("Cannot read vertex index 1: Unexpected end of data.");
    }

    uint vertexIndex1 = readUInt(data, offset);
    offset += 4;

    // Read vertex index 2
    if (data.length - offset < 4) {
        return failure("Cannot read vertex index 2: Unexpected end of data.");
    }

    uint vertexIndex2 = readUInt(data, offset);
    offset += 4;

    // Read vertex index 3
    if (data.length - offset < 4) {
        return failure("Cannot read vertex index 3: Unexpected end of data.");
    }

    uint vertexIndex3 = readUInt(data, offset);
    offset += 4;

    mesh.faces ~= Face(vertexIndex1, vertexIndex2, vertexIndex3);
    return success();
}

private uint readUInt(ubyte[] data, ref size_t offset) {
    ubyte[4] bytes = data[offset .. offset + 4];
    return toPlatformEndian!uint(bytes, Endian.little);
}

private float readFloat(ubyte[] data, ref size_t offset) {
    ubyte[4] bytes = data[offset .. offset + 4];
    return toPlatformEndian!float(bytes, Endian.little);
}

version (UnitTesting)  :  ///

void runRgmTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- RGM tests --");

    test("Load simple model containing a plane", {
        ubyte[138] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)

            // Mesh 1
            0x04, 0x00, 0x00, 0x00, // Vertex count (4)
            0x02, 0x00, 0x00, 0x00, // Face count (2)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, // X coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Y coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x00, 0x00, // G color (0.0)
            0x00, 0x00, 0x00, 0x00, // B color (0.0)

            // Vertex 2
            0x00, 0x00, 0x80, 0x3F, // X coordinate (1.0)
            0x00, 0x00, 0x00, 0x00, // Y coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // R color (0.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x00, 0x00, // B color (0.0)

            // Vertex 3
            0x00, 0x00, 0x00, 0x00, // X coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // Y coordinate (1.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // R color (0.0)
            0x00, 0x00, 0x00, 0x00, // G color (0.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Vertex 4
            0x00, 0x00, 0x80, 0x3F, // X coordinate (1.0)
            0x00, 0x00, 0x80, 0x3F, // Y coordinate (1.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Face 1
            0x00, 0x00, 0x00, 0x00, // Vertex index 1 (0)
            0x01, 0x00, 0x00, 0x00, // Vertex index 2 (1)
            0x02, 0x00, 0x00, 0x00, // Vertex index 3 (2)

            // Face 2
            0x01, 0x00, 0x00, 0x00, // Vertex index 1 (1)
            0x03, 0x00, 0x00, 0x00, // Vertex index 2 (3)
            0x02, 0x00, 0x00, 0x00, // Vertex index 3 (2)
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.meshes.length == 1);
        assert(model.meshes[0].vertices.length == 4);
        assert(model.meshes[0].vertices[0].x == 0.0);
        assert(model.meshes[0].vertices[0].y == 0.0);
        assert(model.meshes[0].vertices[0].z == 0.0);
        assert(model.meshes[0].vertices[0].r == 1.0);
        assert(model.meshes[0].vertices[0].g == 0.0);
        assert(model.meshes[0].vertices[0].b == 0.0);

        assert(model.meshes[0].vertices[1].x == 1.0);
        assert(model.meshes[0].vertices[1].y == 0.0);
        assert(model.meshes[0].vertices[1].z == 0.0);
        assert(model.meshes[0].vertices[1].r == 0.0);
        assert(model.meshes[0].vertices[1].g == 1.0);
        assert(model.meshes[0].vertices[1].b == 0.0);

        assert(model.meshes[0].vertices[2].x == 0.0);
        assert(model.meshes[0].vertices[2].y == 1.0);
        assert(model.meshes[0].vertices[2].z == 0.0);
        assert(model.meshes[0].vertices[2].r == 0.0);
        assert(model.meshes[0].vertices[2].g == 0.0);
        assert(model.meshes[0].vertices[2].b == 1.0);

        assert(model.meshes[0].vertices[3].x == 1.0);
        assert(model.meshes[0].vertices[3].y == 1.0);
        assert(model.meshes[0].vertices[3].z == 0.0);
        assert(model.meshes[0].vertices[3].r == 1.0);
        assert(model.meshes[0].vertices[3].g == 1.0);
        assert(model.meshes[0].vertices[3].b == 1.0);

        assert(model.meshes[0].faces.length == 2);

        assert(model.meshes[0].faces[0].vA == 0);
        assert(model.meshes[0].faces[0].vB == 1);
        assert(model.meshes[0].faces[0].vC == 2);

        assert(model.meshes[0].faces[1].vA == 1);
        assert(model.meshes[0].faces[1].vB == 3);
        assert(model.meshes[0].faces[1].vC == 2);
    });
}
