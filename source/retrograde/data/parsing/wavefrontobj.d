/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2023 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.data.parsing.wavefrontobj;

import retrograde.std.storage : File;
import retrograde.std.memory : SharedPtr, makeShared;
import retrograde.std.string : String, StringIterator, split;
import retrograde.std.stringid : StringId, sid;
import retrograde.std.option : Option, some, none;
import retrograde.std.conv : to;

import retrograde.data.model : Model, Mesh, Vertex, Face;

SharedPtr!Model parseWavefrontObjModel(String modelSource, StringId name = "".sid) {
    auto model = makeShared!Model;

    ParseContext ctx;
    ctx.model = model;
    ctx.model.ptr.name = name;
    ctx.iter = StringIterator(modelSource);

    if (ctx.iter.hasNext) {
        startParse(ctx);
    }

    return ctx.model;
}

private struct ParseContext {
    StringIterator iter;
    Option!(SharedPtr!Mesh) currentMesh;
    SharedPtr!Model model;
}

private void startParse(ref ParseContext ctx) {
    import retrograde.std.stdio : writeln; // temp

    while (ctx.iter.hasNext) {
        auto lineType = ctx.parseToNonSpace();
        if (lineType.isEmpty) {
            break;
        }

        switch (lineType.value) {
        case '#':
            ctx.parseToEndLine();
            continue;

        case 'o':
            if (ctx.currentMesh.isDefined) {
                ctx.model.ptr.meshes.add(*ctx.currentMesh.value.ptr);
            }

            ctx.currentMesh = some(makeShared!Mesh);
            ctx.parseToEndLine();
            continue;

        case 'v':
            ctx.parseVertex();
            continue;

        case 'f':
            ctx.parseFace();
            continue;

        default:
            continue;
        }
    }

    if (ctx.currentMesh.isDefined) {
        ctx.model.ptr.meshes.add(*ctx.currentMesh.value.ptr);
    }
}

private Option!char parseToNonSpace(ref ParseContext ctx) {
    return parseTill(ctx, (char c) => c.isSpace);
}

private Option!char parseToEndLine(ref ParseContext ctx) {
    return parseTill(ctx, (char c) => c != '\r' && c != '\n');
}

private void parseVertex(ref ParseContext ctx) {
    ctx.parseToNonSpace();
    ctx.iter.previous();

    auto line = ctx.collectTillEndOfLine();
    if (line.isDefined) {
        auto components = line.value.split(' ');
        auto vertex = Vertex(0, 0, 0, 1, 0, 0, 0, 1);

        if (components.length >= 3) {
            vertex.x = components[0].to!float;
            vertex.y = components[1].to!float;
            vertex.z = components[2].to!float;
        }

        if (components.length == 4) {
            vertex.w = components[3].to!float;
        }

        if (components.length >= 6) {
            vertex.r = components[3].to!float;
            vertex.g = components[4].to!float;
            vertex.b = components[5].to!float;
        }

        ctx.currentMesh.value.ptr.vertices.add(vertex);
    }
}

private void parseFace(ref ParseContext ctx) {
    ctx.parseToNonSpace();
    ctx.iter.previous();

    auto line = ctx.collectTillEndOfLine();
    if (line.isDefined) {
        auto components = line.value.split(' ');
        auto face = Face(0, 0, 0);

        if (components.length == 3) {
            face.vA = components[0].split('/', false)[0].to!size_t;
            face.vB = components[1].split('/', false)[0].to!size_t;
            face.vC = components[2].split('/', false)[0].to!size_t;
        }

        ctx.currentMesh.value.ptr.faces.add(face);
    }
}

private Option!char parseTill(ref ParseContext ctx, bool function(char) conditionFn) {
    auto iter = &ctx.iter;
    auto next = iter.next;
    while (next.isDefined && conditionFn(next.value)) {
        next = iter.next;
    }

    return next;
}

private Option!String collectTillWhitespace(ref ParseContext ctx) {
    return collectTill(ctx, (char c) => !c.isWhite);
}

private Option!String collectTillEndOfLine(ref ParseContext ctx) {
    return collectTill(ctx, (char c) => !c.isEndOfLine);
}

private Option!String collectTill(ref ParseContext ctx, bool function(char) conditionFn) {
    auto iter = &ctx.iter;
    auto next = iter.next;
    if (next.isEmpty) {
        return none!String;
    }

    String str;
    while (next.isDefined && conditionFn(next.value)) {
        str ~= next.value;
        next = iter.next;
    }

    return some(str);
}

private bool isWhite(char c) {
    return isSpace(c) || isEndOfLine(c);
}

private bool isSpace(char c) {
    return c == ' ' || c == '\t';
}

private bool isEndOfLine(char c) {
    return c == '\r' || c == '\n';
}

version (UnitTesting)  :  ///

void runWavefrontObjTests() {
    import retrograde.std.test : test, writeSection;
    import retrograde.std.string : s;
    import retrograde.std.math : approxEqual;

    writeSection("-- Wavefront OBJ tests --");

    test("Parse empty model", {
        auto model = parseWavefrontObjModel("".s);
        assert(model.name == "".sid);
        assert((model.meshes.length == 0));
    });

    test("Parse simple model", {
        auto modelSource = "
            # Blender 3.6.2
            # www.blender.org
            o Cube
            v 1.000000     1.000000     -1.000000 0.9882 1.0000 0.8235
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

        auto model = parseWavefrontObjModel(modelSource.s, "testModel".sid);
        assert(model.name == "testModel".sid);
        assert(model.meshes.length == 1);
        assert(model.meshes[0].vertices.length == 8);
        assert(model.meshes[0].faces.length == 12);

        auto vert0 = model.meshes[0].vertices[0];
        assert(vert0.x.approxEqual(1.0));
        assert(vert0.y.approxEqual(1.0));
        assert(vert0.z.approxEqual(-1.0));
        assert(vert0.w == 1);
        assert(vert0.r.approxEqual(0.9882));
        assert(vert0.g.approxEqual(1.0));
        assert(vert0.b.approxEqual(0.8235));
        assert(vert0.a == 1);

        auto face4 = model.meshes[0].faces[4];
        assert(face4.vA == 1);
        assert(face4.vB == 4);
        assert(face4.vC == 2);
    });

    test("Parse model without vertices and faces", {
        auto modelSource = "
            # Blender 3.6.2
            # www.blender.org
            o Cube
        ";

        auto model = parseWavefrontObjModel(modelSource.s, "testModel".sid);
        assert(model.name == "testModel".sid);
        assert(model.meshes.length == 1);
        assert(model.meshes[0].vertices.length == 0);
        assert(model.meshes[0].faces.length == 0);
    });

    test("Parse model with empty vertices and faces", {
        auto modelSource = "
            # Blender 3.6.2
            # www.blender.org
            o Cube
            v
            f
        ";

        auto model = parseWavefrontObjModel(modelSource.s, "testModel".sid);
        assert(model.name == "testModel".sid);
        assert(model.meshes.length == 1);
        assert(model.meshes[0].vertices.length == 1);
        assert(model.meshes[0].faces.length == 1);

        auto vert0 = model.meshes[0].vertices[0];
        assert(vert0.x == 0);
        assert(vert0.y == 0);
        assert(vert0.z == 0);
        assert(vert0.w == 1);
        assert(vert0.r == 0);
        assert(vert0.g == 0);
        assert(vert0.b == 0);
        assert(vert0.a == 1);

        auto face0 = model.meshes[0].faces[0];
        assert(face0.vA == 0);
        assert(face0.vB == 0);
        assert(face0.vC == 0);
    });
}
