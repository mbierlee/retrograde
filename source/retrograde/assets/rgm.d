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

module retrograde.assets.rgm;

import retrograde.assets.model : Model, Vertex, Face, Mesh, UvCoord, Normal, Tangent,
    maxUvChannels, MeshAttributeFlags, Material, MaterialIndex, MaterialType, MaterialFlags,
    noMaterial, referencesTexture, referencesNormalTexture, Texture, TextureIndex, TextureType,
    TextureMagFilter, TextureMinFilter, TextureWrap;
import retrograde.assets.readercommon : readUInt, readUShort, readFloat;
import retrograde.std.endian : toPlatformEndian, Endian;
import retrograde.std.memory : ResultPtr, failedPtr, makeRaw, successPtr;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.string : String;
import retrograde.std.result : Result, OperationResult, success, failure;

enum byte[] rgmMagicNumber = [0x52, 0x47, 0x4D, 0x20];
private enum size_t rgmHeaderSize = 18;

/**
 * Metadata for the file-level header of an RGM model.
 */
struct ModelHeader {
    /// File format version (currently always 1).
    ushort formatVersion;
    /// Number of meshes contained in the file.
    uint meshCount;
    /// Number of materials contained in the file.
    uint materialCount;
    /// Number of textures contained in the file.
    uint textureCount;
}

/**
 * Parse and validate the 18-byte file-level header of an RGM model.
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
    offset = 10;
    header.materialCount = readUInt(data, offset);
    offset = 14;
    header.textureCount = readUInt(data, offset);
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

    for (uint i; i < header.materialCount; i++) {
        OperationResult result = readMaterialData(data, offset, model);
        if (result.isFailure()) {
            return failedPtr!Model(result.errorMessage());
        }
    }

    for (uint i; i < header.textureCount; i++) {
        OperationResult result = readTextureData(data, offset, model);
        if (result.isFailure()) {
            return failedPtr!Model(result.errorMessage());
        }
    }

    OperationResult meshMaterialCrossCheck = validateMeshMaterialReferences(model);
    if (meshMaterialCrossCheck.isFailure()) {
        return failedPtr!Model(meshMaterialCrossCheck.errorMessage());
    }

    OperationResult textureCrossCheck = validateMaterialTextureReferences(model);
    if (textureCrossCheck.isFailure()) {
        return failedPtr!Model(textureCrossCheck.errorMessage());
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

    // Read attribute flags
    if (data.length - offset < 1) {
        return failure("Cannot read attribute flags: Unexpected end of data.");
    }

    ubyte attributeFlags = data[offset];
    offset += 1;

    enum ubyte knownAttributeFlags = MeshAttributeFlags.normals | MeshAttributeFlags.tangents;
    if ((attributeFlags & ~knownAttributeFlags) != 0) {
        return failure("Invalid attribute flags: reserved bits are set.");
    }

    bool hasNormals = (attributeFlags & MeshAttributeFlags.normals) != 0;
    bool hasTangents = (attributeFlags & MeshAttributeFlags.tangents) != 0;

    // A tangent is only meaningful alongside the normal it is orthogonal to, and
    // it describes the gradient of the first UV channel, so both must be present.
    if (hasTangents && !hasNormals) {
        return failure("Invalid attribute flags: tangents require normals.");
    }

    if (hasTangents && uvChannelCount == 0) {
        return failure("Invalid attribute flags: tangents require at least one UV channel.");
    }

    // Read material index
    if (data.length - offset < 4) {
        return failure("Cannot read material index: Unexpected end of data.");
    }

    MaterialIndex materialIndex = readUInt(data, offset);
    offset += 4;
    mesh.materialIndex = materialIndex;

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

    // Read normal data
    if (hasNormals) {
        OperationResult normalResult = readNormalData(data, offset, mesh, vertexCount);
        if (normalResult.isFailure()) {
            return normalResult;
        }
    }

    // Read tangent data
    if (hasTangents) {
        OperationResult tangentResult = readTangentData(data, offset, mesh, vertexCount);
        if (tangentResult.isFailure()) {
            return tangentResult;
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

private OperationResult readNormalData(
    const(ubyte)[] data,
    ref size_t offset,
    ref Mesh mesh,
    uint vertexCount
) {
    size_t requiredBytes = cast(size_t) vertexCount * 12;
    if (data.length - offset < requiredBytes) {
        return failure("Cannot read normal data: Unexpected end of data.");
    }

    mesh.normals.capacity = vertexCount;
    for (uint i = 0; i < vertexCount; i++) {
        float x = readFloat(data, offset);
        offset += 4;
        float y = readFloat(data, offset);
        offset += 4;
        float z = readFloat(data, offset);
        offset += 4;
        mesh.normals ~= Normal(x, y, z);
    }

    return success();
}

private OperationResult readTangentData(
    const(ubyte)[] data,
    ref size_t offset,
    ref Mesh mesh,
    uint vertexCount
) {
    size_t requiredBytes = cast(size_t) vertexCount * 16;
    if (data.length - offset < requiredBytes) {
        return failure("Cannot read tangent data: Unexpected end of data.");
    }

    mesh.tangents.capacity = vertexCount;
    for (uint i = 0; i < vertexCount; i++) {
        float x = readFloat(data, offset);
        offset += 4;
        float y = readFloat(data, offset);
        offset += 4;
        float z = readFloat(data, offset);
        offset += 4;
        float w = readFloat(data, offset);
        offset += 4;
        mesh.tangents ~= Tangent(x, y, z, w);
    }

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

private OperationResult readMaterialData(const(ubyte)[] data, ref size_t offset, Model* model) {
    // Read material index
    if (data.length - offset < 4) {
        return failure("Cannot read material index: Unexpected end of data.");
    }

    MaterialIndex index = readUInt(data, offset);
    offset += 4;

    if (index == 0) {
        return failure("Material index 0 is reserved.");
    }

    for (size_t i; i < model.materials.length; i++) {
        if (model.materials[i].index == index) {
            return failure("Duplicate material index.");
        }
    }

    // Read material type
    if (data.length - offset < 1) {
        return failure("Cannot read material type: Unexpected end of data.");
    }

    ubyte typeByte = data[offset];
    offset += 1;

    Material material;
    material.index = index;

    // Match the type byte against every MaterialType member at compile time, so
    // new material types are recognised here automatically.
    bool knownType = false;
    static foreach (member; __traits(allMembers, MaterialType)) {
        if (typeByte == cast(ubyte) __traits(getMember, MaterialType, member)) {
            material.type = __traits(getMember, MaterialType, member);
            knownType = true;
        }
    }

    if (!knownType) {
        return failure("Unknown material type.");
    }

    // Common flags: present for every type except the `invalid` sentinel.
    if (material.type != MaterialType.invalid) {
        if (data.length - offset < 1) {
            return failure("Cannot read material flags: Unexpected end of data.");
        }

        ubyte flags = data[offset];
        offset += 1;
        material.doubleSided = (flags & MaterialFlags.doubleSided) != 0;
    }

    // Type-specific payload.
    if (material.type.referencesTexture) {
        // Read the referenced texture index. 0 means the material has no albedo texture and
        // takes its color from the base color factor alone.
        if (data.length - offset < 4) {
            return failure("Cannot read material texture index: Unexpected end of data.");
        }

        material.textureIndex = readUInt(data, offset);
        offset += 4;

        // The multiplier over that texture, stored even by a material without one - where it
        // is the albedo outright rather than a tint.
        if (data.length - offset < 16) {
            return failure("Cannot read material base color factor: Unexpected end of data.");
        }

        material.baseColorFactor.r = readFloat(data, offset);
        offset += 4;
        material.baseColorFactor.g = readFloat(data, offset);
        offset += 4;
        material.baseColorFactor.b = readFloat(data, offset);
        offset += 4;
        material.baseColorFactor.a = readFloat(data, offset);
        offset += 4;
    }

    if (material.type.referencesNormalTexture) {
        // Read the referenced normal map index. Always present for these types; 0 means
        // the material has no normal map.
        if (data.length - offset < 4) {
            return failure("Cannot read material normal texture index: Unexpected end of data.");
        }

        material.normalTextureIndex = readUInt(data, offset);
        offset += 4;

        // The strength dial for the map above. Stored even by a material without a normal
        // map, which keeps the payload a fixed size; it is simply unused there.
        if (data.length - offset < 4) {
            return failure("Cannot read material normal texture scale: Unexpected end of data.");
        }

        material.normalTextureScale = readFloat(data, offset);
        offset += 4;
    }

    model.materials ~= material;
    return success();
}

private OperationResult readTextureData(const(ubyte)[] data, ref size_t offset, Model* model) {
    // Read texture index
    if (data.length - offset < 4) {
        return failure("Cannot read texture index: Unexpected end of data.");
    }

    TextureIndex index = readUInt(data, offset);
    offset += 4;

    if (index == 0) {
        return failure("Texture index 0 is reserved.");
    }

    for (size_t i; i < model.textures.length; i++) {
        if (model.textures[i].index == index) {
            return failure("Duplicate texture index.");
        }
    }

    // Read texture type
    if (data.length - offset < 1) {
        return failure("Cannot read texture type: Unexpected end of data.");
    }

    ubyte typeByte = data[offset];
    offset += 1;

    Texture texture;
    texture.index = index;

    // Match the type byte against every TextureType member at compile time, so
    // new texture types are recognised here automatically.
    bool knownType = false;
    static foreach (member; __traits(allMembers, TextureType)) {
        if (typeByte == cast(ubyte) __traits(getMember, TextureType, member)) {
            texture.type = __traits(getMember, TextureType, member);
            knownType = true;
        }
    }

    if (!knownType) {
        return failure("Unknown texture type.");
    }

    // Read sampler filters (common to every texture type).
    if (data.length - offset < 1) {
        return failure("Cannot read texture magFilter: Unexpected end of data.");
    }

    ubyte magFilterByte = data[offset];
    offset += 1;

    bool knownMagFilter = false;
    static foreach (member; __traits(allMembers, TextureMagFilter)) {
        if (magFilterByte == cast(ubyte) __traits(getMember, TextureMagFilter, member)) {
            texture.magFilter = __traits(getMember, TextureMagFilter, member);
            knownMagFilter = true;
        }
    }

    if (!knownMagFilter) {
        return failure("Unknown texture magFilter.");
    }

    if (data.length - offset < 1) {
        return failure("Cannot read texture minFilter: Unexpected end of data.");
    }

    ubyte minFilterByte = data[offset];
    offset += 1;

    bool knownMinFilter = false;
    static foreach (member; __traits(allMembers, TextureMinFilter)) {
        if (minFilterByte == cast(ubyte) __traits(getMember, TextureMinFilter, member)) {
            texture.minFilter = __traits(getMember, TextureMinFilter, member);
            knownMinFilter = true;
        }
    }

    if (!knownMinFilter) {
        return failure("Unknown texture minFilter.");
    }

    // Read sampler wrap modes (common to every texture type).
    if (data.length - offset < 1) {
        return failure("Cannot read texture wrapS: Unexpected end of data.");
    }

    ubyte wrapSByte = data[offset];
    offset += 1;

    bool knownWrapS = false;
    static foreach (member; __traits(allMembers, TextureWrap)) {
        if (wrapSByte == cast(ubyte) __traits(getMember, TextureWrap, member)) {
            texture.wrapS = __traits(getMember, TextureWrap, member);
            knownWrapS = true;
        }
    }

    if (!knownWrapS) {
        return failure("Unknown texture wrapS.");
    }

    if (data.length - offset < 1) {
        return failure("Cannot read texture wrapT: Unexpected end of data.");
    }

    ubyte wrapTByte = data[offset];
    offset += 1;

    bool knownWrapT = false;
    static foreach (member; __traits(allMembers, TextureWrap)) {
        if (wrapTByte == cast(ubyte) __traits(getMember, TextureWrap, member)) {
            texture.wrapT = __traits(getMember, TextureWrap, member);
            knownWrapT = true;
        }
    }

    if (!knownWrapT) {
        return failure("Unknown texture wrapT.");
    }

    // Type-specific payload.
    if (texture.type == TextureType.embedded) {
        return failure("Embedded textures are not yet implemented.");
    }

    if (texture.type == TextureType.reference) {
        // Read path length
        if (data.length - offset < 2) {
            return failure("Cannot read texture path length: Unexpected end of data.");
        }

        ushort pathLength = readUShort(data, offset);
        offset += 2;

        // Read UTF-8 path bytes
        if (data.length - offset < pathLength) {
            return failure("Cannot read texture path: Unexpected end of data.");
        }

        for (size_t i; i < pathLength; i++) {
            texture.path ~= cast(char) data[offset + i];
        }

        offset += pathLength;
    }

    model.textures ~= texture;
    return success();
}

private OperationResult validateMeshMaterialReferences(Model* model) {
    // Iterate over non-owning slices to avoid Array.opIndex returning Mesh/Material
    // by value (which would deep-copy and reallocate inner arrays on every iteration).
    Mesh[] meshes = model.meshes.arr();
    Material[] materials = model.materials.arr();

    foreach (ref mesh; meshes) {
        MaterialIndex meshIndex = mesh.materialIndex;
        if (meshIndex == noMaterial) {
            continue;
        }

        bool found = false;
        foreach (ref material; materials) {
            if (material.index == meshIndex) {
                found = true;
                break;
            }
        }

        if (!found) {
            return failure("Mesh references unknown material index.");
        }
    }

    return success();
}

private OperationResult validateMaterialTextureReferences(Model* model) {
    // Iterate over non-owning slices to avoid Array.opIndex returning Material/Texture
    // by value (which would deep-copy and reallocate inner data on every iteration).
    Material[] materials = model.materials.arr();
    Texture[] textures = model.textures.arr();

    foreach (ref material; materials) {
        // An albedo texture index of 0 means the material has none and is colored by its base
        // color factor alone, so only a non-zero one has to resolve.
        if (material.type.referencesTexture && material.textureIndex != 0
            && !hasTexture(textures, material.textureIndex)) {
            return failure("Material references unknown texture index.");
        }

        // A normal texture index of 0 means the material has no normal map, so only a
        // non-zero one has to resolve.
        if (material.type.referencesNormalTexture && material.normalTextureIndex != 0
            && !hasTexture(textures, material.normalTextureIndex)) {
            return failure("Material references unknown normal texture index.");
        }
    }

    return success();
}

private bool hasTexture(Texture[] textures, TextureIndex index) {
    foreach (ref texture; textures) {
        if (texture.index == index) {
            return true;
        }
    }

    return false;
}

version (UnitTesting)  :  ///

void runRgmTests() {
    import retrograde.std.test : test, writeSection;

    writeSection("-- RGM tests --");

    test("Load simple model containing a plane", {
        ubyte[152] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x04, 0x00, 0x00, 0x00, // Vertex count (4)
            0x02, 0x00, 0x00, 0x00, // Face count (2)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)

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
        assert(model.textures.length == 0);
    });

    test("Reject model with trailing bytes beyond expected data", {
        ubyte[153] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x04, 0x00, 0x00, 0x00, // Vertex count (4)
            0x02, 0x00, 0x00, 0x00, // Face count (2)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)

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
        ubyte[116] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)

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
        ubyte[164] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x02, // UV channel count (2)
            0x00, // Attribute flags (none)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)

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

    test("Load model with one Unlit material referencing a texture", {
        ubyte[164] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x01, 0x00, 0x00, 0x00, // Material index (1)

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

            // Material 1
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x02, // Material type (Unlit)
            0x00, // Common flags (none)
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, 0x00, 0x00, 0x3F, // Base color factor R (0.5)
            0x00, 0x00, 0x80, 0x3E, // Base color factor G (0.25)
            0x00, 0x00, 0x80, 0x3F, // Base color factor B (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor A (1)

            // Texture 1
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0x02, // magFilter (linear)
            0x06, // minFilter (linearMipmapLinear)
            0x02, // wrapS (clampToEdge)
            0x01, // wrapT (repeat)
            0x0B, 0x00, // Path length (11)
            'd', 'i', 'f', 'f', 'u', 's', 'e', '.', 'r', 'g', 'i', // Path
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.materials.length == 1);
        assert(model.materials[0].index == 1);
        assert(model.materials[0].type == MaterialType.unlit);
        assert(model.materials[0].doubleSided == false);
        assert(model.materials[0].textureIndex == 1);
        assert(model.materials[0].baseColorFactor.r == 0.5f);
        assert(model.materials[0].baseColorFactor.g == 0.25f);
        assert(model.materials[0].baseColorFactor.b == 1.0f);
        assert(model.materials[0].baseColorFactor.a == 1.0f);
        assert(model.meshes[0].materialIndex == 1);

        assert(model.textures.length == 1);
        assert(model.textures[0].index == 1);
        assert(model.textures[0].type == TextureType.reference);
        assert(model.textures[0].magFilter == TextureMagFilter.linear);
        assert(model.textures[0].minFilter == TextureMinFilter.linearMipmapLinear);
        assert(model.textures[0].wrapS == TextureWrap.clampToEdge);
        assert(model.textures[0].wrapT == TextureWrap.repeat);
        assert(model.textures[0].path == "diffuse.rgi");
    });

    test("Load model with one Vertex Colors material", {
        ubyte[122] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x07, 0x00, 0x00, 0x00, // Material index (7)

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

            // Material 1
            0x07, 0x00, 0x00, 0x00, // Material index (7)
            0x01, // Material type (Vertex Colors)
            0x00, // Common flags (none)
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.materials.length == 1);
        assert(model.materials[0].index == 7);
        assert(model.materials[0].type == MaterialType.vertexColors);
        assert(model.materials[0].doubleSided == false);
        assert(model.materials[0].textureIndex == 0);
        assert(model.meshes[0].materialIndex == 7);
        assert(model.textures.length == 0);
    });

    test("Load model with multiple materials using non-sequential indices", {
        ubyte[183] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x02, 0x00, 0x00, 0x00, // Amount of meshes (2)
            0x02, 0x00, 0x00, 0x00, // Amount of materials (2)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x05, 0x00, 0x00, 0x00, // Material index (5)

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

            // Mesh 2 (degenerate, references material 9)
            0x00, 0x00, 0x00, 0x00, // Vertex count (0)
            0x00, 0x00, 0x00, 0x00, // Face count (0)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x09, 0x00, 0x00, 0x00, // Material index (9)

            // Material 1: Unlit at index 5, referencing texture 2
            0x05, 0x00, 0x00, 0x00, // Material index (5)
            0x02, // Material type (Unlit)
            0x00, // Common flags (none)
            0x02, 0x00, 0x00, 0x00, // Texture index (2)
            0x00, 0x00, 0x80, 0x3F, // Base color factor R (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor G (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor B (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor A (1)

            // Material 2: Vertex Colors at index 9
            0x09, 0x00, 0x00, 0x00, // Material index (9)
            0x01, // Material type (Vertex Colors)
            0x00, // Common flags (none)

            // Texture 1: reference at index 2 (declared index is independent of file order)
            0x02, 0x00, 0x00, 0x00, // Texture index (2)
            0x00, // Texture type (reference)
            0x00, // magFilter (unspecified)
            0x00, // minFilter (unspecified)
            0x00, // wrapS (unspecified)
            0x00, // wrapT (unspecified)
            0x0A, 0x00, // Path length (10)
            'a', 'l', 'b', 'e', 'd', 'o', '.', 'r', 'g', 'i',
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.materials.length == 2);
        assert(model.materials[0].index == 5);
        assert(model.materials[0].type == MaterialType.unlit);
        assert(model.materials[0].doubleSided == false);
        assert(model.materials[0].textureIndex == 2);
        assert(model.materials[1].index == 9);
        assert(model.materials[1].type == MaterialType.vertexColors);
        assert(model.materials[1].doubleSided == false);

        assert(model.meshes[0].materialIndex == 5);
        assert(model.meshes[1].materialIndex == 9);

        assert(model.textures.length == 1);
        assert(model.textures[0].index == 2);
        assert(model.textures[0].type == TextureType.reference);
        assert(model.textures[0].magFilter == TextureMagFilter.unspecified);
        assert(model.textures[0].minFilter == TextureMinFilter.unspecified);
        assert(model.textures[0].wrapS == TextureWrap.unspecified);
        assert(model.textures[0].wrapT == TextureWrap.unspecified);
        assert(model.textures[0].path == "albedo.rgi");
    });

    test("Load model with a double-sided material", {
        ubyte[38] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1 (degenerate, references material 1)
            0x00, 0x00, 0x00, 0x00, // Vertex count (0)
            0x00, 0x00, 0x00, 0x00, // Face count (0)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x01, 0x00, 0x00, 0x00, // Material index (1)

            // Material 1: Vertex Colors, double-sided (with a reserved bit also set)
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x01, // Material type (Vertex Colors)
            0x03, // Common flags (double-sided | reserved bit 1)
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.materials.length == 1);
        assert(model.materials[0].index == 1);
        assert(model.materials[0].type == MaterialType.vertexColors);
        // Bit 0 set => double-sided; reserved bits are ignored, parsing stays clean.
        assert(model.materials[0].doubleSided == true);
        assert(model.meshes[0].materialIndex == 1);
    });

    test("Reject material with reserved index 0", {
        ubyte[23] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Material 1: reserved index 0
            0x00, 0x00, 0x00, 0x00, // Material index (0 - reserved)
            0x01, // Material type (Vertex Colors)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject duplicate material indices", {
        ubyte[30] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x02, 0x00, 0x00, 0x00, // Amount of materials (2)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Material 1
            0x03, 0x00, 0x00, 0x00, // Material index (3)
            0x01, // Material type (Vertex Colors)
            0x00, // Common flags (none)

            // Material 2 (duplicate index)
            0x03, 0x00, 0x00, 0x00, // Material index (3) - duplicate!
            0x01, // Material type (Vertex Colors)
            0x00, // Common flags (none)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject mesh referencing unknown material index", {
        ubyte[62] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1 (references material 99)
            0x01, 0x00, 0x00, 0x00, // Vertex count (1)
            0x00, 0x00, 0x00, 0x00, // Face count (0)
            0x00, // UV channel count (0)
            0x00, // Attribute flags (none)
            0x63, 0x00, 0x00, 0x00, // Material index (99)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x80, 0x3F, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,

            // Material 1 (only index 1 exists, not 99)
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x01, // Material type (Vertex Colors)
            0x00, // Common flags (none)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject unknown material type byte", {
        ubyte[23] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Material 1: unknown type
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0xFF, // Material type (unknown)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject texture with reserved index 0", {
        ubyte[23] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Texture 1: reserved index 0
            0x00, 0x00, 0x00, 0x00, // Texture index (0 - reserved)
            0x00, // Texture type (reference)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject duplicate texture indices", {
        ubyte[33] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x02, 0x00, 0x00, 0x00, // Amount of textures (2)

            // Texture 1
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0x00, // magFilter (unspecified)
            0x00, // minFilter (unspecified)
            0x00, // wrapS (unspecified)
            0x00, // wrapT (unspecified)
            0x00, 0x00, // Path length (0)

            // Texture 2 (duplicate index)
            0x01, 0x00, 0x00, 0x00, // Texture index (1) - duplicate!
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject embedded texture as not yet implemented", {
        ubyte[27] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Texture 1: embedded (reserved, not implemented)
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x01, // Texture type (embedded)
            0x00, // magFilter (unspecified)
            0x00, // minFilter (unspecified)
            0x00, // wrapS (unspecified)
            0x00, // wrapT (unspecified)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject texture with unknown magFilter", {
        ubyte[24] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Texture 1: reference with an out-of-range magFilter
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0xFF, // magFilter (unknown)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject texture with unknown minFilter", {
        ubyte[25] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Texture 1: reference with a valid magFilter but out-of-range minFilter
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0x02, // magFilter (linear)
            0xFF, // minFilter (unknown)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject texture with unknown wrapS", {
        ubyte[26] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Texture 1: reference with valid filters but an out-of-range wrapS
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0x02, // magFilter (linear)
            0x02, // minFilter (linear)
            0xFF, // wrapS (unknown)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject texture with unknown wrapT", {
        ubyte[27] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Texture 1: reference with a valid wrapS but out-of-range wrapT
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0x02, // magFilter (linear)
            0x02, // minFilter (linear)
            0x01, // wrapS (repeat)
            0xFF, // wrapT (unknown)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject unlit material referencing unknown texture index", {
        ubyte[44] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Material 1: Unlit referencing a non-existent texture 99
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x02, // Material type (Unlit)
            0x00, // Common flags (none)
            0x63, 0x00, 0x00, 0x00, // Texture index (99 - undefined)
            0x00, 0x00, 0x80, 0x3F, // Base color factor R (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor G (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor B (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor A (1)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Load model with a PBR material referencing an albedo and a normal texture", {
        ubyte[94] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x02, 0x00, 0x00, 0x00, // Amount of textures (2)

            // Material 1
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x04, // Material type (PBR Metallic-Roughness)
            0x00, // Common flags (none)
            0x01, 0x00, 0x00, 0x00, // Albedo texture index (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor R (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor G (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor B (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor A (1)
            0x02, 0x00, 0x00, 0x00, // Normal texture index (2)
            0x00, 0x00, 0x00, 0x3F, // Normal texture scale (0.5)

            // Texture 1
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0x00, // magFilter (unspecified)
            0x00, // minFilter (unspecified)
            0x00, // wrapS (unspecified)
            0x00, // wrapT (unspecified)
            0x0A, 0x00, // Path length (10)
            'a', 'l', 'b', 'e', 'd', 'o', '.', 'r', 'g', 'i', // Path

            // Texture 2
            0x02, 0x00, 0x00, 0x00, // Texture index (2)
            0x00, // Texture type (reference)
            0x00, // magFilter (unspecified)
            0x00, // minFilter (unspecified)
            0x00, // wrapS (unspecified)
            0x00, // wrapT (unspecified)
            0x0A, 0x00, // Path length (10)
            'n', 'o', 'r', 'm', 'a', 'l', '.', 'r', 'g', 'i', // Path
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.materials.length == 1);
        assert(model.materials[0].type == MaterialType.pbrMetallicRoughness);
        assert(model.materials[0].textureIndex == 1);
        assert(model.materials[0].baseColorFactor.r == 1.0f);
        assert(model.materials[0].baseColorFactor.a == 1.0f);
        assert(model.materials[0].normalTextureIndex == 2);
        assert(model.materials[0].normalTextureScale == 0.5);

        assert(model.textures.length == 2);
        assert(model.textures[0].path == "albedo.rgi");
        assert(model.textures[1].path == "normal.rgi");
    });

    test("Load model with a Lambert material without a normal texture", {
        ubyte[73] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Material 1
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x03, // Material type (Lambert)
            0x00, // Common flags (none)
            0x01, 0x00, 0x00, 0x00, // Albedo texture index (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor R (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor G (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor B (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor A (1)
            0x00, 0x00, 0x00, 0x00, // Normal texture index (0 - none)
            0x00, 0x00, 0x80, 0x3F, // Normal texture scale (1.0 - unused without a map)

            // Texture 1
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0x00, // magFilter (unspecified)
            0x00, // minFilter (unspecified)
            0x00, // wrapS (unspecified)
            0x00, // wrapT (unspecified)
            0x0A, 0x00, // Path length (10)
            'a', 'l', 'b', 'e', 'd', 'o', '.', 'r', 'g', 'i', // Path
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.materials.length == 1);
        assert(model.materials[0].type == MaterialType.lambert);
        assert(model.materials[0].textureIndex == 1);
        assert(model.materials[0].normalTextureIndex == 0);
        assert(model.materials[0].normalTextureScale == 1.0);
    });

    test("Reject material referencing unknown normal texture index", {
        ubyte[73] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x01, 0x00, 0x00, 0x00, // Amount of textures (1)

            // Material 1: albedo resolves, but the normal map does not
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x04, // Material type (PBR Metallic-Roughness)
            0x00, // Common flags (none)
            0x01, 0x00, 0x00, 0x00, // Albedo texture index (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor R (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor G (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor B (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor A (1)
            0x63, 0x00, 0x00, 0x00, // Normal texture index (99 - undefined)
            0x00, 0x00, 0x80, 0x3F, // Normal texture scale (1.0)

            // Texture 1
            0x01, 0x00, 0x00, 0x00, // Texture index (1)
            0x00, // Texture type (reference)
            0x00, // magFilter (unspecified)
            0x00, // minFilter (unspecified)
            0x00, // wrapS (unspecified)
            0x00, // wrapT (unspecified)
            0x0A, 0x00, // Path length (10)
            'a', 'l', 'b', 'e', 'd', 'o', '.', 'r', 'g', 'i', // Path
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Load model with a material that has no albedo texture, only a base color", {
        ubyte[44] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Material 1: index 0 means no texture, so the factor is the albedo outright.
            // The file declares no textures at all and still validates.
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x02, // Material type (Unlit)
            0x00, // Common flags (none)
            0x00, 0x00, 0x00, 0x00, // Albedo texture index (0 - none)
            0x90, 0x39, 0x89, 0x3D, // Base color factor R (0.067004323)
            0x4A, 0xCD, 0x4C, 0x3F, // Base color factor G (0.80000746)
            0x4B, 0x0B, 0x06, 0x3E, // Base color factor B (0.13090245)
            0x00, 0x00, 0x80, 0x3F, // Base color factor A (1)
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.materials.length == 1);
        assert(model.materials[0].type == MaterialType.unlit);
        assert(model.materials[0].textureIndex == 0);
        assert(model.materials[0].baseColorFactor.r == 0.067004323f);
        assert(model.materials[0].baseColorFactor.g == 0.80000746f);
        assert(model.materials[0].baseColorFactor.b == 0.13090245f);
        assert(model.materials[0].baseColorFactor.a == 1.0f);
        assert(model.textures.length == 0);
    });

    test("Reject textured material truncated after its albedo texture index", {
        ubyte[28] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Material 1: the mandatory base color factor is missing
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x04, // Material type (PBR Metallic-Roughness)
            0x00, // Common flags (none)
            0x01, 0x00, 0x00, 0x00, // Albedo texture index (1)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject textured material truncated part-way through its base color factor", {
        ubyte[36] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Material 1: only two of the factor's four components are present
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x02, // Material type (Unlit)
            0x00, // Common flags (none)
            0x01, 0x00, 0x00, 0x00, // Albedo texture index (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor R (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor G (1)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject lit material truncated after its normal texture index", {
        ubyte[48] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x00, 0x00, 0x00, 0x00, // Amount of meshes (0)
            0x01, 0x00, 0x00, 0x00, // Amount of materials (1)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Material 1: the mandatory normal texture scale is missing
            0x01, 0x00, 0x00, 0x00, // Material index (1)
            0x04, // Material type (PBR Metallic-Roughness)
            0x00, // Common flags (none)
            0x01, 0x00, 0x00, 0x00, // Albedo texture index (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor R (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor G (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor B (1)
            0x00, 0x00, 0x80, 0x3F, // Base color factor A (1)
            0x00, 0x00, 0x00, 0x00, // Normal texture index (0 - none)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Load model with normals", {
        ubyte[152] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x00, // UV channel count (0)
            0x01, // Attribute flags (normals)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, // X coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Y coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Vertex 2
            0x00, 0x00, 0x80, 0x3F, // X coordinate (1.0)
            0x00, 0x00, 0x00, 0x00, // Y coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Vertex 3
            0x00, 0x00, 0x00, 0x00, // X coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // Y coordinate (1.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Face 1
            0x00, 0x00, 0x00, 0x00, // Vertex index 1 (0)
            0x01, 0x00, 0x00, 0x00, // Vertex index 2 (1)
            0x02, 0x00, 0x00, 0x00, // Vertex index 3 (2)

            // Normal 1 (0, 0, 1)
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x80, 0x3F, // Z (1.0)

            // Normal 2 (0, 1, 0)
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x80, 0x3F, // Y (1.0)
            0x00, 0x00, 0x00, 0x00, // Z (0.0)

            // Normal 3 (-1, 0, 0)
            0x00, 0x00, 0x80, 0xBF, // X (-1.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x00, 0x00, // Z (0.0)
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.meshes[0].normals.length == 3);

        assert(model.meshes[0].normals[0].x == 0.0);
        assert(model.meshes[0].normals[0].y == 0.0);
        assert(model.meshes[0].normals[0].z == 1.0);

        assert(model.meshes[0].normals[1].x == 0.0);
        assert(model.meshes[0].normals[1].y == 1.0);
        assert(model.meshes[0].normals[1].z == 0.0);

        assert(model.meshes[0].normals[2].x == -1.0);
        assert(model.meshes[0].normals[2].y == 0.0);
        assert(model.meshes[0].normals[2].z == 0.0);

        assert(model.meshes[0].tangents.length == 0);
    });

    test("Load model with normals and tangents", {
        ubyte[224] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x03, 0x00, 0x00, 0x00, // Vertex count (3)
            0x01, 0x00, 0x00, 0x00, // Face count (1)
            0x01, // UV channel count (1)
            0x03, // Attribute flags (normals | tangents)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, // X coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Y coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Vertex 2
            0x00, 0x00, 0x80, 0x3F, // X coordinate (1.0)
            0x00, 0x00, 0x00, 0x00, // Y coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Vertex 3
            0x00, 0x00, 0x00, 0x00, // X coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // Y coordinate (1.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Face 1
            0x00, 0x00, 0x00, 0x00, // Vertex index 1 (0)
            0x01, 0x00, 0x00, 0x00, // Vertex index 2 (1)
            0x02, 0x00, 0x00, 0x00, // Vertex index 3 (2)

            // UV channel 0
            0x00, 0x00, 0x00, 0x00, // U (0.0)
            0x00, 0x00, 0x00, 0x00, // V (0.0)
            0x00, 0x00, 0x80, 0x3F, // U (1.0)
            0x00, 0x00, 0x00, 0x00, // V (0.0)
            0x00, 0x00, 0x00, 0x00, // U (0.0)
            0x00, 0x00, 0x80, 0x3F, // V (1.0)

            // Normal 1 (0, 0, 1)
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x80, 0x3F, // Z (1.0)

            // Normal 2 (0, 0, 1)
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x80, 0x3F, // Z (1.0)

            // Normal 3 (0, 0, 1)
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x80, 0x3F, // Z (1.0)

            // Tangent 1 (1, 0, 0, +1)
            0x00, 0x00, 0x80, 0x3F, // X (1.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x00, 0x00, // Z (0.0)
            0x00, 0x00, 0x80, 0x3F, // W handedness (1.0)

            // Tangent 2 (1, 0, 0, -1), a mirrored UV island
            0x00, 0x00, 0x80, 0x3F, // X (1.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x00, 0x00, // Z (0.0)
            0x00, 0x00, 0x80, 0xBF, // W handedness (-1.0)

            // Tangent 3 (0, 1, 0, +1)
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x80, 0x3F, // Y (1.0)
            0x00, 0x00, 0x00, 0x00, // Z (0.0)
            0x00, 0x00, 0x80, 0x3F, // W handedness (1.0)
        ];

        auto result = loadModel(modelData);
        assert(result.isSuccessful());

        auto model = result.unique();
        assert(model.meshes[0].uvChannelCount == 1);
        assert(model.meshes[0].uvCoords.length == 3);
        assert(model.meshes[0].normals.length == 3);
        assert(model.meshes[0].tangents.length == 3);

        assert(model.meshes[0].normals[2].z == 1.0);

        assert(model.meshes[0].tangents[0].x == 1.0);
        assert(model.meshes[0].tangents[0].y == 0.0);
        assert(model.meshes[0].tangents[0].z == 0.0);
        assert(model.meshes[0].tangents[0].w == 1.0);

        assert(model.meshes[0].tangents[1].w == -1.0);

        assert(model.meshes[0].tangents[2].x == 0.0);
        assert(model.meshes[0].tangents[2].y == 1.0);
        assert(model.meshes[0].tangents[2].w == 1.0);
    });

    test("Reject mesh with tangents but no normals", {
        ubyte[32] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x00, 0x00, 0x00, 0x00, // Vertex count (0)
            0x00, 0x00, 0x00, 0x00, // Face count (0)
            0x01, // UV channel count (1)
            0x02, // Attribute flags (tangents without normals)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject mesh with tangents but no UV channels", {
        ubyte[32] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x00, 0x00, 0x00, 0x00, // Vertex count (0)
            0x00, 0x00, 0x00, 0x00, // Face count (0)
            0x00, // UV channel count (0)
            0x03, // Attribute flags (normals | tangents)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject mesh with reserved attribute flag bits set", {
        ubyte[32] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x00, 0x00, 0x00, 0x00, // Vertex count (0)
            0x00, 0x00, 0x00, 0x00, // Face count (0)
            0x00, // UV channel count (0)
            0x04, // Attribute flags (reserved bit 2)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject mesh with a truncated normal block", {
        ubyte[64] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x01, 0x00, 0x00, 0x00, // Vertex count (1)
            0x00, 0x00, 0x00, 0x00, // Face count (0)
            0x00, // UV channel count (0)
            0x01, // Attribute flags (normals)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, // X coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Y coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // Normal 1, cut short: only X and Y are present
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });

    test("Reject mesh with a truncated tangent block", {
        ubyte[84] modelData = [
            // Header
            0x52, 0x47, 0x4D, 0x20, // Magic
            0x01, 0x00, // Version
            0x01, 0x00, 0x00, 0x00, // Amount of meshes (1)
            0x00, 0x00, 0x00, 0x00, // Amount of materials (0)
            0x00, 0x00, 0x00, 0x00, // Amount of textures (0)

            // Mesh 1
            0x01, 0x00, 0x00, 0x00, // Vertex count (1)
            0x00, 0x00, 0x00, 0x00, // Face count (0)
            0x01, // UV channel count (1)
            0x03, // Attribute flags (normals | tangents)
            0x00, 0x00, 0x00, 0x00, // Material index (0 = no material)

            // Vertex 1
            0x00, 0x00, 0x00, 0x00, // X coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Y coordinate (0.0)
            0x00, 0x00, 0x00, 0x00, // Z coordinate (0.0)
            0x00, 0x00, 0x80, 0x3F, // R color (1.0)
            0x00, 0x00, 0x80, 0x3F, // G color (1.0)
            0x00, 0x00, 0x80, 0x3F, // B color (1.0)

            // UV channel 0
            0x00, 0x00, 0x00, 0x00, // U (0.0)
            0x00, 0x00, 0x00, 0x00, // V (0.0)

            // Normal 1 (0, 0, 1)
            0x00, 0x00, 0x00, 0x00, // X (0.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
            0x00, 0x00, 0x80, 0x3F, // Z (1.0)

            // Tangent 1, cut short: only X and Y are present
            0x00, 0x00, 0x80, 0x3F, // X (1.0)
            0x00, 0x00, 0x00, 0x00, // Y (0.0)
        ];

        auto result = loadModel(modelData);
        assert(!result.isSuccessful());
    });
}
