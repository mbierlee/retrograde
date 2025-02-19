import std.algorithm;
import std.array;
import std.bitmanip;
import std.conv;
import std.range;
import std.stdio;
import std.string;

struct Vertex {
    float x, y, z;
    float r, g, b;
}

struct Face {
    uint[3] indices;
}

struct Mesh {
    Vertex[] vertices;
    Face[] faces;
}

void main() {
    string objFile = "
        # Blender 3.6.2
        # www.blender.org
        o Cube
        v 1.000000 1.000000 -1.000000 0.9882 1.0000 0.8235
        v 1.000000 -1.000000 -1.000000 0.5373 0.7333 1.0000
        v 1.000000 1.000000 1.000000 1.0000 0.3490 0.3372
        v 1.000000 -1.000000 1.000000 0.5608 1.0000 0.6118
        v -1.000000 1.000000 -1.000000 0.5019 0.7176 1.0000
        v -1.000000 -1.000000 -1.000000 1.0000 0.3451 0.3608
        v -1.000000 1.000000 1.000000 0.5608 1.0000 0.6118
        v -1.000000 -1.000000 1.000000 0.9843 1.0000 0.7137
        s 1
        f 5 3 1
        f 3 8 4
        f 7 6 8
        f 2 8 6
        f 1 4 2
        f 5 2 6
        f 5 7 3
        f 3 7 8
        f 7 5 6
        f 2 4 8
        f 1 3 4
        f 5 1 2
    ";

    Mesh mesh = parseOBJ(objFile);
    ubyte[] rgmFile = convertToRGM(mesh);
    writeToByteArray(rgmFile, mesh);
}

Mesh parseOBJ(string objFile) {
    Mesh mesh;
    foreach (line; objFile.splitLines()) {
        string strippedLine = line.strip();
        if (strippedLine.startsWith("v ")) {
            auto parts = line.split;
            Vertex vertex;
            vertex.x = to!float(parts[1]);
            vertex.y = to!float(parts[2]);
            vertex.z = to!float(parts[3]);
            vertex.r = to!float(parts[4]);
            vertex.g = to!float(parts[5]);
            vertex.b = to!float(parts[6]);
            mesh.vertices ~= vertex;
        } else if (strippedLine.startsWith("f ")) {
            auto parts = line.split;
            Face face;
            face.indices[0] = to!uint(parts[1]);
            face.indices[1] = to!uint(parts[2]);
            face.indices[2] = to!uint(parts[3]);
            mesh.faces ~= face;
        }
    }

    return mesh;
}

ubyte[] convertToRGM(in Mesh mesh) {
    ubyte[] rgm;
    rgm ~= cast(ubyte[]) "RGM "; // Magic number
    rgm ~= nativeToLittleEndian(cast(ushort) 1); // Version
    rgm ~= nativeToLittleEndian(cast(uint) 1); // Amount of meshes

    rgm ~= nativeToLittleEndian(cast(uint) mesh.vertices.length); // Vertex count
    rgm ~= nativeToLittleEndian(cast(uint) mesh.faces.length); // Face count

    foreach (vertex; mesh.vertices) {
        rgm ~= nativeToLittleEndian(vertex.y);
        rgm ~= nativeToLittleEndian(vertex.x);
        rgm ~= nativeToLittleEndian(vertex.z);
        rgm ~= nativeToLittleEndian(vertex.r);
        rgm ~= nativeToLittleEndian(vertex.g);
        rgm ~= nativeToLittleEndian(vertex.b);
    }

    foreach (face; mesh.faces) {
        foreach (index; face.indices) {
            rgm ~= nativeToLittleEndian(cast(uint)(index - 1)); // OBJ indices are 1-based
        }
    }

    return rgm;
}

void writeToByteArray(ubyte[] rgmFile, in Mesh mesh) {
    writeln("ubyte[" ~ rgmFile.length.to!string ~ "] rgmFile = [");

    // Header
    writeln("    // Header");
    foreach (ubyte b; rgmFile[0 .. 4]) {
        writef("    0x%02X, ", b);
    }

    writeln();
    writeln();

    // Version
    writeln("    // Version");
    foreach (ubyte b; rgmFile[4 .. 6]) {
        writef("    0x%02X, ", b);
    }

    writeln();
    writeln();

    // Amount of meshes
    writeln("    // Amount of meshes");
    foreach (ubyte b; rgmFile[6 .. 10]) {
        writef("    0x%02X, ", b);
    }

    writeln();
    writeln();

    size_t counter = 0;

    // Vertex count and face count
    writefln("    // Vertex count and face count");
    foreach (ubyte b; rgmFile[10 .. 18]) {
        writef("    0x%02X, ", b);
        counter++;

        if (counter % 4 == 0) {
            writeln();
        }
    }

    writeln();

    // Vertices
    counter = 0;
    writeln("    // Vertices (" ~ mesh.vertices.length.to!string ~ ")");
    foreach (ubyte b; rgmFile[18 .. 18 + mesh.vertices.length * 24]) {
        writef("    0x%02X, ", b);
        counter++;
        if (counter % 24 == 0) {
            writeln();
        }
    }

    writeln();
    writeln();

    // Faces
    counter = 0;
    writeln("    // Faces (" ~ mesh.faces.length.to!string ~ ")");
    foreach (ubyte b; rgmFile[18 + mesh.vertices.length * 24 .. $]) {
        writef("    0x%02X, ", b);
        counter++;
        if (counter % 12 == 0) {
            writeln();
        }
    }

    writeln();
    writeln("];");
}
