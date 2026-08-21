/**
 * rgmodelconv - glTF 2.0 model reader.
 *
 * Imports a `.gltf` text file (with an external `.bin` buffer and external image
 * files) into the intermediate `ModelData` form, using a small custom parser
 * built on Phobos' JSON support. Binary `.glb` containers and embedded
 * (data-URI / bufferView) buffers and images are not supported.
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2026 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module reader;

import std.conv : to;
import std.json : parseJSON, JSONValue, JSONType;
import std.bitmanip : peek;
import std.system : Endian;
import std.uri : decodeComponent;
import std.file : read, readText;
import std.path : buildPath, dirName, extension;

import retrograde.assets.model : TextureMagFilter, TextureMinFilter, TextureWrap;

import model : Primitive, MaterialInfo, ModelData, TextureRef;

/// glTF `primitive.mode` value for a triangle list. The only mode we support.
private enum glTfModeTriangles = 4;

/// Outcome of a read: either a populated `model`, or `ok == false` with an `error`.
struct ReadResult {
    bool ok;
    string error;
    ModelData model;
}

/**
 * Read a model file into the intermediate `ModelData` form.
 *
 * Only glTF 2.0 `.gltf` files are supported. Any parsing or I/O failure is
 * reported through the returned `ReadResult` rather than thrown.
 */
ReadResult readModel(string path) {
    if (extension(path) == ".glb") {
        return ReadResult(false,
            "binary glTF (.glb) is not supported. Provide a .gltf file with an external .bin buffer.",
            ModelData.init);
    }

    try {
        return ReadResult(true, "", parseGltf(path));
    } catch (Exception e) {
        return ReadResult(false, e.msg, ModelData.init);
    }
}

/**
 * Parse a glTF 2.0 file into the flattened `Primitive`/`MaterialInfo` lists the
 * RGM writer consumes.
 *
 * The buffer(s) and image files are resolved relative to the glTF file's own
 * directory. Only external resources are supported: buffers must carry a `uri`
 * pointing at a companion file (typically the `.bin`), and image references used
 * as texture paths must likewise be external files.
 */
private ModelData parseGltf(string path) {
    JSONValue gltf = parseJSON(readText(path));
    string gltfDir = dirName(path);

    ModelData result;

    // Load every buffer up front. Embedded (data-URI) and .glb-style bufferless
    // buffers are rejected: we only support an external companion file.
    const(ubyte)[][] buffers;
    if (auto buffersP = "buffers" in gltf.object) {
        foreach (buf; buffersP.array) {
            string uri = optStr(buf, "uri", "");
            if (uri.length == 0) {
                throw new Exception(
                    "Buffer has no 'uri'. Embedded/GLB buffers are not supported; " ~
                        "provide a .gltf with an external .bin file.");
            }

            if (startsWith(uri, "data:")) {
                throw new Exception(
                    "Data-URI buffers are not supported; provide a .gltf with an external .bin file.");
            }

            string bufferPath = buildPath(gltfDir, decodeComponent(uri));
            buffers ~= cast(const(ubyte)[]) read(bufferPath);
        }
    }

    // Flatten every primitive of every mesh, in file order.
    if (auto meshesP = "meshes" in gltf.object) {
        foreach (mesh; meshesP.array) {
            if (auto primsP = "primitives" in mesh.object) {
                foreach (prim; primsP.array) {
                    result.primitives ~= parsePrimitive(gltf, buffers, prim);
                }
            }
        }
    }

    // Extract classification inputs for every material, in glTF order, so a
    // primitive's `materialIndex` indexes straight into this list.
    if (auto materialsP = "materials" in gltf.object) {
        foreach (mat; materialsP.array) {
            result.materials ~= parseMaterial(gltf, mat);
        }
    }

    return result;
}

/// Parse one glTF primitive into a `Primitive`, reading its geometry from the accessors.
private Primitive parsePrimitive(ref JSONValue gltf, const(ubyte)[][] buffers, JSONValue prim) {
    Primitive result;

    long mode = optInt(prim, "mode", glTfModeTriangles);
    if (mode != glTfModeTriangles) {
        throw new Exception(
            "Only triangle primitives (mode 4) are supported; found mode " ~ mode.to!string ~ ".");
    }

    auto attrsP = "attributes" in prim.object;
    if (attrsP is null) {
        throw new Exception("Primitive is missing its 'attributes'.");
    }

    JSONValue attrs = *attrsP;
    auto posP = "POSITION" in attrs.object;
    if (posP is null) {
        throw new Exception("Primitive is missing the POSITION attribute.");
    }

    AccessorData positions = readFloatAccessor(gltf, buffers, cast(size_t) jsonInt(*posP));
    if (positions.componentCount != 3) {
        throw new Exception("POSITION accessor must be a VEC3.");
    }

    result.vertexCount = cast(uint) positions.count;
    result.positions = positions.values;

    // Vertex colors (COLOR_0). The RGB components are kept and any alpha is dropped.
    if (auto colorP = "COLOR_0" in attrs.object) {
        AccessorData colors = readFloatAccessor(gltf, buffers, cast(size_t) jsonInt(*colorP));
        if (colors.count != result.vertexCount) {
            throw new Exception("COLOR_0 accessor count does not match POSITION.");
        }

        result.hasColors = true;
        result.colors = new float[result.vertexCount * 3];
        for (uint i = 0; i < result.vertexCount; i++) {
            for (uint c = 0; c < 3; c++) {
                result.colors[i * 3 + c] = colors.values[i * colors.componentCount + c];
            }
        }
    }

    // Normals (NORMAL). Passed through as authored; nothing is generated when the
    // attribute is absent.
    if (auto normalP = "NORMAL" in attrs.object) {
        AccessorData normals = readFloatAccessor(gltf, buffers, cast(size_t) jsonInt(*normalP));
        if (normals.componentCount != 3) {
            throw new Exception("NORMAL accessor must be a VEC3.");
        }

        if (normals.count != result.vertexCount) {
            throw new Exception("NORMAL accessor count does not match POSITION.");
        }

        result.normals = normals.values;
    }

    // UV channels (TEXCOORD_0, TEXCOORD_1, ...), contiguous from 0. UVs are kept
    // exactly as glTF stores them (top-left origin), which is the convention the
    // engine expects; V is not flipped.
    for (uint channel = 0;; channel++) {
        auto uvP = ("TEXCOORD_" ~ channel.to!string) in attrs.object;
        if (uvP is null) {
            break;
        }

        AccessorData uv = readFloatAccessor(gltf, buffers, cast(size_t) jsonInt(*uvP));
        if (uv.count != result.vertexCount) {
            throw new Exception("TEXCOORD accessor count does not match POSITION.");
        }

        float[] channelData = new float[result.vertexCount * 2];
        for (uint i = 0; i < result.vertexCount; i++) {
            channelData[i * 2 + 0] = uv.values[i * uv.componentCount + 0];
            channelData[i * 2 + 1] = uv.values[i * uv.componentCount + 1];
        }

        result.uvChannels ~= channelData;
    }

    // Tangents (TANGENT). Also passed through as authored. A tangent basis is
    // orthogonal to the normal and describes the gradient of the first UV channel,
    // so it is dropped when either is missing — the glTF spec likewise says
    // tangents are ignored on a primitive without normals.
    if (auto tangentP = "TANGENT" in attrs.object) {
        if (result.normals.length > 0 && result.uvChannels.length > 0) {
            AccessorData tangents = readFloatAccessor(gltf, buffers, cast(size_t) jsonInt(
                    *tangentP));
            if (tangents.componentCount != 4) {
                throw new Exception("TANGENT accessor must be a VEC4.");
            }

            if (tangents.count != result.vertexCount) {
                throw new Exception("TANGENT accessor count does not match POSITION.");
            }

            result.tangents = tangents.values;
        }
    }

    // Faces. Indexed geometry is read as-is; non-indexed primitives get an
    // implicit sequential triangle list.
    if (auto indicesP = "indices" in prim.object) {
        result.indices = readIndexAccessor(gltf, buffers, cast(size_t) jsonInt(*indicesP));
    } else {
        result.indices = new uint[result.vertexCount];
        foreach (i; 0 .. result.vertexCount) {
            result.indices[i] = i;
        }
    }

    if (result.indices.length % 3 != 0) {
        throw new Exception("Triangle index count is not a multiple of three.");
    }

    result.materialIndex = cast(int) optInt(prim, "material", -1);
    return result;
}

/// Extract the classification inputs from a single glTF material.
private MaterialInfo parseMaterial(ref JSONValue gltf, JSONValue mat) {
    MaterialInfo info;

    if (auto extP = "extensions" in mat.object) {
        info.unlit = ("KHR_materials_unlit" in extP.object) !is null;
    }

    // `extras` is glTF's escape hatch for application-specific data, and is where a
    // Blender custom property on the material ends up. Carried over as the raw string;
    // the writer is what knows the RGM material type names it can spell.
    if (auto extrasP = "extras" in mat.object) {
        if (extrasP.type == JSONType.object) {
            if (auto rgMatP = "rg_mat" in extrasP.object) {
                if (rgMatP.type == JSONType.string) {
                    info.materialTypeOverride = rgMatP.str;
                }
            }
        }
    }

    info.doubleSided = optBool(mat, "doubleSided", false);

    // Only the base color (albedo) texture is converted, whether the material is
    // unlit or a lit PBR one: the remaining PBR slots (metallic-roughness, normal,
    // occlusion and emissive) have no RGM payload yet. They are still counted in
    // `hasAnyTexture`, so a material carrying only, say, a normal map is not
    // mistaken for a textureless vertex-colored one.
    JSONValue* pbrP = "pbrMetallicRoughness" in mat.object;
    JSONValue* baseColorP = pbrP is null ? null : "baseColorTexture" in pbrP.object;

    info.hasAnyTexture = baseColorP !is null
        || hasKey(mat, "emissiveTexture")
        || hasKey(mat, "normalTexture")
        || hasKey(mat, "occlusionTexture")
        || (pbrP !is null && hasKey(*pbrP, "metallicRoughnessTexture"));

    if (baseColorP !is null) {
        TextureRef texture = resolveTextureRef(gltf, *baseColorP);
        if (texture.path.length > 0 && !startsWith(texture.path, "data:")) {
            info.baseColorTexture = texture;
        }
    }

    return info;
}

/**
 * Resolve a glTF `textureInfo` (an object carrying an `index` into `textures`)
 * to a `TextureRef`: the backing image's URI plus the sampler's magnification and
 * minification filters and its S/T wrap modes. `path` is "" when the image is
 * embedded (no `uri`) or cannot be resolved. Filters and wrap modes default to
 * `unspecified` when the texture has no sampler or the sampler omits them.
 */
private TextureRef resolveTextureRef(ref JSONValue gltf, JSONValue textureInfo) {
    TextureRef result;

    auto texturesP = "textures" in gltf.object;
    auto imagesP = "images" in gltf.object;
    if (texturesP is null || imagesP is null) {
        return result;
    }

    long textureIndex = jsonInt(textureInfo["index"]);
    JSONValue texture = texturesP.array[textureIndex];

    auto sourceP = "source" in texture.object;
    if (sourceP is null) {
        return result;
    }

    JSONValue image = imagesP.array[jsonInt(*sourceP)];
    result.path = optStr(image, "uri", "");

    auto samplerP = "sampler" in texture.object;
    if (samplerP !is null) {
        if (auto samplersP = "samplers" in gltf.object) {
            JSONValue sampler = samplersP.array[jsonInt(*samplerP)];
            result.magFilter = mapMagFilter(optInt(sampler, "magFilter", 0));
            result.minFilter = mapMinFilter(optInt(sampler, "minFilter", 0));
            result.wrapS = mapWrap(optInt(sampler, "wrapS", 0));
            result.wrapT = mapWrap(optInt(sampler, "wrapT", 0));
        }
    }

    return result;
}

/// Map a glTF/OpenGL magnification filter constant to the engine `TextureMagFilter`.
private TextureMagFilter mapMagFilter(long glFilter) {
    switch (glFilter) {
    case 9728: // GL_NEAREST
        return TextureMagFilter.nearest;
    case 9729: // GL_LINEAR
        return TextureMagFilter.linear;
    default:
        return TextureMagFilter.unspecified;
    }
}

/// Map a glTF/OpenGL minification filter constant to the engine `TextureMinFilter`.
private TextureMinFilter mapMinFilter(long glFilter) {
    switch (glFilter) {
    case 9728: // GL_NEAREST
        return TextureMinFilter.nearest;
    case 9729: // GL_LINEAR
        return TextureMinFilter.linear;
    case 9984: // GL_NEAREST_MIPMAP_NEAREST
        return TextureMinFilter.nearestMipmapNearest;
    case 9985: // GL_LINEAR_MIPMAP_NEAREST
        return TextureMinFilter.linearMipmapNearest;
    case 9986: // GL_NEAREST_MIPMAP_LINEAR
        return TextureMinFilter.nearestMipmapLinear;
    case 9987: // GL_LINEAR_MIPMAP_LINEAR
        return TextureMinFilter.linearMipmapLinear;
    default:
        return TextureMinFilter.unspecified;
    }
}

/// Map a glTF/OpenGL wrap (address) mode constant to the engine `TextureWrap`.
private TextureWrap mapWrap(long glWrap) {
    switch (glWrap) {
    case 10_497: // GL_REPEAT
        return TextureWrap.repeat;
    case 33_071: // GL_CLAMP_TO_EDGE
        return TextureWrap.clampToEdge;
    case 33_648: // GL_MIRRORED_REPEAT
        return TextureWrap.mirroredRepeat;
    default:
        return TextureWrap.unspecified;
    }
}

/**
 * Decoded contents of a glTF accessor, expressed as floats.
 *
 * Integer component types are converted to float, applying normalization when
 * the accessor is flagged `normalized`. `values` is laid out row-major:
 * `values[i * componentCount + c]` is component `c` of element `i`.
 */
private struct AccessorData {
    float[] values;
    size_t componentCount;
    size_t count;
}

/// Read a floating-point accessor (POSITION, COLOR_0, TEXCOORD_n, ...).
private AccessorData readFloatAccessor(ref JSONValue gltf, const(ubyte)[][] buffers, size_t accessorIndex) {
    JSONValue acc = gltf["accessors"].array[accessorIndex];
    auto bufferViewP = "bufferView" in acc.object;
    if (bufferViewP is null) {
        throw new Exception("Sparse accessors (no bufferView) are not supported.");
    }

    int componentType = cast(int) jsonInt(acc["componentType"]);
    size_t count = cast(size_t) jsonInt(acc["count"]);
    string type = acc["type"].str;
    bool normalized = optBool(acc, "normalized", false);
    size_t accessorByteOffset = cast(size_t) optInt(acc, "byteOffset", 0);

    JSONValue bufferView = gltf["bufferViews"].array[cast(size_t) jsonInt(*bufferViewP)];
    const(ubyte)[] buffer = buffers[cast(size_t) jsonInt(bufferView["buffer"])];
    size_t bufferViewByteOffset = cast(size_t) optInt(bufferView, "byteOffset", 0);
    size_t byteStride = cast(size_t) optInt(bufferView, "byteStride", 0);

    size_t numComponents = typeComponentCount(type);
    size_t componentSize = componentByteSize(componentType);
    size_t elementSize = numComponents * componentSize;
    size_t stride = byteStride != 0 ? byteStride : elementSize;
    size_t base = bufferViewByteOffset + accessorByteOffset;

    if (count > 0 && base + (count - 1) * stride + elementSize > buffer.length) {
        throw new Exception("Accessor reads past the end of its buffer.");
    }

    AccessorData result;
    result.componentCount = numComponents;
    result.count = count;
    result.values = new float[count * numComponents];
    for (size_t i = 0; i < count; i++) {
        size_t elementOffset = base + i * stride;
        for (size_t c = 0; c < numComponents; c++) {
            result.values[i * numComponents + c] =
                readComponentAsFloat(buffer, elementOffset + c * componentSize, componentType, normalized);
        }
    }

    return result;
}

/// Read an index accessor into a flat list of vertex indices.
private uint[] readIndexAccessor(ref JSONValue gltf, const(ubyte)[][] buffers, size_t accessorIndex) {
    JSONValue acc = gltf["accessors"].array[accessorIndex];
    auto bufferViewP = "bufferView" in acc.object;
    if (bufferViewP is null) {
        throw new Exception("Index accessor without a bufferView is not supported.");
    }

    int componentType = cast(int) jsonInt(acc["componentType"]);
    size_t count = cast(size_t) jsonInt(acc["count"]);
    size_t accessorByteOffset = cast(size_t) optInt(acc, "byteOffset", 0);

    JSONValue bufferView = gltf["bufferViews"].array[cast(size_t) jsonInt(*bufferViewP)];
    const(ubyte)[] buffer = buffers[cast(size_t) jsonInt(bufferView["buffer"])];
    size_t bufferViewByteOffset = cast(size_t) optInt(bufferView, "byteOffset", 0);
    size_t componentSize = componentByteSize(componentType);
    size_t base = bufferViewByteOffset + accessorByteOffset;

    if (count > 0 && base + count * componentSize > buffer.length) {
        throw new Exception("Index accessor reads past the end of its buffer.");
    }

    uint[] result = new uint[count];
    for (size_t i = 0; i < count; i++) {
        size_t offset = base + i * componentSize;
        switch (componentType) {
        case 5121:
            result[i] = buffer.peek!(ubyte, Endian.littleEndian)(offset);
            break;
        case 5123:
            result[i] = buffer.peek!(ushort, Endian.littleEndian)(offset);
            break;
        case 5125:
            result[i] = buffer.peek!(uint, Endian.littleEndian)(offset);
            break;
        default:
            throw new Exception(
                "Unsupported index componentType " ~ componentType.to!string ~ ".");
        }
    }

    return result;
}

/// Read a single component from a buffer and convert it to float per the glTF rules.
private float readComponentAsFloat(const(ubyte)[] buffer, size_t offset, int componentType, bool normalized) {
    switch (componentType) {
    case 5126: // FLOAT
        return buffer.peek!(float, Endian.littleEndian)(offset);
    case 5121: // UNSIGNED_BYTE
        ubyte ub = buffer.peek!(ubyte, Endian.littleEndian)(offset);
        return normalized ? ub / 255.0f : cast(float) ub;
    case 5123: // UNSIGNED_SHORT
        ushort us = buffer.peek!(ushort, Endian.littleEndian)(offset);
        return normalized ? us / 65_535.0f : cast(float) us;
    case 5120: // BYTE
        byte b = buffer.peek!(byte, Endian.littleEndian)(offset);
        return normalized ? fmaxf(b / 127.0f, -1.0f) : cast(float) b;
    case 5122: // SHORT
        short s = buffer.peek!(short, Endian.littleEndian)(offset);
        return normalized ? fmaxf(s / 32_767.0f, -1.0f) : cast(float) s;
    case 5125: // UNSIGNED_INT
        return cast(float) buffer.peek!(uint, Endian.littleEndian)(offset);
    default:
        throw new Exception(
            "Unsupported accessor componentType " ~ componentType.to!string ~ ".");
    }
}

/// Byte size of a glTF accessor component type.
private size_t componentByteSize(int componentType) {
    switch (componentType) {
    case 5120:
    case 5121:
        return 1;
    case 5122:
    case 5123:
        return 2;
    case 5125:
    case 5126:
        return 4;
    default:
        throw new Exception(
            "Unsupported accessor componentType " ~ componentType.to!string ~ ".");
    }
}

/// Number of components in a glTF accessor element type ("VEC3" -> 3, ...).
private size_t typeComponentCount(string type) {
    switch (type) {
    case "SCALAR":
        return 1;
    case "VEC2":
        return 2;
    case "VEC3":
        return 3;
    case "VEC4":
        return 4;
    case "MAT2":
        return 4;
    case "MAT3":
        return 9;
    case "MAT4":
        return 16;
    default:
        throw new Exception("Unsupported accessor type '" ~ type ~ "'.");
    }
}

private float fmaxf(float a, float b) {
    return a > b ? a : b;
}

private bool startsWith(string value, string prefix) {
    return value.length >= prefix.length && value[0 .. prefix.length] == prefix;
}

/// Read a JSON number as a `long`, accepting integer, unsigned, or float storage.
private long jsonInt(JSONValue value) {
    switch (value.type) {
    case JSONType.integer:
        return value.integer;
    case JSONType.uinteger:
        return cast(long) value.uinteger;
    case JSONType.float_:
        return cast(long) value.floating;
    default:
        throw new Exception("Expected a JSON number.");
    }
}

/// Returns true when the JSON object has a field under `key`.
private bool hasKey(JSONValue obj, string key) {
    return (key in obj.object) !is null;
}

/// Fetch an optional integer field from a JSON object, falling back to `defaultValue`.
private long optInt(JSONValue obj, string key, long defaultValue) {
    auto p = key in obj.object;
    return p is null ? defaultValue : jsonInt(*p);
}

/// Fetch an optional boolean field from a JSON object, falling back to `defaultValue`.
private bool optBool(JSONValue obj, string key, bool defaultValue) {
    auto p = key in obj.object;
    if (p is null) {
        return defaultValue;
    }

    return p.type == JSONType.true_;
}

/// Fetch an optional string field from a JSON object, falling back to `defaultValue`.
private string optStr(JSONValue obj, string key, string defaultValue) {
    auto p = key in obj.object;
    return p is null ? defaultValue : p.str;
}
