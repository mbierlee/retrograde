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

module retrograde.std.math;

version (Native) {
    public import retrograde.native.math;
} else version (WebAssembly) {
    public import retrograde.wasm.math;
}

import retrograde.std.string : String, s, join;
import retrograde.std.conv : to;
import retrograde.std.collections : Array;

alias scalar = float;

enum double PI = 3.141592653589793238462643383279502884197169399375105820974944;

/**
 * A Euclidean vector.
 */
struct Vector(T, uint N) if (N > 0) {
    //TODO: In these methods a lot of vectors can be passed by reference, since they're const.

    private T[N] components;

    alias _N = N;
    alias _T = T;

    static if (N >= 2) {
        private static Vector!(T, N) _upVector;

        /**
         * Returns the engine's standard up vector, which is +y.
         */
        static upVector() {
            if (_upVector[1] != 1) {
                _upVector = Vector!(T, N)(0);
                _upVector[1] = 1;
            }

            return _upVector;
        }
    }

    /**
     * Create new vector with all components set to the same value.
     *
     * Params:
     *  val = Value to use for all components.
     */
    this(const T val) {
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
            static foreach (i; 0 .. N - 1) {
                this.components[i] = smallerVector.components[i];
            }

            this.components[$ - 1] = extraComponent;
        }
    }

    /**
     * Shortcut to the first component of the vector.
     */
    T x() const {
        return components[0];
    }

    /**
     * Sets the first component of the vector.
     */
    void x(T x) {
        components[0] = x;
    }

    static if (N >= 2) {
        /**
         * Shortcut to the second component of the vector.
         */
        T y() const {
            return components[1];
        }

        /**
         * Sets the second component of the vector.
         */
        void y(const T y) {
            components[1] = y;
        }
    }

    static if (N >= 3) {
        /**
         * Shortcut to the third component of the vector.
         */
        T z() const {
            return components[2];
        }

        /**
         * Sets the third component of the vector.
         */
        void z(const T z) {
            components[2] = z;
        }
    }

    static if (N >= 4) {
        /**
         * Shortcut to the second component of the vector.
         */
        T w() const {
            return components[3];
        }

        /**
         * Sets the third component of the vector.
         */
        void w(const T w) {
            components[3] = w;
        }
    }

    static if (N >= 2) {
        /**
         * Returns a normalized version of this vector.
         *
         * The current vector is not changed.
         */
        Vector normalize() const {
            // Prevent magnitude calculation over and over
            auto const currentMagnitude = magnitude;

            if (currentMagnitude == 0) {
                return Vector(0);
            }

            if (currentMagnitude == 1) {
                return this;
            }

            Vector normalizedVector;
            static foreach (i; 0 .. N) {
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
        scalar magnitude() const {
            scalar powSum = 0;
            static foreach (i; 0 .. N) {
                powSum += components[i] * components[i];
            }

            return sqrt(powSum);
        }
    }

    static if (N == 2) {
        /**
         * Returns the angle in degrees of this vector in two-dimentionsal space.
         */
        scalar angle() const {
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
        static foreach (i; 0 .. N) {
            mixin("vec[i] = cast(T) (components[i] " ~ op ~ " rhs[i]);");
        }

        return vec;
    }

    /**
     * Returns a copy of this vector multiplied/divided by the given scalar.
     */
    Vector opBinary(string op)(const scalar rhs) const if (op == "*" || op == "/") {
        Vector vec;
        static foreach (i; 0 .. N) {
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
        static foreach (i; 0 .. N) {
            {
                auto res = components[i] * i + 1;
                hash *= res;
            }
        }

        return cast(ulong)(hash / currentMagnitude);
    }

    /**
     * Calculates the dot product of two vectors.
     */
    T dot()(const Vector other) const if (other._N == N) {
        T dotProduct = 0;
        static foreach (i; 0 .. N) {
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
        // dfmt on
    }

    /**
     * Returns a vector perpendicular to this one and a normal, essentially
     * the reflection off the surface of the normal.
     *
     * Params:
     *  normal = A normal used to determine the direction of the reflection.
     */
    Vector reflect()(const Vector normal) const if (N >= 2 && normal._N == N) {
        auto const normalizedNormal = normal.normalize();
        return this - (((2 * normalizedNormal).dot(this)) * normalizedNormal);
    }

    /**
     * Returns a vector that refractos off of this vector and a normal.
     *
     * Params:
     *  refractionIndex = Intensity of the refraction.
     *  normal = A normal used to determine the direction of the reflection.
     */
    Vector refract()(const T refractionIndex, const Vector normal) const
    if (N >= 2 && normal._N == N) {

        auto const normalizedThis = this.normalize();
        auto const normalizedNormal = normal.normalize();
        auto const dotProduct = normalizedNormal.dot(normalizedThis);
        auto const k = 1 - (refractionIndex * refractionIndex) * (1 - (dotProduct * dotProduct));

        if (k < 0) {
            return Vector(0);
        }

        return refractionIndex * normalizedThis - (refractionIndex * normalizedNormal.dot(
                normalizedThis) + sqrt(k)) * normalizedNormal;
    }

    /** 
     * Returns the interpolation of two vectors by amount t.
     * 
     * Params:
     *  other = The other vector to interpolate with.
     *  t = Interpolation factor between 0 and 1. If t is greater than 1, the result is the same as extrapolate.
     *
     * Returns: A vector that is the result of the interpolation factor. 
     */
    Vector interpolate(const Vector other, scalar t) const {
        return (1 - t) * this + t * other;
    }

    /** 
     * Returns the extrapolation of two vectors by amount t.
     * 
     * Params:
     *  other = The other vector to extrapolate with.
     *  t = Extrapolation factor greater than 1. If t is less than 1, the result is the same as interplate.
     *
     * Returns: A vector that is the result of the extrapolation factor. 
     */
    Vector extrapolate(const Vector other, scalar t) const {
        return interpolate(other, t); // Deal with it
    }

    /**
     * Create a point on a quadratic bezier curve.
     * 
     * The current vector serves as beginning of the curve, control point 1.
     *
     * Params:
     *  B = Apex of curve, control point 2.
     *  C = End of curve, control point 3.
     *  t = Interpolation amount on curve for which to return a point.
     *
     * Returns: Point on curve at t
     */
    Vector quadraticBezierCurvePoint(const Vector B, const Vector C, const scalar t) const {
        auto const D = this.interpolate(B, t);
        auto const E = B.interpolate(C, t);
        return D.interpolate(E, t);
    }

    /**
     * Create a point on a cubic bezier curve.
     * 
     * The current vector serves as beginning of the curve, control point 1.
     *
     * Params:
     *  B = First apex of curve, control point 2.
     *  C = Second apex of curve, control point 3.
     *  D = End of curve, control point 4.
     *  t = Interpolation amount on curve for which to return a point.
     *
     * Returns: Point on curve at t
     */
    Vector cubicBezierCurvePoint(const Vector B, const Vector C, const Vector D, const scalar t) const {
        auto const E = this.interpolate(B, t);
        auto const F = B.interpolate(C, t);
        auto const G = C.interpolate(D, t);
        return E.quadraticBezierCurvePoint(F, G, t);
    }

    /**
     * Cast vector type into another vector type. 
     *
     * When the target type is bigger, extra components are set to their default init.
     * When the target type is smaller, components are lost.
     */
    TargetVectorType opCast(TargetVectorType)() const if (TargetVectorType._N == N) {
        auto resultVector = TargetVectorType();
        static foreach (i; 0 .. N) {
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
        Array!String componentStrings;
        static foreach (i; 0 .. N) {
            componentStrings ~= to!String(this[i]);
        }

        return "(".s ~ componentStrings.join(", ") ~ ")".s;
    }

    static if (N >= 2) {
        /**
         * Returns a copy of this vector that has one component less.
         */
        Vector!(T, N - 1) downgrade() const {
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

alias Vector3I = Vector!(int, 3);
alias Vector3U = Vector!(uint, 3);
alias Vector3L = Vector!(long, 3);
alias Vector3UL = Vector!(ulong, 3);
alias Vector3F = Vector!(float, 3);
alias Vector3D = Vector!(double, 3);

alias Vector4D = Vector!(double, 4);

bool approxEqual(T)(T lhs, T rhs, T deviation = 0.0001)
        if (is(T == float) || is(T == double) || is(T == real)) {
    if (lhs > 0) {
        return (lhs - deviation) < rhs && (lhs + deviation) > rhs;
    } else {
        return (lhs + deviation) > rhs && (lhs - deviation) < rhs;
    }
}

version (UnitTesting)  :  ///
import retrograde.std.test : test, writeSection;

void runMathTests() {
    writeSection("-- Math tests --");

    runMathFunctionsTests();
    runVectorTests();
}

void runMathFunctionsTests() {
    writeSection("-- Math functions tests --");

    test("ceil", {
        assert(ceil(1.0) == 1.0);
        assert(ceil(1.1) == 2.0);
        assert(ceil(1.5) == 2.0);
        assert(ceil(1.9) == 2.0);
        assert(ceil(2.0) == 2.0);
    });

    test("floor", {
        assert(floor(1.0) == 1.0);
        assert(floor(1.1) == 1.0);
        assert(floor(1.5) == 1.0);
        assert(floor(1.9) == 1.0);
        assert(floor(2.0) == 2.0);
    });

    test("pow", {
        assert(pow(10.0, 1.0) == 10.0);
        assert(pow(5.0, 5.0) == 3125.0);
        assert(pow(10.0, 0.0) == 1.0);
    });

    test("approxEqual", {
        assert(approxEqual(0.1, 0.1));
        assert(approxEqual(0.1, 0.10));
        assert(!approxEqual(0.2, 0.1));
        assert(!approxEqual(1, 0.1));

        assert(approxEqual(-0.1, -0.1));
        assert(approxEqual(-0.1, -0.10));
        assert(!approxEqual(-0.2, -0.1));
        assert(!approxEqual(-1, -0.1));
    });
}

void runVectorTests() {
    writeSection("-- Vector tests --");

    test("Create vector with two components", {
        auto const vector = Vector2U(1, 2);
        assert(1 == vector.x);
        assert(2 == vector.y);

        auto const vector2 = Vector2F(1.5, 2.0);
        assert(1.5 == vector2.x);
        assert(2.0 == vector2.y);

        auto const vector3 = Vector2F(1.5);
        assert(1.5 == vector3.x);
        assert(1.5 == vector3.y);

        auto const vector4 = Vector2D(3.5);
        assert(3.5 == vector4.x);
        assert(3.5 == vector4.y);
    });

    test("Negate vector with two components", {
        auto const vector = Vector2I(1, 2);
        auto const negatedVector = -vector;
        assert(-1 == negatedVector.x);
        assert(-2 == negatedVector.y);
    });

    test("Add vectors with two components", {
        auto const vector1 = Vector2U(1, 2);
        auto const vector2 = Vector2U(4, 8);
        auto const addedVector = vector1 + vector2;
        assert(5 == addedVector.x);
        assert(10 == addedVector.y);
    });

    test("Subtract vectors with two components", {
        auto const vector1 = Vector2U(2, 8);
        auto const vector2 = Vector2U(1, 4);
        auto const subbedVector = vector1 - vector2;
        assert(1 == subbedVector.x);
        assert(4 == subbedVector.y);
    });

    test("Multiply vectors with two components by scalar", {
        auto const vector = Vector2U(2, 8);
        auto const multipliedVector = vector * 2;
        assert(4 == multipliedVector.x);
        assert(16 == multipliedVector.y);
    });

    test("Multiply vectors with two components by left-hand scalar", {
        auto const vector = Vector2U(2, 8);
        auto const multipliedVector = 2 * vector;
        assert(4 == multipliedVector.x);
        assert(16 == multipliedVector.y);
    });

    test("Calculate magnitude of vector with two components", {
        auto const vector = Vector2U(5, 6);
        assert(approxEqual(cast(scalar) 7.81025, vector.magnitude, 1e-6));
    });

    test("Compare two vectors with two components", {
        auto const vector1 = Vector2U(5, 6);
        auto const vector2 = Vector2U(5, 6);
        assert(vector1 == vector2);
    });

    test("Cast vector with two component", {
        auto vector = cast(Vector2U) Vector2D(1.5, 6);
        assert(vector.x == 1);
        assert(vector.y == 6);
    });

    test("Create vector with three components", {
        auto const vector = Vector3U(1, 2, 3);
        assert(1 == vector.x);
        assert(2 == vector.y);
        assert(3 == vector.z);

        auto const vector2 = Vector3F(1.5, 2.0, 3.0);
        assert(1.5 == vector2.x);
        assert(2.0 == vector2.y);
        assert(3.0 == vector2.z);

        auto const vector3 = Vector3D(1.5);
        assert(1.5 == vector3.x);
        assert(1.5 == vector3.y);
        assert(1.5 == vector3.z);
    });

    test("Negate vector with three components", {
        auto const vector = Vector3I(1, 2, 3);
        auto const negatedVector = -vector;
        assert(-1 == negatedVector.x);
        assert(-2 == negatedVector.y);
        assert(-3 == negatedVector.z);
    });

    test("Add vectors with three components", {
        auto const vector1 = Vector3U(1, 2, 3);
        auto const vector2 = Vector3U(4, 8, 2);
        auto const addedVector = vector1 + vector2;
        assert(5 == addedVector.x);
        assert(10 == addedVector.y);
        assert(5 == addedVector.z);
    });

    test("Subtract vectors with three components", {
        auto const vector1 = Vector3U(2, 8, 7);
        auto const vector2 = Vector3U(1, 4, 5);
        auto const subbedVector = vector1 - vector2;
        assert(1 == subbedVector.x);
        assert(4 == subbedVector.y);
        assert(2 == subbedVector.z);
    });

    test("Multiply vectors with three components by scalar", {
        auto const vector = Vector3U(2, 8, 4);
        auto const multipliedVector = vector * 2;
        assert(4 == multipliedVector.x);
        assert(16 == multipliedVector.y);
        assert(8 == multipliedVector.z);
    });

    test("Multiply vectors with three components by left-hand scalar", {
        auto const vector = Vector3U(2, 8, 4);
        auto const multipliedVector = 2 * vector;
        assert(4 == multipliedVector.x);
        assert(16 == multipliedVector.y);
        assert(8 == multipliedVector.z);
    });

    test("Magnitude of vector with three components", {
        auto vector = Vector3U(5, 6, 8);
        auto expectedMagnitude = cast(scalar) 11.1803;
        assert(approxEqual(expectedMagnitude, vector.magnitude, 1e-4));
        assert(approxEqual(expectedMagnitude, vector.length, 1e-4));
    });

    test("Compare two vectors with three components", {
        auto const vector1 = Vector3U(5, 6, 7);
        auto const vector2 = Vector3U(5, 6, 7);
        assert(vector1 == vector2);
    });

    test("Cast vector with three components", {
        auto vector = cast(Vector3U) Vector3D(1.5, 6, 9.88);
        assert(vector.x == 1);
        assert(vector.y == 6);
        assert(vector.z == 9);
    });

    test("Create vector by setting all components", {
        auto const vector = Vector3U(5);
        assert(5 == vector.x);
        assert(5 == vector.y);
        assert(5 == vector.z);

        auto const vector2 = Vector3F(5.5);
        assert(5.5 == vector2.x);
        assert(5.5 == vector2.y);
        assert(5.5 == vector2.z);

        auto const vector3 = Vector3D(6.0);
        assert(6.0 == vector3.x);
        assert(6.0 == vector3.y);
        assert(6.0 == vector3.z);
    });

    test("Normalize vector", {
        auto const vector = Vector2D(10, 6);
        auto const normalizedVector = vector.normalize();
        assert(approxEqual(normalizedVector.magnitude, 1));
    });

    test("Normalize vector that has length below 1", {
        auto const vector = Vector2D(0.2, 0.2);
        auto const normalizedVector = vector.normalize();
        assert(approxEqual(normalizedVector.magnitude, 1));
    });

    test("Normalize vector with length of 0", {
        auto const vector = Vector2D(0);
        auto const normalizedVector = vector.normalize();
        assert(normalizedVector.magnitude == 0);
    });

    test("Calculate angle of two dimensional vector", {
        auto const vector = Vector2D(1, 0);
        assert(0 == vector.angle);
    });

    test("Create vector with four components", {
        auto const vector = Vector4D(1, 2, 3, 4);
        assert(1 == vector.x);
        assert(2 == vector.y);
        assert(3 == vector.z);
        assert(4 == vector.w);
    });

    test("Calculate dot product", {
        auto const vector1 = Vector3D(1, 2, 3);
        auto const vector2 = Vector3D(4, 5, 6);
        auto dotProduct = vector1.dot(vector2);
        assert(32 == dotProduct);

        auto const vector3 = Vector3D(77, 88, 99);
        auto const vector4 = Vector3D(5, 3, 2);
        dotProduct = vector3.dot(vector4);
        assert(847 == dotProduct);
    });

    test("Calculate cross product", {
        auto const vector1 = Vector3D(3, 4, 5);
        auto const vector2 = Vector3D(7, 8, 9);
        auto const expectedCrossProduct = Vector3D(-4, 8, -4);
        auto const actualCrossProduct = vector1.cross(vector2);
        assert(expectedCrossProduct == actualCrossProduct);
    });

    test("Calculate reflection vector", {
        auto const vector = Vector3D(6, 2, 3);
        auto const normal = Vector3D(0, 1, 0);
        auto const expectedVector = Vector3D(6, -2, 3);
        auto const actualVector = vector.reflect(normal);
        assert(expectedVector == actualVector);
    });

    test("Calculate refraction vector", {
        auto const vector = Vector3D(1, -1, 0);
        auto const normal = Vector3D(0, 1, 0);
        auto const expectedVector = Vector3D(0.707107, -0.707107, 0);
        auto const actualVector = vector.refract(1, normal);
        assert(expectedVector.toHash == actualVector.toHash);
    });

    test("Create vector with extra dimension", {
        auto const originalVector = Vector2D(1, 2);
        auto const expectedExpandedVector = Vector3D(1, 2, 3);
        auto const actualExpandedVector = Vector3D(originalVector, 3);
        assert(expectedExpandedVector == actualExpandedVector);
    });

    test("Downgrade vector", {
        auto const originalVector = Vector3D(1, 2, 3);
        auto const expectedVector = Vector2D(1, 2);
        auto const actualVector = originalVector.downgrade();
        assert(expectedVector == actualVector);
    });

    test("Modify vector components by component aliases", {
        auto vector = Vector2D(1, 2);
        vector.x = 3;
        vector.y = 4;
        assert(vector == Vector2D(3, 4));
    });

    test("Modify vector components by array index", {
        auto vector = Vector2D(1, 2);
        vector[0] = 3;
        vector[1] = 4;
        assert(vector == Vector2D(3, 4));
    });

    test("Convert vectors to string representation", {
        assert("(1.000000)" == Vector!(double, 1)(1).toString());
        assert("(1.000000, 2.000000)" == Vector2D(1, 2).toString());
        assert("(1.000000, 2.000000, 3.000000)" == Vector3D(1, 2, 3).toString());
        assert("(5)" == Vector!(int, 1)(5).toString());
        assert("(5, 6)" == Vector2I(5, 6).toString());
        assert("(5, 6, 7)" == Vector3I(5, 6, 7).toString());
        assert("(0.000000, 0.000000, 0.000000)" == Vector3D(0).toString());
        assert("(1.600000)" == Vector!(double, 1)(1.6).toString());
        assert("(1.840000, 2.400000)" == Vector2D(1.84, 2.4).toString());
        assert("(1.300000, 2.750000, 3.782000)" == Vector3D(1.3, 2.75, 3.782).toString());
    });

    test("To hash", {
        auto const vector1Hash = Vector2D(1.2, 3.4).toHash;
        auto const vector2Hash = Vector2D(1.2, 3.4).toHash;
        auto const vector3Hash = Vector3U(1, 2, 3).toHash;
        auto const vector4Hash = Vector!(ulong, 1)(7).toHash;
        auto const vector5Hash = Vector3U(3, 2, 1).toHash;

        assert(vector1Hash == vector2Hash);
        assert(vector2Hash != vector3Hash);
        assert(vector3Hash != vector4Hash);
        assert(vector3Hash != vector5Hash);
    });

    test("Interpolate vectors", {
        auto const vector1 = Vector2D(0, 0);
        auto const vector2 = Vector2D(0, 1);
        auto const expectedInterplation1 = Vector2D(0, 0.5);
        auto const actualInterpolation1 = vector1.interpolate(vector2, 0.5);
        assert(actualInterpolation1 == expectedInterplation1);

        auto const vector3 = Vector2D(0, 0);
        auto const vector4 = Vector2D(1, 1);
        auto const expectedInterplation2 = Vector2D(0.5, 0.5);
        auto const actualInterpolation2 = vector3.interpolate(vector4, 0.5);
        assert(actualInterpolation2 == expectedInterplation2);

        auto const vector5 = Vector2D(0, 0);
        auto const vector6 = Vector2D(1, 1);
        auto const expectedInterplation3 = Vector2D(1, 1);
        auto const actualInterpolation3 = vector5.interpolate(vector6, 1);
        assert(actualInterpolation3 == expectedInterplation3);

        auto const vector7 = Vector2D(12, 3);
        auto const vector8 = Vector2D(6, 7);
        auto const expectedInterplation4 = Vector2D(12, 3);
        auto const actualInterpolation4 = vector7.interpolate(vector8, 0);
        assert(actualInterpolation4 == expectedInterplation4);
    });

    test("Extraplate vectors", {
        auto const vector1 = Vector2D(0, 0);
        auto const vector2 = Vector2D(0, 1);
        auto const expectedExtrapolation1 = Vector2D(0, 2);
        auto const aactualExtrapolation1 = vector1.extrapolate(vector2, 2);
        assert(aactualExtrapolation1 == expectedExtrapolation1);

        auto const vector3 = Vector2D(0, 0);
        auto const vector4 = Vector2D(1, 1);
        auto const expectedExtrapolation2 = Vector2D(2, 2);
        auto const aactualExtrapolation2 = vector3.extrapolate(vector4, 2);
        assert(aactualExtrapolation2 == expectedExtrapolation2);

        auto const vector5 = Vector2D(0, 0);
        auto const vector6 = Vector2D(1, 1);
        auto const expectedExtrapolation3 = Vector2D(1, 1);
        auto const aactualExtrapolation3 = vector5.extrapolate(vector6, 1);
        assert(aactualExtrapolation3 == expectedExtrapolation3);

        auto const vector7 = Vector2D(12, 3);
        auto const vector8 = Vector2D(6, 7);
        auto const expectedExtrapolation4 = Vector2D(12, 3);
        auto const aactualExtrapolation4 = vector7.extrapolate(vector8, 0);
        assert(aactualExtrapolation4 == expectedExtrapolation4);

        auto const vector9 = Vector2D(0, 0);
        auto const vector10 = Vector2D(0, 1);
        auto const expectedExtrapolation5 = Vector2D(0, -1);
        auto const aactualExtrapolation5 = vector9.extrapolate(vector10, -1);
        assert(aactualExtrapolation5 == expectedExtrapolation5);
    });

    test("Create point on quadratic bezier curve", {
        auto const A = Vector2D(0, 0);
        auto const B = Vector2D(0.5, 0.5);
        auto const C = Vector2D(1, 0);
        auto const expectedPoint = Vector2D(0.5, 0.25);
        auto const actualPoint = A.quadraticBezierCurvePoint(B, C, 0.5);
        assert(expectedPoint == actualPoint);
    });

    test("Create point on cubic bezier curve", {
        auto const A = Vector2D(0, 0);
        auto const B = Vector2D(0.25, 0.25);
        auto const C = Vector2D(0.75, 0.75);
        auto const D = Vector2D(1, 0);
        auto const expectedPoint = Vector2D(0.5, 0.375);
        auto const actualPoint = A.cubicBezierCurvePoint(B, C, D, 0.5);
        assert(expectedPoint == actualPoint);
    });

    test("Get standard up vector in 2D", {
        auto const expectedUpVector = Vector3D(0, 1, 0);
        auto const actualUpVector = Vector3D.upVector();
        assert(expectedUpVector == actualUpVector);
    });

    test("Get standard up vector in 3D", {
        auto const expectedUpVector = Vector3D(0, 1, 0);
        auto const actualUpVector = Vector3D.upVector();
        assert(expectedUpVector == actualUpVector);
    });
}
