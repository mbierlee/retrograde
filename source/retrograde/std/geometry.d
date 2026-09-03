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

module retrograde.std.geometry;

import retrograde.std.math : Quaternion, Vector3;
import retrograde.std.stringid : sid;

enum PositionComponentType = sid("comp_position");
enum OrientationComponentType = sid("comp_orientation");
enum ScaleComponentType = sid("comp_scale");

/**
 * Returns: The way the given orientation faces, as a unit vector.
 *
 * An orientation looks along its negative Z axis, which is the negated third
 * column of its rotation matrix. An unrotated orientation therefore faces the
 * way the world does, along its negative Z axis.
 */
Vector3 forwardOf(const Quaternion orientation) {
    auto const rotation = orientation.toRotationMatrix();
    return Vector3(-rotation[0, 2], -rotation[1, 2], -rotation[2, 2]);
}

version (UnitTesting)  :  //

import retrograde.std.math : degreesToRadians;
import retrograde.std.test : test, writeSection;

void runGeometryTests() {
    writeSection("-- Geometry tests --");

    test("An unrotated orientation faces the world's negative Z axis", {
        auto forward = forwardOf(Quaternion.init);

        assert(forward.x == 0);
        assert(forward.y == 0);
        assert(forward.z == -1);
    });

    test("A half turn turns the facing around", {
        auto forward = forwardOf(
            Quaternion.createRotation(degreesToRadians(180), Vector3(0, 1, 0)));

        assert(forward.x < 0.001 && forward.x > -0.001);
        assert(forward.y < 0.001 && forward.y > -0.001);
        assert(forward.z > 0.999);
    });

    test("Looking up and down tilts the facing off the ground", {
        auto up = forwardOf(Quaternion.createRotation(degreesToRadians(90), Vector3(1, 0, 0)));

        assert(up.x < 0.001 && up.x > -0.001);
        assert(up.y > 0.999);
        assert(up.z < 0.001 && up.z > -0.001);

        auto down = forwardOf(Quaternion.createRotation(degreesToRadians(-90), Vector3(1, 0, 0)));

        assert(down.x < 0.001 && down.x > -0.001);
        assert(down.y < -0.999);
        assert(down.z < 0.001 && down.z > -0.001);
    });
}
