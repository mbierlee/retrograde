/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2021 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.core.math;

import std.math : sqrt, atan2, PI, stdround = round;
import std.conv : to;
import std.string : join;

alias scalar = double;

/**
 * Implementation of a euclideon vector.
 */
struct Vector(T, uint N) if (N > 0) {
    //TODO: In these methods a lot of vectors can be passed by reference, since they're const.
    private T[N] components;

    public alias _N = N;
    public alias _T = T;

    /**
     * Create new vector with all components set to the same value.
     *
     * Params:
     *  val = Value to use for all components.
     */
    this(T val) {
        this.components[0 .. N] = val;
    }

    /**
     * Create new vector with each component individually defined.
     *
     * The amount of supplied components must match the amount of components
     * the vector has.
     *
     * Params:
     *  components = Each individual component.
     *
     * Throws: AssertionError when amount of supplied components is not the same as that of the vector.
     */
    this(const T[] components...) {
        assert(components.length == N,
                "Cannot initialize a vector with a different amount of components than available.");
        this.components = components;
    }

    static if (N >= 2) {
        /**
         * Constructs a vector from a smaller vector and an extra.
         *
         * The smaller vector must exactly be one component smaller. For example:
         * you can supply a Vector2U and an extra component to create a Vector3U.
         *
         * Example:
         * ---
         * auto v = Vector3U(Vector2U(1, 2), 3);
         * ---
         *
         * Params:
         *  smallerVector = A vector that is one component smaller than the current.
         *  extraComponent = Value of the extra component to be added.
         */
        this(Vector!(T, N - 1) smallerVector, T extraComponent) {
            this.components = smallerVector.components ~ [extraComponent];
        }
    }

    /**
     * Shortcut to the first component of the vector.
     */
    public @property T x() const {
        return components[0];
    }

    /**
     * Sets the first component of the vector.
     */
    public @property void x(T x) {
        components[0] = x;
    }

    static if (N >= 2) {
        /**
         * Shortcut to the second component of the vector.
         */
        public @property T y() const {
            return components[1];
        }

        /**
         * Sets the second component of the vector.
         */
        public @property void y(const T y) {
            components[1] = y;
        }
    }

    static if (N >= 3) {
        /**
         * Shortcut to the third component of the vector.
         */
        public @property T z() const {
            return components[2];
        }

        /**
         * Sets the third component of the vector.
         */
        public @property void z(const T z) {
            components[2] = z;
        }
    }

    static if (N >= 4) {
        /**
         * Shortcut to the second component of the vector.
         */
        public @property T w() const {
            return components[3];
        }

        /**
         * Sets the third component of the vector.
         */
        public @property void w(const T w) {
            components[3] = w;
        }
    }

    static if (N >= 2) {
        /**
         * Returns a normalized version of this vector.
         *
         * The current vector is not changed.
         */
        public Vector normalize() const {
            // Prevent magnitude calculation over and over
            auto const currentMagnitude = magnitude;

            if (currentMagnitude == 0) {
                return Vector(0);
            }

            if (currentMagnitude == 1) {
                return this;
            }

            Vector normalizedVector;
            foreach (i; 0 .. N) {
                normalizedVector[i] = cast(T)(this[i] / currentMagnitude);
            }

            return normalizedVector;
        }
    }

    static if (N >= 2) {
        alias length = magnitude;

        /**
         * Calculates the magnitude, or length, of the vector.
         */
        public @property scalar magnitude() const {
            scalar powSum = 0;
            foreach (component; components) {
                powSum += component * component;
            }

            return sqrt(powSum);
        }
    }

    /**
     * Rounds off all components of this vector to the nearest integer value.
     */
    public void round() {
        foreach (i, component; components) {
            components[i] = cast(T) stdround(component);
        }
    }

    static if (N == 2) {
        /**
         * Returns the angle in degrees of this vector in two-dimentionsal space.
         */
        public @property scalar angle() const {
            auto angle = atan2(cast(scalar) y, cast(scalar) x);
            if (angle < 0) {
                angle = (2 * PI) + angle;
            }
            return angle;
        }
    }

    /**
     * Returns an inverse copy of this vector.
     */
    Vector opUnary(string s)() const if (s == "-") {
        return this * -1;
    }

    /**
     * Returns a copy of this and another vector added/substracted together.
     */
    Vector opBinary(string op)(const Vector rhs) const 
            if (rhs._N == N && (op == "+" || op == "-")) {
        Vector vec;
        foreach (i; 0 .. N) {
            mixin("vec[i] = cast(T) (components[i] " ~ op ~ " rhs[i]);");
        }

        return vec;
    }

    /**
     * Returns a copy of this vector multiplied/divided by the given scalar.
     */
    Vector opBinary(string op)(const scalar rhs) const if (op == "*" || op == "/") {
        Vector vec;
        foreach (i; 0 .. N) {
            mixin("vec[i] = cast(T) (components[i] " ~ op ~ " rhs);");
        }

        return vec;
    }

    /**
     * Returns a copy of this vector multiplied/divided by the given scalar.
     */
    Vector opBinaryRight(string op)(const scalar lhs) const if (op == "*") {
        return this * lhs;
    }

    bool opEquals()(auto ref const Vector other) const if (other._N == N) {
        foreach (i; 0 .. N) {
            if (this[i] != other[i]) {
                return false;
            }
        }
        return true;
    }

    ulong toHash() const nothrow @trusted {
        static if (N >= 2) {
            auto const currentMagnitude = this.magnitude;
        } else {
            auto const currentMagnitude = 1;
        }

        scalar hash = currentMagnitude + 1;
        for (uint i = 0; i < components.length; i++) {
            hash *= components[i] * i + 1;
        }

        return cast(ulong)(hash / currentMagnitude);
    }

    /**
     * Calculates the dot product of two vectors.
     */
    T dot()(const Vector other) const if (other._N == N) {
        T dotProduct = 0;
        foreach (i; 0 .. N) {
            dotProduct += this[i] * other[i];
        }
        return dotProduct;
    }

    /**
     * Calculates the cross product of two vectors.
     */
    Vector cross()(const Vector other) const if (N == 3 && other._N == N) {
        // dfmt off
        return Vector(
            (this.y * other.z) - (this.z * other.y),
            (this.z * other.x) - (this.x * other.z),
            (this.x * other.y) - (this.y * other.x)
        );
        // dftm on
    }

    /**
     * Returns a vector perpendicular to this one and a normal, essentially
     * the reflection off the normal.
     *
     * Params:
     *  normal = A normal used to determine the direction of the reflection.
     */
    Vector reflect()(const Vector normal) const if (N >= 2 && normal._N == N) {
        auto const normalizedNormal = normal.normalize();
        return this - ((2 * normalizedNormal).dot(this) * normalizedNormal);
    }

    /**
     * Returns a vector that refractos off of this vector and a normal.
     *
     * Params:
     *  refractionIndex = Intensity of the refraction.
     *  normal = A normal used to determine the direction of the reflection.
     */
    Vector refract()(const T refractionIndex, const Vector normal) const if (N >= 2 && normal._N == N) {
        auto const normalizedThis = this.normalize();
        auto const normalizedNormal = normal.normalize();
        auto const dotProduct = normalizedNormal.dot(normalizedThis);
        auto const k = 1 - (refractionIndex * refractionIndex) * (1 - (dotProduct * dotProduct));
        if (k < 0) {
            return Vector(0);
        }

        return refractionIndex * normalizedThis - (
                refractionIndex * normalizedNormal.dot(normalizedThis) + sqrt(k)) * normalizedNormal;
    }

    /**
     * Cast vector type into another vector type. 
     *
     * When the target type is bigger, extra components are set to their default init.
     * When the target type is smaller, components are lost.
     */
    TargetVectorType opCast(TargetVectorType)() const if (TargetVectorType._N == N)  {
        auto resultVector = TargetVectorType();
        foreach (i; 0 .. N) {
            resultVector[i] = cast(TargetVectorType._T) this[i];
        }
        return resultVector;
    }

    /**
     * Return specific component of this vector.
     */
    T opIndex(size_t index) const {
        return components[index];
    }

    /**
     * Assign specific component of this vector.
     */
    T opIndexAssign(T value, size_t index) {
        return components[index] = value;
    }

    string toString() const {
        string[] componentStrings;

        foreach (i; 0 .. N) {
            componentStrings ~= to!string(this[i]);
        }

        return "(" ~ componentStrings.join(", ") ~ ")";
    }

    static if (N >= 2) {
        /**
         * Returns a copy of this vector that has one component less.
         */
        public Vector!(T, N - 1) downgrade() const {
            return Vector!(T, N - 1)(this.components[0 .. $ - 1]);
        }
    }
}

alias Vector2I = Vector!(int, 2);
alias Vector2U = Vector!(uint, 2);
alias Vector2L = Vector!(long, 2);
alias Vector2UL = Vector!(ulong, 2);
alias Vector2F = Vector!(float, 2);
alias Vector2D = Vector!(double, 2);
alias Vector2R = Vector!(real, 2);

alias Vector3I = Vector!(int, 3);
alias Vector3U = Vector!(uint, 3);
alias Vector3L = Vector!(long, 3);
alias Vector3UL = Vector!(ulong, 3);
alias Vector3F = Vector!(float, 3);
alias Vector3D = Vector!(double, 3);
alias Vector3R = Vector!(real, 3);

alias Vector4D = Vector!(double, 4);

// Vector tests
version (unittest) {
    import std.math.operations : isClose;

    @("Create vector with two components")
    unittest {
        auto const vector = Vector2U(1, 2);

        assert(1 == vector.x);
        assert(2 == vector.y);
    }

    @("Negate vector with two components")
    unittest {
        auto const vector = Vector2U(1, 2);
        auto const negatedVector = -vector;

        assert(-1 == negatedVector.x);
        assert(-2 == negatedVector.y);
    }

    @("Add vectors with two components")
    unittest {
        auto const vector1 = Vector2U(1, 2);
        auto const vector2 = Vector2U(4, 8);
        auto const addedVector = vector1 + vector2;

        assert(5 == addedVector.x);
        assert(10 == addedVector.y);
    }

    @("Subtract vectors with two components")
    unittest {
        auto const vector1 = Vector2U(2, 8);
        auto const vector2 = Vector2U(1, 4);
        auto const subbedVector = vector1 - vector2;

        assert(1 == subbedVector.x);
        assert(4 == subbedVector.y);
    }

    @("Multiply vectors with two components by scalar")
    unittest {
        auto const vector = Vector2U(2, 8);
        auto const  multipliedVector = vector * 2;

        assert(4 == multipliedVector.x);
        assert(16 == multipliedVector.y);
    }

    @("Multiply vectors with two components by left-hand scalar")
    unittest {
        auto const vector = Vector2U(2, 8);
        auto const multipliedVector = 2 * vector;

        assert(4 == multipliedVector.x);
        assert(16 == multipliedVector.y);
    }

    @("Calculate magnitude of vector with two components")
    unittest {
        auto const vector = Vector2U(5, 6);

        assert(isClose(cast(scalar) 7.81025, vector.magnitude, 1e-6));
    }

    @("Compare two vectors with two components")
    unittest {
        auto const vector1 = Vector2U(5, 6);
        auto const vector2 = Vector2U(5, 6);

        assert(vector1 == vector2);
    }

    @("Cast vector with two component")
    unittest {
        auto vector = cast(Vector2U) Vector2D(1.5, 6);

        assert(vector.x == 1);
        assert(vector.y == 6);
    }

    @("Create vector with three components")
    unittest {
        auto const vector = Vector3U(1, 2, 3);

        assert(1 == vector.x);
        assert(2 == vector.y);
        assert(3 == vector.z);
    }

    @("Negate vector with three components")
    unittest {
        auto const vector = Vector3U(1, 2, 3);
        auto const negatedVector = -vector;

        assert(-1 == negatedVector.x);
        assert(-2 == negatedVector.y);
        assert(-3 == negatedVector.z);
    }

    @("Add vectors with three components")
    unittest {
        auto const vector1 = Vector3U(1, 2, 3);
        auto const vector2 = Vector3U(4, 8, 2);
        auto const addedVector = vector1 + vector2;

        assert(5 == addedVector.x);
        assert(10 == addedVector.y);
        assert(5 == addedVector.z);
    }

    @("Subtract vectors with three components")
    unittest {
        auto const vector1 = Vector3U(2, 8, 7);
        auto const vector2 = Vector3U(1, 4, 5);
        auto const subbedVector = vector1 - vector2;

        assert(1 == subbedVector.x);
        assert(4 == subbedVector.y);
        assert(2 == subbedVector.z);
    }

    @("Multiply vectors with three components by scalar")
    unittest {
        auto const vector = Vector3U(2, 8, 4);
        auto const multipliedVector = vector * 2;

        assert(4 == multipliedVector.x);
        assert(16 == multipliedVector.y);
        assert(8 == multipliedVector.z);
    }

    @("Multiply vectors with three components by left-hand scalar")
    unittest {
        auto const vector = Vector3U(2, 8, 4);
        auto const multipliedVector = 2 * vector;

        assert(4 == multipliedVector.x);
        assert(16 == multipliedVector.y);
        assert(8 == multipliedVector.z);
    }

    @("Magnitude of vector with three components")
    unittest {
        auto vector = Vector3U(5, 6, 8);
        auto expectedMagnitude = cast(scalar) 11.1803;

        assert(isClose(expectedMagnitude, vector.magnitude, 1e-5));
        assert(isClose(expectedMagnitude, vector.length, 1e-5));
    }

    @("Compare two vectors with three components")
    unittest {
        auto const vector1 = Vector3U(5, 6, 7);
        auto const vector2 = Vector3U(5, 6, 7);

        assert(vector1 == vector2);
    }

    @("Cast vector with three components")
    unittest {
        auto vector = cast(Vector3U) Vector3D(1.5, 6, 9.88);

        assert(vector.x == 1);
        assert(vector.y == 6);
        assert(vector.z == 9);
    }

    @("Create vector by setting all components")
    unittest {
        auto const vector = Vector3U(5);

        assert(5 == vector.x);
        assert(5 == vector.y);
        assert(5 == vector.z);
    }

    @("Normalize vector")
    unittest {
        auto const vector = Vector2D(10, 6);
        auto const normalizedVector = vector.normalize();

        assert(isClose(normalizedVector.magnitude, 1));
    }

    @("Normalize vector that has length below 1")
    unittest {
        auto const vector = Vector2D(0.2, 0.2);
        auto const normalizedVector = vector.normalize();

        assert(isClose(normalizedVector.magnitude, 1));
    }

    @("Normalize vector with length of 0")
    unittest {
        auto const vector = Vector2D(0);
        auto const normalizedVector = vector.normalize();

        assert(normalizedVector.magnitude == 0);
    }

    @("Calculate angle of two dimensional vector")
    unittest {
        auto const vector = Vector2D(1, 0);
        assert(0 == vector.angle);
    }

    @("Create vector with four components")
    unittest {
        auto const vector = Vector4D(1, 2, 3, 4);

        assert(1 == vector.x);
        assert(2 == vector.y);
        assert(3 == vector.z);
        assert(4 == vector.w);
    }

    @("Calculate dot product")
    unittest {
        auto const vector1 = Vector3D(1, 2, 3);
        auto const vector2 = Vector3D(4, 5, 6);

        auto dotProduct = vector1.dot(vector2);
        assert(32 == dotProduct);

        auto const vector3 = Vector3D(77, 88, 99);
        auto const vector4 = Vector3D(5, 3, 2);

        dotProduct = vector3.dot(vector4);
        assert(847 == dotProduct);
    }

    @("Calculate cross product")
    unittest {
        auto const vector1 = Vector3D(3, 4, 5);
        auto const vector2 = Vector3D(7, 8, 9);
        auto const expectedCrossProduct = Vector3D(-4, 8, -4);
        auto const actualCrossProduct = vector1.cross(vector2);

        assert(expectedCrossProduct == actualCrossProduct);
    }

    @("Calculate reflection vector")
    unittest {
        auto const vector = Vector3D(6, 2, 3);
        auto const normal = Vector3D(0, 1, 0);
        auto const expectedVector = Vector3D(6, -2, 3);
        auto const actualVector = vector.reflect(normal);

        assert(expectedVector == actualVector);
    }

    @("Calculate refraction vector")
    unittest {
        auto const vector = Vector3D(1, -1, 0);
        auto const normal = Vector3D(0, 1, 0);
        auto const expectedVector = Vector3D(0.707107, -0.707107, 0);
        auto const actualVector = vector.refract(1, normal);

        assert(to!string(expectedVector) == to!string(actualVector));
    }

    @("Create vector with extra dimension")
    unittest {
        auto const originalVector = Vector2D(1, 2);
        auto const expectedExpandedVector = Vector3D(1, 2, 3);
        auto const actualExpandedVector = Vector3D(originalVector, 3);

        assert(expectedExpandedVector == actualExpandedVector);
    }

    @("Downgrade vector")
    unittest {
        auto const originalVector = Vector3D(1, 2, 3);
        auto const expectedVector = Vector2D(1, 2);
        auto const actualVector = originalVector.downgrade();

        assert(expectedVector == actualVector);
    }

    @("Modify vector components by aliases")
    unittest {
        auto vector = Vector2D(1, 2);
        vector.x = 3;
        vector.y = 4;

        assert(vector == Vector2D(3, 4));
    }

    @("Modify vector components by array index")
    unittest {
        auto vector = Vector2D(1, 2);
        vector[0] = 3;
        vector[1] = 4;

        assert(vector == Vector2D(3, 4));
    }

    @("Convert vectors to string representation")
    unittest {
        assert("(1)" == Vector!(double, 1)(1).toString());
        assert("(1, 2)" == Vector2D(1, 2).toString());
        assert("(1, 2, 3)" == Vector3D(1, 2, 3).toString());
        assert("(5)" == Vector!(int, 1)(5).toString());
        assert("(5, 6)" == Vector2I(5, 6).toString());
        assert("(5, 6, 7)" == Vector3I(5, 6, 7).toString());
        assert("(0, 0, 0)" == Vector3D(0).toString());

        assert("(1.6)" == Vector!(double, 1)(1.6).toString());
        assert("(1.84, 2.4)" == Vector2D(1.84, 2.4).toString());
        assert("(1.3, 2.75, 3.782)" == Vector3D(1.3, 2.75, 3.782).toString());
    }

    @("To hash")
    unittest {
        auto const vector1Hash = Vector2D(1.2, 3.4).toHash;
        auto const vector2Hash = Vector2D(1.2, 3.4).toHash;
        auto const vector3Hash = Vector3U(1, 2, 3).toHash;
        auto const vector4Hash = Vector!(ulong, 1)(7).toHash;
        auto const vector5Hash = Vector3U(3, 2, 1).toHash;

        assert(vector1Hash == vector2Hash);
        assert(vector2Hash != vector3Hash);
        assert(vector3Hash != vector4Hash);
        assert(vector3Hash != vector5Hash);
    }
}
