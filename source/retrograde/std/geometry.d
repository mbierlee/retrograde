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

import retrograde.std.math : abs, Matrix4, Quaternion, scalar, Vector3;
import retrograde.std.stringid : sid;

/**
 * A $(D Vector3) placing an entity in the world.
 *
 * The world is right-handed and Y-up. An entity without a position sits at the world origin.
 * The position is where the entity's origin goes, the point it is rotated and scaled about.
 * That is also its center unless an $(D OriginOffsetComponentType) moves it aside.
 */
enum PositionComponentType = sid("comp_position");

/**
 * A $(D Quaternion) turning an entity in the world.
 *
 * An unrotated entity faces along the negative Z axis, the way the world does. An entity
 * without an orientation is unrotated. $(D forwardOf) tells which way an orientation faces.
 */
enum OrientationComponentType = sid("comp_orientation");

/**
 * A $(D Vector3) stretching an entity along each of its own axes, before it is rotated.
 *
 * A scale of 1 on every axis leaves an entity its natural size, which is also how an entity
 * without a scale is sized.
 */
enum ScaleComponentType = sid("comp_scale");

/**
 * A $(D Vector3) moving an entity away from its origin, the point at its position that it is
 * rotated and scaled about.
 *
 * The offset is in the entity's own space, so it is turned and stretched along with the
 * entity. An unrotated entity thereby sits beside its position, offset by this much, while
 * turning it swings it around its position instead of spinning it in place, and scaling it
 * pushes it away from its position.
 */
enum OriginOffsetComponentType = sid("comp_origin_offset");

/**
 * An axis-aligned bounding box, kept as its two extreme corners.
 *
 * The corners are the box's native form because the operations a box sees most, overlap
 * tests and unions, work on them directly. The box's center and half extents can be read
 * off it as well, for the operations that want those instead, such as plane tests and
 * transforms.
 *
 * A default box is empty: its corners sit at the origin.
 */
struct Aabb {
    /// The corner with the smallest coordinate on every axis.
    Vector3 min;

    /// The corner with the largest coordinate on every axis.
    Vector3 max;

    /**
     * Creates a box spanning the given corners.
     *
     * Params:
     *  min = The corner with the smallest coordinate on every axis.
     *  max = The corner with the largest coordinate on every axis.
     */
    this(const Vector3 min, const Vector3 max) {
        this.min = min;
        this.max = max;
    }

    /**
     * Returns: A box around the given center, reaching out by the given half extents on each
     * axis.
     */
    static Aabb fromCenter(const Vector3 center, const Vector3 halfExtents) {
        return Aabb(center - halfExtents, center + halfExtents);
    }

    /**
     * Returns: The point halfway between the box's corners.
     */
    Vector3 center() const {
        return (min + max) * 0.5;
    }

    /**
     * Returns: How far the box reaches out from its center along each axis, which is half
     * its size on that axis.
     */
    Vector3 halfExtents() const {
        return (max - min) * 0.5;
    }

    /**
     * Returns: The point of the box nearest to `point`, which is `point` itself when it lies
     * inside the box.
     */
    Vector3 closestPointTo(const Vector3 point) const {
        return Vector3(
            point.x < min.x ? min.x : (point.x > max.x ? max.x : point.x),
            point.y < min.y ? min.y : (point.y > max.y ? max.y : point.y),
            point.z < min.z ? min.z : (point.z > max.z ? max.z : point.z)
        );
    }

    /**
     * Returns: How far `point` is from the box's surface, or zero when it lies inside.
     */
    scalar distanceTo(const Vector3 point) const {
        return (point - closestPointTo(point)).magnitude;
    }

    /**
     * Returns: The smallest axis-aligned box enclosing this box after `transform` is applied
     * to it.
     *
     * The result is a loose fit when the transform rotates: it encloses the turned box, not
     * the turned contents. That is the box's nature, and what keeps this cheap: the center
     * goes through the transform as a point, and each half extent is stretched by the
     * absolute values of the transform's upper-left 3x3, which is the same as projecting
     * all eight corners without visiting any of them.
     */
    Aabb transformedBy(const ref Matrix4 transform) const {
        Vector3 c = center();
        Vector3 h = halfExtents();

        Vector3 newCenter = Vector3(
            transform[0, 0] * c.x + transform[0, 1] * c.y + transform[0, 2] * c.z + transform[0, 3],
            transform[1, 0] * c.x + transform[1, 1] * c.y + transform[1, 2] * c.z + transform[1, 3],
            transform[2, 0] * c.x + transform[2, 1] * c.y + transform[2, 2] * c.z + transform[2, 3]
        );

        Vector3 newHalfExtents = Vector3(
            abs(transform[0, 0]) * h.x + abs(transform[0, 1]) * h.y + abs(transform[0, 2]) * h.z,
            abs(transform[1, 0]) * h.x + abs(transform[1, 1]) * h.y + abs(transform[1, 2]) * h.z,
            abs(transform[2, 0]) * h.x + abs(transform[2, 1]) * h.y + abs(transform[2, 2]) * h.z
        );

        return fromCenter(newCenter, newHalfExtents);
    }

    /**
     * Returns: The smallest box enclosing both this box and the given one.
     *
     * A default box is not treated as empty here: it takes up the origin, so the result
     * reaches out to that too.
     */
    Aabb unionWith(const Aabb other) const {
        return Aabb(
            Vector3(
                min.x < other.min.x ? min.x : other.min.x,
                min.y < other.min.y ? min.y : other.min.y,
                min.z < other.min.z ? min.z : other.min.z
            ),
            Vector3(
                max.x > other.max.x ? max.x : other.max.x,
                max.y > other.max.y ? max.y : other.max.y,
                max.z > other.max.z ? max.z : other.max.z
            )
        );
    }
}

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

    test("A box's center lies halfway between its corners", {
        auto box = Aabb(Vector3(-1, 2, -5), Vector3(3, 4, 1));
        auto center = box.center();

        assert(center.x == 1);
        assert(center.y == 3);
        assert(center.z == -2);
    });

    test("A box's half extents reach from its center to its corners", {
        auto box = Aabb(Vector3(-1, 2, -5), Vector3(3, 4, 1));
        auto halfExtents = box.halfExtents();

        assert(halfExtents.x == 2);
        assert(halfExtents.y == 1);
        assert(halfExtents.z == 3);
    });

    test("A box built from a center and half extents has the matching corners", {
        auto box = Aabb.fromCenter(Vector3(1, 3, -2), Vector3(2, 1, 3));

        assert(box.min.x == -1);
        assert(box.min.y == 2);
        assert(box.min.z == -5);
        assert(box.max.x == 3);
        assert(box.max.y == 4);
        assert(box.max.z == 1);
    });

    test("A default box is empty at the origin", {
        Aabb box;

        assert(box.min == Vector3(0));
        assert(box.max == Vector3(0));
        assert(box.halfExtents() == Vector3(0));
    });

    test("The union of two boxes encloses both", {
        auto box = Aabb(Vector3(-2, -1, 0), Vector3(0, 1, 2));
        auto other = Aabb(Vector3(1, -3, -1), Vector3(3, 0, 1));
        auto merged = box.unionWith(other);

        assert(merged.min == Vector3(-2, -3, -1));
        assert(merged.max == Vector3(3, 1, 2));
    });

    test("The union of a box with one inside it is the box itself", {
        auto box = Aabb(Vector3(-2, -2, -2), Vector3(2, 2, 2));
        auto inner = Aabb(Vector3(-1, -1, -1), Vector3(1, 1, 1));

        assert(box.unionWith(inner) == box);
        assert(inner.unionWith(box) == box);
    });

    test("A point inside a box is at no distance from it", {
        auto box = Aabb(Vector3(-1, -1, -1), Vector3(1, 1, 1));

        assert(box.distanceTo(Vector3(0.5, -0.5, 0)) == 0);
        assert(box.closestPointTo(Vector3(0.5, -0.5, 0)) == Vector3(0.5, -0.5, 0));
    });

    test("A point on a box's surface is at no distance from it", {
        auto box = Aabb(Vector3(-1, -1, -1), Vector3(1, 1, 1));

        assert(box.distanceTo(Vector3(1, 0, 0)) == 0);
    });

    test("A point facing a box's side is as far as that side", {
        auto box = Aabb(Vector3(-1, -1, -1), Vector3(1, 1, 1));

        assert(box.closestPointTo(Vector3(4, 0, 0)) == Vector3(1, 0, 0));
        assert(box.distanceTo(Vector3(4, 0, 0)) == 3);
    });

    test("A point off a box's corner is as far as that corner", {
        auto box = Aabb(Vector3(-1, -1, -1), Vector3(1, 1, 1));

        assert(box.closestPointTo(Vector3(4, 5, 1)) == Vector3(1, 1, 1));
        assert(box.distanceTo(Vector3(4, 5, 1)) == 5);
    });

    test("A translated box moves with the translation", {
        import retrograde.std.math : toTranslationMatrix4;

        auto box = Aabb(Vector3(-1, -2, -3), Vector3(1, 2, 3));
        auto transform = Vector3(10, 20, 30).toTranslationMatrix4();
        auto moved = box.transformedBy(transform);

        assert(moved.min == Vector3(9, 18, 27));
        assert(moved.max == Vector3(11, 22, 33));
    });

    test("A scaled box grows about the origin", {
        import retrograde.std.math : toScalingMatrix4;

        auto box = Aabb(Vector3(0, 0, 0), Vector3(1, 2, 3));
        auto transform = Vector3(2, 3, 4).toScalingMatrix4();
        auto scaled = box.transformedBy(transform);

        assert(scaled.min == Vector3(0, 0, 0));
        assert(scaled.max == Vector3(2, 6, 12));
    });

    test("A box mirrored by a negative scale keeps its corners in order", {
        import retrograde.std.math : toScalingMatrix4;

        auto box = Aabb(Vector3(1, 0, 0), Vector3(3, 1, 1));
        auto transform = Vector3(-1, 1, 1).toScalingMatrix4();
        auto mirrored = box.transformedBy(transform);

        assert(mirrored.min == Vector3(-3, 0, 0));
        assert(mirrored.max == Vector3(-1, 1, 1));
    });

    test("A box turned a quarter swaps the axes it spans", {
        auto box = Aabb(Vector3(-1, -2, -3), Vector3(1, 2, 3));
        auto transform = Quaternion.createRotation(degreesToRadians(90), Vector3(0, 1, 0))
            .toRotationMatrix();
        auto turned = box.transformedBy(transform);

        // A quarter turn about Y takes the Z extent onto X and the X extent onto Z.
        assert(turned.min.x > -3.001 && turned.min.x < -2.999);
        assert(turned.max.x > 2.999 && turned.max.x < 3.001);
        assert(turned.min.y == -2);
        assert(turned.max.y == 2);
        assert(turned.min.z > -1.001 && turned.min.z < -0.999);
        assert(turned.max.z > 0.999 && turned.max.z < 1.001);
    });

    test("A box turned an eighth grows to enclose its turned corners", {
        auto box = Aabb(Vector3(-1, -1, -1), Vector3(1, 1, 1));
        auto transform = Quaternion.createRotation(degreesToRadians(45), Vector3(0, 1, 0))
            .toRotationMatrix();
        auto turned = box.transformedBy(transform);

        // The corners of a unit cube reach sqrt(2) along X and Z once turned by 45 degrees.
        assert(turned.max.x > 1.414 && turned.max.x < 1.415);
        assert(turned.max.z > 1.414 && turned.max.z < 1.415);
        assert(turned.min.x > -1.415 && turned.min.x < -1.414);
        assert(turned.max.y == 1);
    });

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
