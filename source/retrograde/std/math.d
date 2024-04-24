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
import retrograde.std.hash : hashOf;

alias scalar = float;

enum double PI = 3.141592653589793238462643383279502884197169399375105820974944;

/**
 * A Euclidean vector.
 */
struct Vector(T, uint N) if (N > 0) {
    alias _N = N;
    alias _T = T;

    //TODO: In these methods a lot of vectors can be passed by reference, since they're const.

    private T[N] components = 0;

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
        return hashOf(this);
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

/**
 * A vector whose length is always 1.
 */
struct UnitVector(VectorType) {
    private VectorType _vector;

    /**
     * Creates a unit vector from a regular vector. 
     *
     * The supplied vector is automatically normalized.
     */
    this(const VectorType vector) {
        this._vector = vector.normalize();
    }

    /**
     * Creates a unit vector from the supplied components. 
     *
     * The resulting vector is automatically normalized.
     */
    this(const VectorType._T[] components...) {
        assert(components.length == VectorType._N,
            "Cannot initialize a unit vector with a different amount of components than its vector type has.");
        this(VectorType(components));
    }

    /**
     * Return a copy of the regular, normalized vector represented by this unit vector.
     */
    VectorType vector() const {
        return _vector;
    }
}

alias UnitVector2D = UnitVector!Vector2D;
alias UnitVector2F = UnitVector!Vector2F;

alias UnitVector3D = UnitVector!Vector3D;
alias UnitVector3F = UnitVector!Vector3F;

alias UnitVector4D = UnitVector!Vector4D;

/**
 * A matrix!
 *
 * The data is laid out in a row-major order.
 */
struct Matrix(T, uint Rows, uint Columns) if (Rows > 0 && Columns > 0) {
    private T[Columns * Rows] data;

    alias _T = T;
    alias _Rows = Rows;
    alias _Columns = Columns;
    alias _VectorType = Vector!(T, Rows);

    /**
     * Creates a matrix where all its values are set to the initial value.
     *
     * Params:
     *  initialValue = Initial value to set all values to.
     */
    this(const T initialValue) const {
        data[0 .. data.length] = initialValue;
    }

    /**
     * Creates a matrix initializing each values to the given ones.
     *
     * The amount of supplied values needs to be the same as the amount of
     * values that fit in this matrix.
     *
     * Params:
     *  initialValues = Initial values to use for the matrix.
     *
     * Throws: AssertionError when amount of supplied values is not the same as that of the matrix.
     */
    this(const T[] initialValues...) {
        assert(initialValues.length == data.length,
            "Cannot initialize a matrix with a different size of data than available.");
        data = initialValues;
    }

    static if (Rows == Columns) {
        private static Matrix identityMatrix;

        /**
         * Returns an identity matrix.
         */
        static Matrix identity() {
            if (identityMatrix[0] != 1) {
                static foreach (row; 0 .. Rows) {
                    static foreach (column; 0 .. Columns) {
                        identityMatrix[row, column] = column == row ? 1 : 0;
                    }
                }
            }

            return identityMatrix;
        }
    }

    /**
     * Return a value by row and column.
     */
    T opIndex(const size_t row, const size_t column) const {
        return data[row * Columns + column];
    }

    /**
     * Return a value from the matrix by index, where the notion of rows and columns is ignored.
     */
    T opIndex(const size_t index) const {
        return data[index];
    }

    /**
     * Assign a value by row and column.
     */
    T opIndexAssign(const T value, const size_t row, const size_t column) {
        return data[row * Columns + column] = value;
    }

    /**
     * Assign a value to the matrix by index, where the notion of rows and columns is ignored.
     */
    T opIndexAssign(const T value, const size_t index) {
        return data[index] = value;
    }

    /**
     * Returns a copy of this matrix where all values are the inverse.
     */
    Matrix opUnary(string s)() const if (s == "-") {
        return this * -1;
    }

    /**
     * Returns a vector where this matrix is multiplied by a vector.
     */
    _VectorType opBinary(string op)(const _VectorType rhs) const if (op == "*") {
        _VectorType vector = _VectorType(0);
        static foreach (row; 0 .. Rows) {
            static foreach (column; 0 .. Columns) {
                vector[row] = vector[row] + this[row, column] * rhs[column];
            }
        }

        return vector;
    }

    /**
     * Returns a copy of this matrix where all values are multiplied by a scalar.
     */
    Matrix opBinary(string op)(const scalar rhs) const if (op == "*") {
        Matrix matrix;
        static foreach (index; 0 .. Rows * Columns) {
            matrix[index] = this[index] * rhs;
        }

        return matrix;
    }

    /**
     * Returns a copy of this matrix where all values are multiplied by a scalar.
     */
    Matrix opBinaryRight(string op)(const scalar lhs) const if (op == "*") {
        return this * lhs;
    }

    /**
     * Returns a copy of this matrix that is multiplied by another matrix.
     */
    Matrix!(T, Rows, OtherColumns) opBinary(string op, uint OtherRows, uint OtherColumns)(
        const Matrix!(T, OtherRows, OtherColumns) rhs) const
    if (op == "*" && Columns == OtherRows) {

        Matrix!(T, Rows, OtherColumns) resultMatrix;

        uint rowStartIdx;
        T sum;
        static foreach (thisRow; 0 .. Rows) {
            rowStartIdx = thisRow * Columns;
            static foreach (otherColumn; 0 .. OtherColumns) {
                sum = 0;
                foreach (k; 0 .. Columns) {
                    sum += this.data[rowStartIdx + k] * rhs.data[k * OtherColumns + otherColumn];
                }

                resultMatrix.data[rowStartIdx / Columns * OtherColumns + otherColumn] = sum;
            }
        }

        return resultMatrix;
    }

    /**
     * Returns a copy of this matrix that adds or subtracts another matrix.
     */
    Matrix opBinary(string op)(const Matrix rhs) const
    if ((op == "+" || op == "-") && Columns == rhs._Columns && Rows == rhs._Rows) {
        Matrix resultMatrix;
        static foreach (i; 0 .. Rows * Columns) {
            mixin("resultMatrix[i] = this[i] " ~ op ~ " rhs[i];");
        }

        return resultMatrix;
    }

    bool opEquals()(auto ref const Matrix other) const {
        static if (other._Rows != this._Rows || other._Columns != this._Columns) {
            return false;
        } else {
            foreach (i; 0 .. Columns * Rows) {
                if (this.data[i] != other.data[i]) {
                    return false;
                }
            }

            return true;
        }
    }

    ulong toHash() const nothrow @trusted {
        return hashOf(this);
    }

    /**
     * Returns a copy of this matrix whjere all rows and columns are flipped.
     */
    Matrix!(T, Columns, Rows) transpose() const {
        Matrix!(T, Columns, Rows) result;
        static foreach (row; 0 .. Rows) {
            static foreach (column; 0 .. Columns) {
                result.data[column * Rows + row] = cast(T) this.data[row * Columns + column];
            }
        }

        return result;
    }

    /**
     * Returns: a certain row of this matrix as vector.
     */
    Vector!(T, Columns) getRowVector(const size_t row) const {
        return Vector!(T, Columns)(data[row * Columns .. (row * Columns) + Columns]);
    }

    /** 
     * Returns: a certain column of this matrix as vector.
     */
    Vector!(T, Rows) getColumnVector(const size_t col) const {
        Vector!(T, Rows) columnVector;
        for (size_t i = 0; i < Rows; ++i) {
            columnVector[i] = data[i * Columns + col];
        }
        return columnVector;
    }

    /**
     * Returns the values of this matrix as continuous array.
     *
     * The array is row-major.
     */
    CastType[Rows * Columns] getDataArray(CastType = T)() const {
        static if (is(CastType == T)) {
            return data;
        } else {
            CastType[Rows * Columns] newData;
            foreach (size_t i, T item; data) {
                newData[i] = cast(CastType) item;
            }

            return newData;
        }
    }
}

alias Matrix4D = Matrix!(double, 4, 4);
alias Matrix3D = Matrix!(double, 3, 3);
alias Matrix2D = Matrix!(double, 2, 2);

/**
 * A complex mathematical number typically used for rotation.
 * Quaternions prevent gimbal lock.
 */
struct Quaternion(T) {
    alias _T = T;
    alias VectorType = Vector!(T, 3);

    private T realPart = 1;
    private VectorType imaginaryVector = VectorType(0);

    /**
     * The real number component.
     */
    T w() const {
        return realPart;
    }

    /**
     * The x component of the vector of imaginary numbers (a.k.a. bi).
     */
    T x() const {
        return imaginaryVector.x;
    }

    /**
     * The y component of the vector of imaginary numbers (a.k.a. cj).
     */
    T y() const {
        return imaginaryVector.y;
    }

    /**
     * The z component of the vector of imaginary numbers (a.k.a. dk).
     */
    T z() const {
        return imaginaryVector.z;
    }

    /**
     * Construct a quaternion from a real number and the products of real and imaginary numbers.
     * Params:
     *  w = The real number component.
     *  x = The product of b * i.
     *  y = The product of c * j.
     *  z = The product of d * k.
     */
    this(T w, T x, T y, T z) {
        realPart = w;
        imaginaryVector = VectorType(x, y, z);
    }

    /**
     * Construct a quaternion from a real number and an imaginary vector.
     * Params:
     *  r = The real number component.
     *  v = The imaginary vector.
     */
    this(T r, const VectorType v) {
        realPart = r;
        imaginaryVector = v;
    }

    /**
     * Create a quaternion that rotates around a specified axis.
     * Params:
     *  radianAngle = Rotation around the given axis in radians.
     *  axis = Regular three-dimensional axis to rotate around.
     */
    static Quaternion createRotation(double radianAngle, const Vector3D axis) {
        auto normalizedAxis = axis.normalize();
        return Quaternion(
            cos(radianAngle / 2),
            sin(radianAngle / 2) * normalizedAxis.x,
            sin(radianAngle / 2) * normalizedAxis.y,
            sin(radianAngle / 2) * normalizedAxis.z
        );
    }

    /**
     * Multiple two quaternions.
     */
    Quaternion opBinary(string op)(const Quaternion rhs) const if (op == "*") {
        return Quaternion(
            w * rhs.w - x * rhs.x - y * rhs.y - z * rhs.z,
            w * rhs.x + x * rhs.w + y * rhs.z - z * rhs.y,
            w * rhs.y - x * rhs.z + y * rhs.w + z * rhs.x,
            w * rhs.z + x * rhs.y - y * rhs.x + z * rhs.w
        );
    }

    /** 
     * Multiply or divide quaternion by the given scalar.
     */
    Quaternion opBinary(string op)(const scalar rhs) const if (op == "*" || op == "/") {
        return Quaternion(
            mixin("w " ~ op ~ " rhs"),
            mixin("x " ~ op ~ " rhs"),
            mixin("y " ~ op ~ " rhs"),
            mixin("z " ~ op ~ " rhs"),
        );
    }

    /**
     * Calculates the dot product of two quaternions.
     */
    T dot()(const Quaternion other) const {
        return x * other.x + y * other.y + z * other.z + w * other.w;
    }

    /**
     * Convert quaterion to a four-dimensional rotation matrix.
     */
    Matrix4D toRotationMatrix() const {
        // dfmt off
        return Matrix4D(
           1 - 2 * (y * y) - 2 * (z * z), 2 * x * y - 2 * z * w          , (2 * x * z) + (2 * y * w)     , 0,
           2 * x * y + 2 * z * w        , 1 - 2 * (x * x) - 2 * (z * z)  , 2 * y * z - 2 * x * w         , 0,
           2 * x * z - 2 * y * w        , 2 * y * z + 2 * x * w          , 1 - 2 * (x * x)  - 2 * (y * y), 0,
           0                            , 0                              , 0                             , 1
        );
        // dfmt on
    }

    /**
     * Convert quaterion to a vector of Euler angles.
     */
    Vector3D toEulerAngles() const {
        auto q = this;

        auto sqw = q.w * q.w;
        auto sqx = q.x * q.x;
        auto sqy = q.y * q.y;
        auto sqz = q.z * q.z;

        auto unit = sqx + sqy + sqz + sqw;
        auto poleTest = q.x * q.y + q.z * q.w;

        if (poleTest > 0.499 * unit) {
            auto yaw = 2 * atan2(q.x, q.w);
            auto pitch = PI / 2;
            return Vector3D(pitch, yaw, 0);
        }

        if (poleTest < -0.499 * unit) {
            auto yaw = -2 * atan2(q.x, q.w);
            auto pitch = -PI / 2;
            return Vector3D(pitch, yaw, 0);
        }

        auto pitch = atan2(2 * q.x * q.w - 2 * q.y * q.z, -sqx + sqy - sqz + sqw);
        auto yaw = atan2(2 * q.y * q.w - 2 * q.x * q.z, sqx - sqy - sqz + sqw);
        auto roll = asin(2 * poleTest / unit);

        return Vector3D(pitch, yaw, roll);
    }

    /**
     * Calculates the squared Euclidian magnitude of the quaternion.
     */
    scalar magnitudeSquared() const {
        return w * w + x * x + y * y + z * z;
    }

    /**
     * Calculates the Euclidian magnitude of the quaternion.
     */
    scalar magnitude() const {
        return sqrt(magnitudeSquared);
    }

    /** 
     * Returns a normalized form of this Quaternion.
     */
    Quaternion normalize() const {
        return this / magnitude;
    }

    /**
     * Return angle of quaternion in radian.
     */
    scalar angle() const {
        return 2 * acos(w);
    }

    /**
     * Return Euclidian axis of quaternion.
     *
     * In case angle = 0 the axis is (0, 1, 0)
     */
    VectorType axis() const {
        auto q = normalize();
        auto _angle = q.angle;
        if (_angle == 0) {
            return VectorType(0, 1, 0);
        }

        return VectorType(
            q.x / sqrt(1 - q.w * q.w),
            q.y / sqrt(1 - q.w * q.w),
            q.z / sqrt(1 - q.w * q.w)
        );
    }

    /**
     * Returns a new quaternion that is the conjugate of the current.
     */
    Quaternion conjugate() const {
        return Quaternion(w, -x, -y, -z);
    }

    /**
     * Returns a new quaternion that is the inverse of the current.
     */
    Quaternion inverse() const {
        return conjugate / magnitudeSquared;
    }

    string toString() const {
        auto realPartString = (cast(T) realPart).to!String();
        auto vectorString = imaginaryVector.toString().s;
        return "(".s ~ realPartString ~ ", ".s ~ vectorString ~ ")".s;
    }
}

alias QuaternionF = Quaternion!float;
alias QuaternionD = Quaternion!double;

/**
 * Creates a translation matrix from a 2D vector.
 */
Matrix3D toTranslationMatrix(const Vector2D vector) {
    // dfmt off
    return Matrix3D(
        1, 0, vector.x,
        0, 1, vector.y,
        0, 0, 1
    );
    // dfmt on
}

/**
 * Creates a translation matrix from a 3D vector.
 */
Matrix4D toTranslationMatrix(const Vector3D vector) {
    // dfmt off
    return Matrix4D(
        1, 0, 0, vector.x,
        0, 1, 0, vector.y,
        0, 0, 1, vector.z,
        0, 0, 0, 1
    );
    // dfmt on
}

/** 
 * Creates a translation vector from a matrix.
 */
Vector3D toTranslationVector(const Matrix4D matrix) {
    return Vector3D(
        matrix[0, 3],
        matrix[1, 3],
        matrix[2, 3]
    );
}

/**
 * Creates a scaling matrix from a 2D scaling vector.
 */
Matrix3D toScalingMatrix(const Vector2D scalingVector) {
    // dfmt off
    return Matrix3D(
        scalingVector.x, 0              , 0,
        0              , scalingVector.y, 0,
        0              , 0              , 1
    );
    // dfmt on
}

/**
 * Creates a scaling matrix from a 3D scaling vector.
 */
Matrix4D toScalingMatrix(const Vector3D scalingVector) {
    // dfmt off
    return Matrix4D(
        scalingVector.x, 0                 , 0              , 0,
        0              , scalingVector.y   , 0              , 0,
        0              , 0                 , scalingVector.z, 0,
        0              , 0                 , 0              , 1
    );
    // dfmt on
}

/**
 * Creates a rotation matrix around axis defined by x, y and z.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 *  x = X component of the axis to rotate around.
 *  y = Y component of the axis to rotate around.
 *  z = Z component of the axis to rotate around.
 */
Matrix4D createRotationMatrix(const scalar radianAngle, const double x,
    const double y, const double z) {
    const double x2 = x * x;
    const double y2 = y * y;
    const double z2 = z * z;
    auto const cosAngle = cos(radianAngle);
    auto const sinAngle = sin(radianAngle);
    auto const omc = 1.0f - cosAngle;

    // dfmt off
    return Matrix4D(
        x2 * omc + cosAngle       ,   y * x * omc + z * sinAngle,   x * z * omc - y * sinAngle,   0,
        x * y * omc - z * sinAngle,   y2 * omc + cosAngle       ,   y * z * omc + x * sinAngle,   0,
        x * z * omc + y * sinAngle,   y * z * omc - x * sinAngle,   z2 * omc + cosAngle       ,   0,
        0                         ,   0                         ,   0                         ,   1
    );
    // dfmt on
}

/**
 * Creates a rotation matrix around the axis defined by a vector.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 *  axis = Vector that serves as the axis around which to rotate.
 */
Matrix4D createRotationMatrix(const scalar radianAngle, const Vector3D axis) {
    return createRotationMatrix(radianAngle, axis.x, axis.y, axis.z);
}

/**
 * Creates a rotation matrix.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
Matrix3D createRotationMatrix(const scalar radianAngle) {
    // dfmt off
    return Matrix3D(
        cos(radianAngle), -sin(radianAngle), 0,
        sin(radianAngle),  cos(radianAngle), 0,
        0               ,  0               , 1
    );
    // dfmt on
}

/**
 * Creates a rotation matrix around the X-axis.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
Matrix4D createXRotationMatrix(const scalar radianAngle) {
    // dfmt off
    return Matrix4D(
        1,  0               , 0               , 0,
        0,  cos(radianAngle), sin(radianAngle), 0,
        0, -sin(radianAngle), cos(radianAngle), 0,
        0,  0               , 0               , 1
    );
    // dfmt on
}

/**
 * Creates a rotation matrix around the Y-axis.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
Matrix4D createYRotationMatrix(const scalar radianAngle) {
    // dfmt off
    return Matrix4D(
        cos(radianAngle), 0, -sin(radianAngle), 0,
        0               , 1,  0               , 0,
        sin(radianAngle), 0,  cos(radianAngle), 0,
        0               , 0,  0               , 1
    );
    // dfmt on
}

/**
 * Creates a rotation matrix around the Z-axis.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
Matrix4D createZRotationMatrix(const scalar radianAngle) {
    // dfmt off
    return Matrix4D(
        cos(radianAngle), -sin(radianAngle), 0, 0,
        sin(radianAngle),  cos(radianAngle), 0, 0,
        0               ,  0               , 1, 0,
        0               ,  0               , 0, 1
    );
    // dfmt on
}

/**
 * Creates a world transformation matrix that looks at a target vector.
 */
Matrix4D createLookatMatrix(const Vector3D eyePosition,
    const Vector3D targetPosition, const UnitVector3D upVector) {

    auto const forwardVector = (targetPosition - eyePosition).normalize();
    auto const sideVector = forwardVector.cross(upVector.vector);
    auto const cameraBasedUpVector = sideVector.cross(forwardVector);

    // dfmt off
    return Matrix4D(
         sideVector.x         ,  sideVector.y         ,  sideVector.z         , -eyePosition.x,
         cameraBasedUpVector.x,  cameraBasedUpVector.y,  cameraBasedUpVector.z, -eyePosition.y,
        -forwardVector.x      , -forwardVector.y      , -forwardVector.z      , -eyePosition.z,
         0                    ,  0                    ,  0                    ,  1
    );
    // dfmt on
}

/**
 * Creates a world transformation matrix that looks at the world with a specified pitch 
 * (up/down rotation) and yaw (left/right rotation).
 */
Matrix4D createViewMatrix(Vector3D eyePosition, scalar pitchInRadian, scalar yawInRadian) {
    const scalar cosPitch = cos(pitchInRadian);
    const scalar sinPitch = sin(pitchInRadian);
    const scalar cosYaw = cos(yawInRadian);
    const scalar sinYaw = sin(yawInRadian);

    auto const sideVector = Vector3D(cosYaw, 0, -sinYaw);
    auto const upVector = Vector3D(sinYaw * sinPitch, cosPitch, cosYaw * sinPitch);
    auto const forwardVector = Vector3D(sinYaw * cosPitch, -sinPitch, cosPitch * cosYaw);

    // dfmt off
    return Matrix4D(
        sideVector.x   , sideVector.y   , sideVector.z   , -sideVector.dot(eyePosition),
        upVector.x     , upVector.y     , upVector.z     , -upVector.dot(eyePosition),
        forwardVector.x, forwardVector.y, forwardVector.z, -forwardVector.dot(eyePosition),
        0              , 0              , 0              ,  1
    );
    // dfmt on
}

Matrix4D createViewMatrix(Vector3D eyePosition, QuaternionD eyeOrientation) {
    return eyeOrientation.inverse.toRotationMatrix * (-eyePosition).toTranslationMatrix;
}

/**
 * Creates a perspective projection matrix.
 * 
 * Params:
 *   yfovRadian = Field of view in radian.
 *   aspectRatio = Aspect ratio of the viewing window, pre-divided (e.g. the result of 4 / 3)
 *   near = Near clipping plane.
 *   far = Far clipping plane. If 0, it is considered infinite.
 * Returns: Perspective Matrix
 */
Matrix4D createPerspectiveMatrix(scalar yfovRadian, scalar aspectRatio,
    scalar near, scalar far) {
    const scalar A = 1.0 / (aspectRatio * tan(0.5 * yfovRadian));
    const scalar B = 1.0 / (tan(0.5 * yfovRadian));
    const scalar C = far == 0 ? -1 : (far + near) / (near - far);
    const scalar D = far == 0 ? (-2 * near) : (2.0 * far * near) / (near - far);

    // dfmt off
    return Matrix4D(
        A, 0,  0, 0,
        0, B,  0, 0,
        0, 0,  C, D,
        0, 0, -1, 0
    );
    // dfmt on
}

/** 
 * Creates an orthographic projection matrix.
 *
 * Params:
 *   left = Farthest left on the x-axis
 *   right = Farthest right on the x-axis
 *   bottom = Farthest down on the y-axis
 *   top = Farthest up on the y-axis
 *   near = Distance to the near clipping plane along the -Z axis
 *   far = Distance to the far clipping plane along the -Z axis
 * Returns: Orthographic Matrix
 */
Matrix4D createOrthographicMatrix(scalar left, scalar right, scalar bottom, scalar top, scalar near, scalar far) {
    return createOrthographicMatrix(right - left, top - bottom, near, far);
}

/** 
 * Creates an orthographic projection matrix.
 *
 * Params:
 *   halfWidth = Half the orthographic width
 *   halfHeight = Half the orthographic height
 *   near = Distance to the near clipping plane along the -Z axis
 *   far = Distance to the far clipping plane along the -Z axis
 * Returns: Orthographic Matrix
 */
Matrix4D createOrthographicMatrix(scalar halfWidth, scalar halfHeight, scalar near, scalar far) {
    const scalar A = 1 / (halfWidth / 2);
    const scalar B = 1 / (halfHeight / 2);
    const scalar C = 2 / (near - far);
    const scalar D = (far + near) / (near - far);

    // dfmt off
    return Matrix4D(
        A, 0 , 0, 0,
        0, B , 0, 0,
        0, 0 , C, D,
        0, 0 , 0, 1
    );
    // dfmt on
}

/**
 * Converts an angle in degrees to radians.
 */
double degreesToRadians(double degrees) {
    return degrees * (PI / 180);
}

/**
 * Converts an angle in radians to degrees.
 */
double radiansToDegrees(double radians) {
    return radians * (180 / PI);
}

bool approxEqual(T)(inout T lhs, inout T rhs, T deviation = 0.0001)
        if (is(T == float) || is(T == double) || is(T == real)) {
    if (lhs > 0) {
        return (lhs - deviation) < rhs && (lhs + deviation) > rhs;
    } else {
        return (lhs + deviation) > rhs && (lhs - deviation) < rhs;
    }
}

//TODO: Port bezier curves and splines from old Retrograde?

version (UnitTesting)  :  ///
import retrograde.std.test : test, writeSection;
import retrograde.std.array : equals, approxEquals;

void runMathTests() {
    writeSection("-- Math tests --");

    runMathFunctionsTests();
    runVectorTests();
    runUnitVectorTests();
    runMatrixTests();
    runQuaternionTests();
    runMatrixUtilTests();
    runMiscUtilTests();
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

    test("Create vector by assigning a number", {
        Vector3U vector = 2;
        assert(2 == vector.x);
        assert(2 == vector.y);
        assert(2 == vector.z);
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
        auto const actualVector = vector.refract(1, normal);
        assert(actualVector.x.approxEqual(0.707107));
        assert(actualVector.y.approxEqual(-0.707107));
        assert(actualVector.z == 0);
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

void runUnitVectorTests() {
    writeSection("-- Unit Vector tests --");

    test("Create unit vector from other vector", {
        auto vector = Vector2D(10, 0);
        assert(vector.magnitude == 10);

        auto unitVector = UnitVector2D(vector);
        assert(unitVector.vector.magnitude == 1);
    });

    test("Create unit vector from components", {
        auto unitVector = UnitVector2D(10, 0);
        assert(unitVector.vector.magnitude == 1);
    });
}

void runMatrixTests() {
    writeSection("-- Matrix tests --");

    test("Create and use matrix", {
        auto matrix1 = Matrix!(double, 4, 3)(0);
        assert(0 == matrix1[0, 0]);

        matrix1[0, 2] = 2;
        assert(2 == matrix1[0, 2]);

        auto matrix2 = Matrix4D(0);
        assert(0 == matrix2[0, 0]);

        matrix2[3, 3] = 6;
        assert(6 == matrix2[3, 3]);

        auto matrix3 = Matrix2D(3);
        assert(3 == matrix3[0, 0]);
        assert(3 == matrix3[0, 1]);
        assert(3 == matrix3[1, 0]);
        assert(3 == matrix3[1, 1]);
    });

    test("Create matix by row/column values", {
        // dfmt off
        auto const matrix = Matrix2D(
            1, 2,
            3, 4
        );
        // dfmt on

        assert(1 == matrix[0, 0]);
        assert(2 == matrix[0, 1]);
        assert(3 == matrix[1, 0]);
        assert(4 == matrix[1, 1]);
    });

    test("Create 4x1 matrix", {
        auto const matrix = Matrix!(double, 4, 1)(1, 2, 3, 4);
        assert(1 == matrix[0, 0]);
        assert(2 == matrix[1, 0]);
        assert(3 == matrix[2, 0]);
        assert(4 == matrix[3, 0]);
    });

    test("Compare two matrices", {
        auto const matrixOne = Matrix2D(1, 2, 3, 4);
        auto const matrixTwo = Matrix2D(1, 2, 3, 4);
        assert(matrixOne == matrixTwo);

        auto const matrixThree = Matrix2D(1, 2, 3, 5);
        assert(matrixOne != matrixThree);
    });

    test("Identity matrix", {
        // dfmt off
        auto const expectedMatrix = Matrix4D(
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        );
        // dfmt on

        auto const identityMatrix = Matrix4D.identity;
        assert(expectedMatrix == identityMatrix);
    });

    test("Multiply matrix by vector", {
        // dfmt off
        auto const matrix = Matrix4D(
            1, 0, 1, 0,
            2, 1, 0, 0,
            0, 0, 1, 3,
            0, 4, 0, 1
        );
        // dfmt on

        auto const vector = Vector4D(1, 2, 3, 4);
        auto const expectedVector = Vector4D(4, 4, 15, 12);
        auto const actualVector = matrix * vector;

        assert(expectedVector == actualVector);
    });

    test("Multiply identity matrix by vector", {
        auto const matrix = Matrix4D.identity;
        auto const vector = Vector4D(1, 4, 6, 7);
        auto const actualVector = matrix * vector;

        assert(vector == actualVector);
    });

    test("Multiply matrices", {
        // dfmt off
        auto const matrix1 = Matrix2D(
            1, 2,
            3, 4
        );

        auto const matrix2 = Matrix2D(
            5, 6,
            7, 8
        );

        auto const expectedMatrix = Matrix2D(
            19, 22,
            43, 50
        );
        // dfmt on

        auto const actualMatrix = matrix1 * matrix2;
        assert(actualMatrix == expectedMatrix);
    });

    test("Multiply matrices of different dimensions", {
        // dfmt off
        auto const matrix1 = Matrix!(double, 2, 3)(
            1, 2, 3,
            4, 5, 6
        );

        auto const matrix2 = Matrix!(double, 3, 2)(
            7 , 8,
            9 , 10,
            11, 12
        );

        auto const expectedMatrix = Matrix2D(
            58 , 64,
            139, 154
        );
        // dfmt on

        auto const actualMatrix = matrix1 * matrix2;
        assert(expectedMatrix == actualMatrix);
    });

    test("Multiply matrix by scalar", {
        // dfmt off
        auto const matrix = Matrix2D(
            1,  4,
            0, -9
        );

        auto const expectedMatrix = Matrix2D(
            2,  8,
            0, -18
        );
        // dfmt on

        auto actualMatrix = matrix * 2;
        assert(expectedMatrix == actualMatrix);

        actualMatrix = 2 * matrix;
        assert(expectedMatrix == actualMatrix);
    });

    test("Transpose matrix", {
        // dfmt off
        auto const matrix = Matrix!(double, 2, 3)(
            1, 2, 3,
            4, 5, 6
        );

        auto const expectedMatrix = Matrix!(double, 3, 2)(
            1, 4,
            2, 5,
            3, 6
        );
        // dfmt on

        auto const actualMatrix = matrix.transpose();
        assert(expectedMatrix == actualMatrix);
    });

    test("Get row vector matrix", {
        // dfmt off
        auto const matrix = Matrix2D(
            3, 5,
            8, 7
        );
        // dfmt on

        auto const expectedVector = Vector2D(3, 5);
        auto const actualVector = matrix.getRowVector(0);

        assert(expectedVector == actualVector);
    });

    test("Get column vector matrix", {
        // dfmt off
        auto const matrix = Matrix2D(
            3, 5,
            8, 7
        );
        // dfmt on

        auto const expectedVector = Vector2D(3, 8);
        auto const actualVector = matrix.getColumnVector(0);

        assert(expectedVector == actualVector);
    });

    test("Matrix addition", {
        // dfmt off
        auto const matrix1 = Matrix2D(
            1, 2,
            3, 4
        );

        auto const matrix2 = Matrix2D(
            5, 6,
            7, 8
        );

        auto const expectedMatrix = Matrix2D(
            6 , 8,
            10, 12
        );
        // dfmt on

        auto const actualMatrix = matrix1 + matrix2;
        assert(expectedMatrix == actualMatrix);
    });

    test("Matrix subtraction", {
        // dfmt off
        auto const matrix1 = Matrix2D(
            8, 7,
            6, 5
        );

        auto const matrix2 = Matrix2D(
            1, 2,
            3, 4
        );

        auto const expectedMatrix = Matrix2D(
            7, 5,
            3, 1
        );
        // dfmt on

        auto const actualMatrix = matrix1 - matrix2;
        assert(expectedMatrix == actualMatrix);
    });

    test("Matrix negation", {
        // dfmt off
        auto const matrix = Matrix2D(
             1, -3,
            -6,  8
        );

        auto const expectedMatrix = Matrix2D(
            -1,  3,
             6, -8
        );
        // dfmt on

        auto const actualMatrix = -matrix;
        assert(expectedMatrix == actualMatrix);
    });

    test("Assign value via index", {
        auto actualMatrix = Matrix2D(0);
        // dfmt off
        auto const expectedMatrix = Matrix2D(
            0, 0,
            6, 0
        );
        // dfmt on

        actualMatrix[2] = 6;
        assert(expectedMatrix == actualMatrix);
    });

    test("Get data array", {
        // dfmt off
        auto const matrix = Matrix2D(
            1, 2, 
            3, 4
        );
        // dfmt on

        const double[4] expectedArray = [1, 2, 3, 4];
        const double[4] actualArray = matrix.getDataArray();

        assert(expectedArray.equals(actualArray));
    });

    test("Get casted data array", {
        // dfmt off
        auto const matrix = Matrix2D(
            1, 2, 
            3, 4
        );
        // dfmt on

        const float[4] expectedArray = [1, 2, 3, 4];
        const float[4] actualArray = matrix.getDataArray!float;

        assert(expectedArray.equals(actualArray));
    });
}

void runQuaternionTests() {
    writeSection("-- Quaternion tests --");

    test("Create quaternion", {
        auto const quaternion = QuaternionD();
        assert(QuaternionD(1, 0, 0, 0) == quaternion);

        auto const quaternion2 = QuaternionD(4, 1, 2, 3);
        assert(4 == quaternion2.w);
        assert(1 == quaternion2.x);
        assert(2 == quaternion2.y);
        assert(3 == quaternion2.z);

        auto const quaternion3 = QuaternionD(4, Vector3D(1, 2, 3));
        assert(4 == quaternion3.w);
        assert(1 == quaternion3.x);
        assert(2 == quaternion3.y);
        assert(3 == quaternion3.z);
    });

    test("Create quaternions", {
        auto const quaternion1 = QuaternionD(1, 2, 3, 4);
        auto const quaternion2 = QuaternionD(5, 6, 7, 8);
        auto const expectedQuaternion = QuaternionD(-60, 12, 30, 24);
        auto const actualQuaternion = quaternion1 * quaternion2;

        assert(expectedQuaternion == actualQuaternion);
        assert(quaternion1 * quaternion2 != quaternion2 * quaternion1);
    });

    test("Create from angle and axis vector", {
        auto const quaternion = QuaternionD.createRotation(PI, Vector3D(1, 0, 0));
        assert(quaternion.realPart.approxEqual(6.12303e-17));
        assert(quaternion.imaginaryVector == Vector3D(1, 0, 0));
    });

    test("Convert to rotation matrix", {
        auto const quaternion = QuaternionD(6.12303e-17, 1, 0, 0);
        auto const actualRotationMatrix = quaternion.toRotationMatrix();
        assert(actualRotationMatrix.data.approxEquals([
                1, 0, 0, 0, 0, -1, -1.22461e-16, 0, 0, 1.22461e-16, -1, 0, 0, 0, 0,
                1
            ]));
    });

    test("Convert to euler angles vector", {
        auto const quaternion = QuaternionD.createRotation(PI, Vector3D(0, 1, 0));
        auto const expectedToEulerAngles = Vector3D(0, PI, 0);
        auto const actualEulerAngles = quaternion.toEulerAngles();
        assert(expectedToEulerAngles == actualEulerAngles);

        auto const quaternion2 = QuaternionD.createRotation(PI, Vector3D(1, 0, 0));
        auto const expectedToEulerAngles2 = Vector3D(PI, 0, 0);
        auto const actualEulerAngles2 = quaternion2.toEulerAngles();
        assert(expectedToEulerAngles2 == actualEulerAngles2);
    });

    test("Angle", {
        auto const quaternion = QuaternionD.createRotation(PI, Vector3D(0, 1, 0));
        assert(quaternion.angle.approxEqual(PI));
    });

    test("Axis when rotation is zero", {
        auto const quaternion = QuaternionD.createRotation(0, Vector3D(0, 1, 0));
        assert(quaternion.axis == Vector3D(0, 1, 0));
    });

    test("Axis when rotation is non-zero", {
        auto const quaternion = QuaternionD.createRotation(PI, Vector3D(0, 0, 1));
        assert(quaternion.axis == Vector3D(0, 0, 1));
    });

    test("Conjugate", {
        auto const quaternion = QuaternionD(1, 2, 3, 4);
        assert(quaternion.conjugate == QuaternionD(1, -2, -3, -4));
    });

    test("Inverse", {
        auto const quaternion = QuaternionD(1, 2, 3, 4);
        auto const inverse = quaternion.inverse;
        assert(inverse.w.approxEqual(0.0333333, 0.01));
        assert(inverse.x.approxEqual(-0.0666667, 0.01));
        assert(inverse.y.approxEqual(-0.1, 0.1));
        assert(inverse.z.approxEqual(-0.1333333, 0.01));
    });

    test("Dot product", {
        auto const quaternion1 = QuaternionD(1, 2, 3, 4);
        auto const quaternion2 = QuaternionD(5, 6, 7, 8);
        assert(quaternion1.dot(quaternion2) == 70);
    });

    test("Multiply", {
        auto const quaternion1 = QuaternionD(1, 2, 3, 4);
        auto const quaternion2 = QuaternionD(5, 6, 7, 8);
        assert(quaternion1 * quaternion2 == QuaternionD(-60, 12, 30, 24));
    });
}

void runMatrixUtilTests() {
    writeSection("-- Matrix util tests --");

    test("Create translation matrix from 2D vector", {
        auto const vector = Vector2D(25, 56);
        // dfmt off
        auto const expectedMatrix = Matrix3D(
            1, 0, 25,
            0, 1, 56,
            0, 0, 1
        );
        // dfmt on

        auto const actualMatrix = vector.toTranslationMatrix();
        assert(expectedMatrix == actualMatrix);
    });

    test("Create translation matrix from 3D vector", {
        auto const vector = Vector3D(2, 5, 6);
        // dfmt off
        auto const expectedMatrix = Matrix4D(
            1, 0, 0, 2,
            0, 1, 0, 5,
            0, 0, 1, 6,
            0, 0, 0, 1
        );
        // dfmt on

        auto const actualMatrix = vector.toTranslationMatrix();
        assert(expectedMatrix == actualMatrix);
    });

    test("Create scaling matrix from 2D vector", {
        auto const vector = Vector2D(6, 12);
        // dfmt off
        auto const expectedMatrix = Matrix3D(
            6, 0 , 0,
            0, 12, 0,
            0, 0 , 1
        );
        // dfmt on

        auto const actualMatrix = vector.toScalingMatrix();
        assert(expectedMatrix == actualMatrix);
    });

    test("Create scaling matrix from 3D vector", {
        auto const vector = Vector3D(1, 2, 5);
        // dfmt off
        auto const expectedMatrix = Matrix4D(
            1, 0, 0, 0,
            0, 2, 0, 0,
            0, 0, 5, 0,
            0, 0, 0, 1
        );
        // dfmt on

        auto const actualMatrix = vector.toScalingMatrix();
        assert(expectedMatrix == actualMatrix);
    });

    test("Create 4D rotation matrix", {
        auto const expectedMatrix = Matrix!(double, 4u, 4u)(
            -1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1
        );

        auto actualMatrix1 = createRotationMatrix(PI, 0, 1, 0);
        assert(expectedMatrix.data.approxEquals(actualMatrix1.data));

        auto actualMatrix2 = createRotationMatrix(PI, Vector3D(0, 1, 0));
        assert(expectedMatrix.data.approxEquals(actualMatrix2.data));
        assert(actualMatrix1.data.approxEquals(actualMatrix2.data));
    });

    test("Create 3D rotation matrix", {
        auto const expectedMatrix = Matrix!(double, 3u, 3u)(-0.989992, -0.14112, 0, 0.14112, -0.989992, 0, 0, 0, 1);
        auto actualMatrix = createRotationMatrix(3);
        assert(expectedMatrix.data.approxEquals(actualMatrix.data));
    });

    test("Create axis-bound rotation matrices", {
        auto expectedMatrix = Matrix!(double, 4u, 4u)(1, 0, 0, 0, 0, -1, 1.22461e-16, 0, 0, -1.22461e-16, -1, 0, 0, 0, 0, 1);
        auto actualMatrix = createXRotationMatrix(PI);
        assert(expectedMatrix.data.approxEquals(actualMatrix.data));

        expectedMatrix = Matrix!(double, 4u, 4u)(-1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1);
        actualMatrix = createYRotationMatrix(PI);
        assert(expectedMatrix.data.approxEquals(actualMatrix.data));

        expectedMatrix = Matrix!(double, 4u, 4u)(-1, -1.22461e-16, 0, 0, 1.22461e-16, -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
        actualMatrix = createZRotationMatrix(PI);
        assert(expectedMatrix.data.approxEquals(actualMatrix.data));
    });

    test("Create look-at matrix", {
        auto const expectedMatrix = Matrix!(double, 4u, 4u)(0, 0, 1, -0, 0, 1, 0, -1, -1, -0, -0, -0, 0, 0, 0, 1);
        auto actualMatrix = createLookatMatrix(Vector3D(0, 1, 0), Vector3D(1,
            1, 0), UnitVector3D(0, 1, 0));
        assert(expectedMatrix.data.approxEquals(actualMatrix.data));
    });

    test("Create view matrix", {
        auto const expectedMatrix = Matrix!(double, 4u, 4u)(0.540302, 0, -0.841471, -0.540302, 0.708073, 0.540302, 0.454649, -1.24838, 0.454649, -0.841471, 0.291927, 0.386822, 0, 0, 0, 1);
        auto actualMatrix = createViewMatrix(Vector3D(1, 1, 0), 1, 1);
        assert(expectedMatrix.data.approxEquals(actualMatrix.data));
    });

    test("Create perspective matrix", {
        auto const expectedMatrix = Matrix!(double, 4u, 4u)(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1.0002, -0.20002, 0, 0, -1, 0);
        auto actualMatrix = createPerspectiveMatrix(degreesToRadians(90), 1920 / 1080, 0.1, 1000);
        assert(expectedMatrix.data.approxEquals(actualMatrix.data));
    });

    test("Create orthographic matrix", {
        auto const expectedMatrix = Matrix!(double, 4u, 4u)(0.2, 0, 0, 0, 0, 0.2, 0, 0, 0, 0, -0.2, -0, 0, 0, 0, 1);
        auto actualMatrix = createOrthographicMatrix(-5, 5, -5, 5, -5, 5);
        assert(expectedMatrix.data.approxEquals(actualMatrix.data));
    });
}

void runMiscUtilTests() {
    writeSection("-- Misc util tests --");

    test("Convert degrees to radians", {
        assert(PI.approxEqual(degreesToRadians(180)));
        assert(0f.approxEqual(degreesToRadians(0)));
        assert((2 * PI).approxEqual(degreesToRadians(360)));
    });

    test("Convert radians to degrees", {
        assert(180 == radiansToDegrees(PI));
        assert(0 == radiansToDegrees(0));
        assert(360 == radiansToDegrees(2 * PI));
    });
}
