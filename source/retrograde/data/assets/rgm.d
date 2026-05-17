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

import retrograde.data.model : Model, Vertex, Face, Mesh, UvCoord, maxUvChannels;
import retrograde.data.assets.readercommon : readUInt, readUShort, readFloat;
import retrograde.std.endian : toPlatformEndian, Endian;
import retrograde.std.memory : ResultPtr, failedPtr, makeRaw, successPtr;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.result : Result, OperationResult, success, failure;

enum byte[] rgmMagicNumber = [0x52, 0x47, 0x4D, 0x20];
private enum size_t rgmHeaderSize = 10;

/**
 * Metadata for the 10-byte file-level header of an RGM model.
 */
struct ModelHeader {
    /// File format version (currently always 1).
    ushort formatVersion;
    /// Number of meshes contained in the file.
    uint meshCount;
}

/**
 * Parse and validate the 10-byte file-level header of an RGM model.
 *
 * Only the header bytes are inspected; the mesh sections are not read.
 *
 * Params:
 *   data = The raw RGM file bytes.
 * Returns:
 *   A successful `Result!ModelHeader` containing the parsed header, or a
 *   failure with a descriptive error message if the header is missing,
 *   malformed, or specifies an unsupported version.
 */
Result!ModelHeader loadModelHeader(const(ubyte)[] data) {
    if (data.length < rgmHeaderSize) {
        return failure!ModelHeader("Header is too small for a valid RGM file.");
    }

    if (data[0 .. 4] != rgmMagicNumber) {
        return failure!ModelHeader("Data is not a valid RGM file.");
    }

    if (data[4 .. 6] != [0x01, 0x00]) {
        return failure!ModelHeader("Unsupported RGM version.");
    }

    ModelHeader header;
    size_t offset = 4;
    header.formatVersion = readUShort(data, offset);
    offset = 6;
    header.meshCount = readUInt(data, offset);
    return success(header);
}

ResultPtr!Model loadModel(const(ubyte)[] data, StringId name = sid("unknown")) {
    auto headerResult = loadModelHeader(data);
    if (headerResult.isFailure()) {
        return failedPtr!Model(headerResult.errorMessage());
    }

    ModelHeader header = headerResult.value();
    Model* model = makeRaw!Model();
    model.name = name;

    size_t offset = rgmHeaderSize;
    for (uint i; i < header.meshCount; i++) {
        OperationResult result = readMeshData(data, offset, model);
        if (result.isFailure()) {
            return failedPtr!Model(result.errorMessage());
        }
    }

    if (offset != data.length) {
        return failedPtr!Model("RGM data contains unexpected trailing bytes.");
    }

    return successPtr(model);
}

private OperationResult readMeshData(const(ubyte)[] data, ref size_t offset, Model* model) {
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

    // Read UV channel count
    if (data.length - offset < 1) {
        return failure("Cannot read UV channel count: Unexpected end of data.");
    }

    ubyte uvChannelCount = data[offset];
    offset += 1;

    if (uvChannelCount > maxUvChannels) {
        return failure("Invalid UV channel count: exceeds maxUvChannels.");
    }

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

    // Read UV channel data
    if (uvChannelCount > 0) {
        OperationResult uvResult = readUvData(data, offset, mesh, uvChannelCount, vertexCount);
        if (uvResult.isFailure()) {
            return uvResult;
        }
    }

    model.meshes ~= mesh;
    return success();
}

private OperationResult readUvData(
    const(ubyte)[] data,
    ref size_t offset,
    ref Mesh mesh,
    ubyte uvChannelCount,
    uint vertexCount
) {
    size_t totalCoords = cast(size_t) uvChannelCount * vertexCount;
    size_t requiredBytes = totalCoords * 8;
    if (data.length - offset < requiredBytes) {
        return failure("Cannot read UV data: Unexpected end of data.");
    }

    mesh.uvCoords.capacity = totalCoords;
    for (size_t i = 0; i < totalCoords; i++) {
        float u = readFloat(data, offset);
        offset += 4;
        float v = readFloat(data, offset);
        offset += 4;
        mesh.uvCoords ~= UvCoord(u, v);
    }

    mesh.uvChannelCount = uvChannelCount;
    return success();
}

private OperationResult readVertexData(const(ubyte)[] data, ref size_t offset, ref Mesh mesh) {
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

private OperationResult readFaceData(const(ubyte)[] data, ref size_t offset, ref Mesh mesh) {
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

version (UnitTesting)  :  ///

void runRgmTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- RGM tests --");

    test("Load simple model containing a plane", {
        ubyte[139] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)

            // Mesh 1
            0x04, 0x00, 0x00, 0x00, // Vertex count (4)
            0x02, 0x00, 0x00, 0x00, // Face count (2)
            0x00, // UV channel count (0)

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
        assert(model.name == sid("unknown"));
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

        assert(model.meshes[0].uvChannelCount == 0);
        assert(model.meshes[0].uvCoords.length == 0);
    });

    test("Reject model with trailing bytes beyond expected data", {
        ubyte[140] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)

            // Mesh 1
            0x04, 0x00, 0x00, 0x00, // Vertex count (4)
            0x02, 0x00, 0x00, 0x00, // Face count (2)
            0x00, // UV channel count (0)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

            // Vertex 2
            0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00,

            // Vertex 3
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F,

            // Vertex 4
            0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x80, 0x3F,

            // Face 1
            0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,

            // Face 2
            0x01, 0x00, 0x00, 0x00, 0x03, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,

            // Trailing byte (unexpected)
            0xFF,
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Assign provided name to loaded model", {
        ubyte[103] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x00, // UV channel count (0)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

            // Vertex 2
            0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00,

            // Vertex 3
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F,

            // Face 1
            0x00, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x02, 0x00, 0x00, 0x00,
        ];

        auto result = loadModel(modelData, sid("my_model"));
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.name == sid("my_model"));
    });

    test("Load simple model with two UV channels", {
        ubyte[151] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x02, // UV channel count (2)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x00, 0x00, // Z (0.0)
            0x00, 0x00, 0x80, 0x3F, // R (1.0)
            0x00, 0x00, 0x00, 0x00, // G (0.0)
            0x00, 0x00, 0x00, 0x00, // B (0.0)

            // Vertex 2
            0x00, 0x00, 0x80, 0x3F, // X (1.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x00, 0x00, // Z (0.0)
            0x00, 0x00, 0x00, 0x00, // R (0.0)
            0x00, 0x00, 0x80, 0x3F, // G (1.0)
            0x00, 0x00, 0x00, 0x00, // B (0.0)

            // Vertex 3
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x80, 0x3F, // Y (1.0)
            0x00, 0x00, 0x00, 0x00, // Z (0.0)
            0x00, 0x00, 0x00, 0x00, // R (0.0)
            0x00, 0x00, 0x00, 0x00, // G (0.0)
            0x00, 0x00, 0x80, 0x3F, // B (1.0)

            // Face 1
            0x00, 0x00, 0x00, 0x00, // index 0
            0x01, 0x00, 0x00, 0x00, // index 1
            0x02, 0x00, 0x00, 0x00, // index 2

            // UV channel 0 (u, v per vertex)
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // (0.0, 0.0)
            0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00, // (1.0, 0.0)
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x80, 0x3F, // (0.0, 1.0)

            // UV channel 1 (u, v per vertex)
            0x00, 0x00, 0x00, 0x40, 0x00, 0x00, 0x00, 0x00, // (2.0, 0.0)
            0x00, 0x00, 0x40, 0x40, 0x00, 0x00, 0x00, 0x00, // (3.0, 0.0)
            0x00, 0x00, 0x80, 0x40, 0x00, 0x00, 0x00, 0x00, // (4.0, 0.0)
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.meshes.length == 1);
        assert(model.meshes[0].uvChannelCount == 2);
        assert(model.meshes[0].uvCoords.length == 6);

        // Channel 0
        assert(model.meshes[0].uvCoords[0].u == 0.0);
        assert(model.meshes[0].uvCoords[0].v == 0.0);
        assert(model.meshes[0].uvCoords[1].u == 1.0);
        assert(model.meshes[0].uvCoords[1].v == 0.0);
        assert(model.meshes[0].uvCoords[2].u == 0.0);
        assert(model.meshes[0].uvCoords[2].v == 1.0);

        // Channel 1
        assert(model.meshes[0].uvCoords[3].u == 2.0);
        assert(model.meshes[0].uvCoords[3].v == 0.0);
        assert(model.meshes[0].uvCoords[4].u == 3.0);
        assert(model.meshes[0].uvCoords[4].v == 0.0);
        assert(model.meshes[0].uvCoords[5].u == 4.0);
        assert(model.meshes[0].uvCoords[5].v == 0.0);
    });
}
