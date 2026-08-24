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

version (DoublePrecision) {
    alias scalar = double;
    enum double PI = 3.141592653589793238462643383279502884197169399375105820974944;
} else {
    alias scalar = float;
    enum float PI = 3.141592653589793238462643383279502884197169399375105820974944;
}

/**
 * A Euclidean vector.
 */
struct VectorT(T, uint N) if (N > 0) {
    alias _N = N;
    alias _T = T;

    private T[N] components = 0;

    static if (N >= 2) {
        private static VectorT!(T, N) _upVector;

        /**
         * Returns the engine's standard up vector, which is +y.
         */
        static upVector() {
            if (_upVector[1] != 1) {
                _upVector = VectorT!(T, N)(0);
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
        assert(components.length == N, "Cannot initialize a vector with a different amount of components than available.");
        this.components = components;
    }

    static if (N >= 2) {
        /**
         * Constructs a vector from a smaller vector and an extra component.
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
        this(VectorT!(T, N - 1) smallerVector, T extraComponent) {
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
        VectorT normalize() const {
            // Prevent magnitude calculation over and over
            auto const currentMagnitude = magnitude;

            if (currentMagnitude == 0) {
                return VectorT(0);
            }

            if (currentMagnitude == 1) {
                return this;
            }

            VectorT normalizedVector;
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

            static if (is(scalar == float)) {
                return sqrtf(powSum);
            } else {
                return sqrt(powSum);
            }
        }
    }

    static if (N == 2) {
        /**
         * Returns the angle in degrees of this vector in two-dimentionsal space.
         */
        scalar angle() const {
            static if (is(scalar == float)) {
                alias _atan2 = atan2f;
            } else {
                alias _atan2 = atan2;
            }
            auto angle = _atan2(cast(scalar) y, cast(scalar) x);
            if (angle < 0) {
                angle = (2 * PI) + angle;
            }
            return angle;
        }
    }

    /**
     * Returns an inverse copy of this vector.
     */
    VectorT opUnary(string s)() const if (s == "-") {
        return this * -1;
    }

    /**
     * Returns a copy of this and another vector added/substracted/multiplied/divided together.
     *
     * All operations are applied per component. Multiplication therefore yields the
     * Hadamard product of both vectors, not their dot or cross product. Use $(D dot)
     * or $(D cross) for those. Division is likewise per component; a zero component in
     * the divisor is not guarded against.
     */
    VectorT opBinary(string op)(const VectorT rhs) const
    if (rhs._N == N && (op == "+" || op == "-" || op == "*" || op == "/")) {
        VectorT vec;
        static foreach (i; 0 .. N) {
            mixin("vec[i] = cast(T) (components[i] " ~ op ~ " rhs[i]);");
        }

        return vec;
    }

    /**
     * Returns a copy of this vector multiplied/divided by the given scalar.
     */
    VectorT opBinary(string op)(const scalar rhs) const if (op == "*" || op == "/") {
        VectorT vec;
        static foreach (i; 0 .. N) {
            mixin("vec[i] = cast(T) (components[i] " ~ op ~ " rhs);");
        }

        return vec;
    }

    /**
     * Returns a copy of this vector multiplied/divided by the given scalar.
     */
    VectorT opBinaryRight(string op)(const scalar lhs) const if (op == "*") {
        return this * lhs;
    }

    bool opEquals()(auto ref const VectorT other) const if (other._N == N) {
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
    T dot()(const VectorT other) const if (other._N == N) {
        T dotProduct = 0;
        static foreach (i; 0 .. N) {
            dotProduct += this[i] * other[i];
        }

        return dotProduct;
    }

    /**
     * Calculates the cross product of two vectors.
     */
    VectorT cross()(const VectorT other) const if (N == 3 && other._N == N) {
        // dfmt off
        return VectorT(
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
    VectorT reflect()(const VectorT normal) const if (N >= 2 && normal._N == N) {
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
    VectorT refract()(const T refractionIndex, const VectorT normal) const
    if (N >= 2 && normal._N == N) {

        auto const normalizedThis = this.normalize();
        auto const normalizedNormal = normal.normalize();
        auto const dotProduct = normalizedNormal.dot(normalizedThis);
        auto const k = 1 - (refractionIndex * refractionIndex) * (1 - (dotProduct * dotProduct));

        if (k < 0) {
            return VectorT(0);
        }

        static if (is(scalar == float)) {
            alias _sqrt = sqrtf;
        } else {
            alias _sqrt = sqrt;
        }
        return refractionIndex * normalizedThis - (refractionIndex * normalizedNormal.dot(
                normalizedThis) + _sqrt(k)) * normalizedNormal;
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
    VectorT interpolate(const VectorT other, scalar t) const {
        return (1 - t) * this + t * other;
    }

    /** 
     * Returns the extrapolation of two vectors by amount t.
     * 
     * Params:
     *  other = The other vector to extrapolate with.
     *  t = Extrapolation factor greater than 1. If t is less than 1, the result is the same as interpolate.
     *
     * Returns: A vector that is the result of the extrapolation factor. 
     */
    VectorT extrapolate(const VectorT other, scalar t) const {
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
    VectorT quadraticBezierCurvePoint(const VectorT B, const VectorT C, const scalar t) const {
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
    VectorT cubicBezierCurvePoint(const VectorT B, const VectorT C, const VectorT D, const scalar t) const {
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

    String toString() const {
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
        VectorT!(T, N - 1) downgrade() const {
            return VectorT!(T, N - 1)(this.components[0 .. $ - 1]);
        }
    }
}

alias Vector2I = VectorT!(int, 2);
alias Vector2U = VectorT!(uint, 2);
alias Vector2L = VectorT!(long, 2);
alias Vector2UL = VectorT!(ulong, 2);
alias Vector2F = VectorT!(float, 2);
alias Vector2D = VectorT!(double, 2);

alias Vector3I = VectorT!(int, 3);
alias Vector3U = VectorT!(uint, 3);
alias Vector3L = VectorT!(long, 3);
alias Vector3UL = VectorT!(ulong, 3);
alias Vector3F = VectorT!(float, 3);
alias Vector3D = VectorT!(double, 3);
alias Vector4F = VectorT!(float, 4);
alias Vector4D = VectorT!(double, 4);

version (DoublePrecision) {
    alias Vector3 = Vector3D;
    alias Vector4 = Vector4D;
} else {
    alias Vector3 = Vector3F;
    alias Vector4 = Vector4F;
}

/**
 * A vector whose length is always 1.
 */
struct UnitVector(VecT) {
    private VecT _vector;

    /**
     * Creates a unit vector from a regular vector. 
     *
     * The supplied vector is automatically normalized.
     */
    this(const VecT vector) {
        this._vector = vector.normalize();
    }

    /**
     * Creates a unit vector from the supplied components. 
     *
     * The resulting vector is automatically normalized.
     */
    this(const VecT._T[] components...) {
        assert(components.length == VecT._N, "Cannot initialize a unit vector with a different amount of components than its vector type has.");
        this(VecT(components));
    }

    /**
     * Return a copy of the regular, normalized vector represented by this unit vector.
     */
    VecT vector() const {
        return _vector;
    }
}

alias UnitVector2F = UnitVector!Vector2F;
alias UnitVector2D = UnitVector!Vector2D;

alias UnitVector3F = UnitVector!Vector3F;
alias UnitVector3D = UnitVector!Vector3D;

alias UnitVector4F = UnitVector!Vector4F;
alias UnitVector4D = UnitVector!Vector4D;

/**
 * A matrix!
 *
 * The data is laid out in a row-major order.
 */
struct MatrixT(T, uint Rows, uint Columns) if (Rows > 0 && Columns > 0) {
    private T[Columns * Rows] data;

    alias _T = T;
    alias _Rows = Rows;
    alias _Columns = Columns;
    alias _VecT = VectorT!(T, Rows);

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
        assert(initialValues.length == data.length, "Cannot initialize a matrix with a different size of data than available.");
        data = initialValues;
    }

    static if (Rows == Columns) {
        private static MatrixT identityMatrix;

        /**
         * Returns an identity matrix.
         */
        static MatrixT identity() {
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
    MatrixT opUnary(string s)() const if (s == "-") {
        return this * -1;
    }

    /**
     * Returns a vector where this matrix is multiplied by a vector.
     */
    _VecT opBinary(string op)(const _VecT rhs) const if (op == "*") {
        _VecT vector = _VecT(0);
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
    MatrixT opBinary(string op)(const scalar rhs) const if (op == "*") {
        MatrixT matrix;
        static foreach (index; 0 .. Rows * Columns) {
            matrix[index] = this[index] * rhs;
        }

        return matrix;
    }

    /**
     * Returns a copy of this matrix where all values are multiplied by a scalar.
     */
    MatrixT opBinaryRight(string op)(const scalar lhs) const if (op == "*") {
        return this * lhs;
    }

    /**
     * Returns a copy of this matrix that is multiplied by another matrix.
     */
    MatrixT!(T, Rows, OtherColumns) opBinary(string op, uint OtherRows, uint OtherColumns)(
        const MatrixT!(T, OtherRows, OtherColumns) rhs) const
    if (op == "*" && Columns == OtherRows) {

        MatrixT!(T, Rows, OtherColumns) resultMatrix;

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
    MatrixT opBinary(string op)(const MatrixT rhs) const
    if ((op == "+" || op == "-") && Columns == rhs._Columns && Rows == rhs._Rows) {
        MatrixT resultMatrix;
        static foreach (i; 0 .. Rows * Columns) {
            mixin("resultMatrix[i] = this[i] " ~ op ~ " rhs[i];");
        }

        return resultMatrix;
    }

    bool opEquals()(auto ref const MatrixT other) const {
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
    MatrixT!(T, Columns, Rows) transpose() const {
        MatrixT!(T, Columns, Rows) result;
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
    VectorT!(T, Columns) getRowVector(const size_t row) const {
        return VectorT!(T, Columns)(data[row * Columns .. (row * Columns) + Columns]);
    }

    /** 
     * Returns: a certain column of this matrix as vector.
     */
    VectorT!(T, Rows) getColumnVector(const size_t col) const {
        VectorT!(T, Rows) columnVector;
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

alias Matrix2F = MatrixT!(float, 2, 2);
alias Matrix3F = MatrixT!(float, 3, 3);
alias Matrix4F = MatrixT!(float, 4, 4);

alias Matrix2D = MatrixT!(double, 2, 2);
alias Matrix3D = MatrixT!(double, 3, 3);
alias Matrix4D = MatrixT!(double, 4, 4);

version (DoublePrecision) {
    alias Matrix2 = Matrix2D;
    alias Matrix3 = Matrix3D;
    alias Matrix4 = Matrix4D;
} else {
    alias Matrix2 = Matrix2F;
    alias Matrix3 = Matrix3F;
    alias Matrix4 = Matrix4F;
}

/**
 * A complex mathematical number typically used for rotation.
 * Quaternions prevent gimbal lock.
 */
struct QuaternionT(T) {
    alias _T = T;
    alias VecT = VectorT!(T, 3);

    private T realPart = 1;
    private VecT imaginaryVector = VecT(0);

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
        imaginaryVector = VecT(x, y, z);
    }

    /**
     * Construct a quaternion from a real number and an imaginary vector.
     * Params:
     *  r = The real number component.
     *  v = The imaginary vector.
     */
    this(T r, const VecT v) {
        realPart = r;
        imaginaryVector = v;
    }

    /**
     * Create a quaternion that rotates around a specified axis.
     * Params:
     *  radianAngle = Rotation around the given axis in radians.
     *  axis = Regular three-dimensional axis to rotate around.
     */
    static QuaternionT createRotation(VecT)(T radianAngle, const VecT axis) {
        auto normalizedAxis = axis.normalize();
        static if (is(T == float)) {
            alias _cos = cosf;
            alias _sin = sinf;
        } else {
            alias _cos = cos;
            alias _sin = sin;
        }

        T halfAngle = radianAngle / 2;
        T sinHalf = _sin(halfAngle);

        return QuaternionT(
            _cos(halfAngle),
            sinHalf * normalizedAxis.x,
            sinHalf * normalizedAxis.y,
            sinHalf * normalizedAxis.z
        );
    }

    /**
     * Multiple two quaternions.
     */
    QuaternionT opBinary(string op)(const QuaternionT rhs) const if (op == "*") {
        return QuaternionT(
            w * rhs.w - x * rhs.x - y * rhs.y - z * rhs.z,
            w * rhs.x + x * rhs.w + y * rhs.z - z * rhs.y,
            w * rhs.y - x * rhs.z + y * rhs.w + z * rhs.x,
            w * rhs.z + x * rhs.y - y * rhs.x + z * rhs.w
        );
    }

    /** 
     * Multiply or divide quaternion by the given scalar.
     */
    QuaternionT opBinary(string op)(const scalar rhs) const if (op == "*" || op == "/") {
        return QuaternionT(
            mixin("w " ~ op ~ " rhs"),
            mixin("x " ~ op ~ " rhs"),
            mixin("y " ~ op ~ " rhs"),
            mixin("z " ~ op ~ " rhs"),
        );
    }

    /**
     * Calculates the dot product of two quaternions.
     */
    T dot()(const QuaternionT other) const {
        return x * other.x + y * other.y + z * other.z + w * other.w;
    }

    /**
     * Convert quaterion to a four-dimensional rotation matrix.
     */
    MatrixT!(T, 4, 4) toRotationMatrix() const {
        // dfmt off
        return MatrixT!(T, 4, 4)(
           1 - 2 * (y * y) - 2 * (z * z), 2 * x * y - 2 * z * w          , (2 * x * z) + (2 * y * w)     , 0,
           2 * x * y + 2 * z * w        , 1 - 2 * (x * x) - 2 * (z * z)  , 2 * y * z - 2 * x * w         , 0,
           2 * x * z - 2 * y * w        , 2 * y * z + 2 * x * w          , 1 - 2 * (x * x)  - 2 * (y * y), 0,
           0                            , 0                              , 0                             , 1
        );
        // dfmt on
    }

    /**
     * Convert quaternion to a vector of Euler angles using the YZX rotation order.
     *
     * This method extracts Euler angles from a quaternion for a right-handed
     * coordinate system with Y-up. The rotation order is YZX (intrinsic), meaning
     * rotations are applied as: first yaw (Y), then roll (Z), then pitch (X).
     *
     * Returns:
     *   A Vector3 containing (pitch, yaw, roll) in radians where:
     *   - pitch = rotation around X-axis (looking up/down)
     *   - yaw = rotation around Y-axis (turning left/right)
     *   - roll = rotation around Z-axis (tilting side to side)
     *
     * Note: Gimbal lock occurs when roll approaches ±π/2.
     */
    VectorT!(T, 3) toEulerAngles() const {
        auto q = this;

        static if (is(T == float)) {
            alias _atan2 = atan2f;
            alias _asin = asinf;
        } else {
            alias _atan2 = atan2;
            alias _asin = asin;
        }

        // Gimbal lock test for YZX rotation order
        // sinRoll = 2(xy + zw), gimbal lock when |sinRoll| ≈ 1
        auto sinRoll = 2 * (q.x * q.y + q.z * q.w);

        if (sinRoll > 0.9999) {
            // Gimbal lock at roll = +π/2
            // Pitch and yaw become coupled; set pitch = 0
            auto pitch = cast(T) 0;
            auto yaw = 2 * _atan2(q.x, q.w);
            auto roll = cast(T)(PI / 2);
            return VectorT!(T, 3)(pitch, yaw, roll);
        }

        if (sinRoll < -0.9999) {
            // Gimbal lock at roll = -π/2
            // Pitch and yaw become coupled; set pitch = 0
            auto pitch = cast(T) 0;
            auto yaw = -2 * _atan2(q.x, q.w);
            auto roll = cast(T)(-PI / 2);
            return VectorT!(T, 3)(pitch, yaw, roll);
        }

        auto sqw = q.w * q.w;
        auto sqx = q.x * q.x;
        auto sqy = q.y * q.y;
        auto sqz = q.z * q.z;

        auto pitch = _atan2(2 * (q.x * q.w - q.y * q.z), sqw - sqx + sqy - sqz);
        auto yaw = _atan2(2 * (q.y * q.w - q.x * q.z), sqw + sqx - sqy - sqz);
        auto roll = _asin(sinRoll);

        return VectorT!(T, 3)(pitch, yaw, roll);
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
        static if (is(scalar == float)) {
            return sqrtf(magnitudeSquared);
        } else {
            return sqrt(magnitudeSquared);
        }
    }

    /** 
     * Returns a normalized form of this Quaternion.
     */
    QuaternionT normalize() const {
        return this / magnitude;
    }

    /**
     * Return angle of quaternion in radian.
     */
    scalar angle() const {
        static if (is(scalar == float)) {
            alias _acos = acosf;
        } else {
            alias _acos = acos;
        }
        return 2 * _acos(w);
    }

    /**
     * Return Euclidian axis of quaternion.
     *
     * In case angle = 0 the axis is (0, 1, 0)
     */
    VecT axis() const {
        auto q = normalize();

        static if (is(scalar == float)) {
            alias _sqrt = sqrtf;
        } else {
            alias _sqrt = sqrt;
        }
        auto denominatorSquared = 1 - q.w * q.w;
        if (denominatorSquared < scalar.epsilon) {
            return VecT(0, 1, 0);
        }
        auto denominator = _sqrt(denominatorSquared);
        return VecT(
            q.x / denominator,
            q.y / denominator,
            q.z / denominator
        );
    }

    /**
     * Returns a new quaternion that is the conjugate of the current.
     */
    QuaternionT conjugate() const {
        return QuaternionT(w, -x, -y, -z);
    }

    /**
     * Returns a new quaternion that is the inverse of the current.
     */
    QuaternionT inverse() const {
        return conjugate / magnitudeSquared;
    }

    String toString() const {
        auto realPartString = (cast(T) realPart).to!String();
        auto vectorString = imaginaryVector.toString();
        return "(".s ~ realPartString ~ ", ".s ~ vectorString ~ ")".s;
    }
}

alias QuaternionF = QuaternionT!float;
alias QuaternionD = QuaternionT!double;

version (DoublePrecision) {
    alias Quaternion = QuaternionD;
} else {
    alias Quaternion = QuaternionF;
}

/**
 * Creates a translation matrix from a vector.
 */
MatT toTranslationMatrix3T(VecT, MatT)(const VecT vector) {
    // dfmt off
    return MatT(
        1, 0, vector.x,
        0, 1, vector.y,
        0, 0, 1
    );
    // dfmt on
}

alias toTranslationMatrix3F = toTranslationMatrix3T!(Vector2F, Matrix3F);
alias toTranslationMatrix3D = toTranslationMatrix3T!(Vector2D, Matrix3D);

version (DoublePrecision) {
    alias toTranslationMatrix3 = toTranslationMatrix3D;
} else {
    alias toTranslationMatrix3 = toTranslationMatrix3F;
}

/**
 * Creates a translation matrix from a vector.
 */
MatT toTranslationMatrix4T(VecT, MatT)(const VecT vector) {
    // dfmt off
    return MatT(
        1, 0, 0, vector.x,
        0, 1, 0, vector.y,
        0, 0, 1, vector.z,
        0, 0, 0, 1
    );
    // dfmt on
}

alias toTranslationMatrix4F = toTranslationMatrix4T!(Vector3F, Matrix4F);
alias toTranslationMatrix4D = toTranslationMatrix4T!(Vector3D, Matrix4D);

version (DoublePrecision) {
    alias toTranslationMatrix4 = toTranslationMatrix4D;
} else {
    alias toTranslationMatrix4 = toTranslationMatrix4F;
}

/** 
 * Creates a translation vector from a matrix.
 */
VecT toTranslationVectorT(MatT, VecT)(const MatT matrix) {
    return VecT(
        matrix[0, 3],
        matrix[1, 3],
        matrix[2, 3]
    );
}

alias toTranslationVector3F = toTranslationVectorT!(Matrix4F, Vector3F);
alias toTranslationVector3D = toTranslationVectorT!(Matrix4D, Vector3D);

version (DoublePrecision) {
    alias toTranslationVector = toTranslationVector3D;
} else {
    alias toTranslationVector = toTranslationVector3F;
}

/**
 * Creates a scaling matrix from a scaling vector.
 */
MatT toScalingMatrix2T(VecT, MatT)(const VecT scalingVector) {
    // dfmt off
    return MatT(
        scalingVector.x, 0              , 0,
        0              , scalingVector.y, 0,
        0              , 0              , 1
    );
    // dfmt on
}

alias toScalingMatrix3F = toScalingMatrix2T!(Vector2F, Matrix3F);
alias toScalingMatrix3D = toScalingMatrix2T!(Vector2D, Matrix3D);

version (DoublePrecision) {
    alias toScalingMatrix3 = toScalingMatrix3D;
} else {
    alias toScalingMatrix3 = toScalingMatrix3F;
}

/**
 * Creates a scaling matrix from a scaling vector.
 */
MatT toScalingMatrix3T(VecT, MatT)(const VecT scalingVector) {
    // dfmt off
    return MatT(
        scalingVector.x, 0                 , 0              , 0,
        0              , scalingVector.y   , 0              , 0,
        0              , 0                 , scalingVector.z, 0,
        0              , 0                 , 0              , 1
    );
    // dfmt on
}

alias toScalingMatrix4F = toScalingMatrix3T!(Vector3F, Matrix4F);
alias toScalingMatrix4D = toScalingMatrix3T!(Vector3D, Matrix4D);

version (DoublePrecision) {
    alias toScalingMatrix4 = toScalingMatrix4D;
} else {
    alias toScalingMatrix4 = toScalingMatrix4F;
}

/**
 * Creates a normal matrix out of a model matrix: the inverse transpose of its upper-left 3x3
 * part, which keeps normals perpendicular to the surface under non-uniform scale and shear.
 *
 * Normals it transforms are not unit length; normalizing is left to the consumer. When the
 * model matrix cannot be inverted its rotation and scale part is returned unchanged.
 */
MatT3 toNormalMatrixT(MatT4, MatT3)(const MatT4 modelMatrix) {
    alias T = MatT3._T;

    const T a = modelMatrix[0, 0], b = modelMatrix[0, 1], c = modelMatrix[0, 2];
    const T d = modelMatrix[1, 0], e = modelMatrix[1, 1], f = modelMatrix[1, 2];
    const T g = modelMatrix[2, 0], h = modelMatrix[2, 1], i = modelMatrix[2, 2];

    // The inverse of a matrix is its adjugate - the transposed matrix of cofactors - over its
    // determinant. Transposing that again to get the inverse transpose cancels out against the
    // adjugate's own transposition, leaving the plain matrix of cofactors over the determinant.
    // dfmt off
    auto const cofactors = MatT3(
        e * i - f * h, f * g - d * i, d * h - e * g,
        c * h - b * i, a * i - c * g, b * g - a * h,
        b * f - c * e, c * d - a * f, a * e - b * d
    );
    // dfmt on

    const T determinant = a * cofactors[0, 0] + b * cofactors[0, 1] + c * cofactors[0, 2];
    if (determinant == 0) {
        // dfmt off
        return MatT3(
            a, b, c,
            d, e, f,
            g, h, i
        );
        // dfmt on
    }

    const T inverseDeterminant = cast(T) 1 / determinant;
    MatT3 normalMatrix;
    foreach (index; 0 .. 9) {
        normalMatrix[index] = cofactors[index] * inverseDeterminant;
    }

    return normalMatrix;
}

alias toNormalMatrixF = toNormalMatrixT!(Matrix4F, Matrix3F);
alias toNormalMatrixD = toNormalMatrixT!(Matrix4D, Matrix3D);

version (DoublePrecision) {
    alias toNormalMatrix = toNormalMatrixD;
} else {
    alias toNormalMatrix = toNormalMatrixF;
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
MatT createRotationMatrixScalarT(MatT, ScalarT)(const scalar radianAngle, const ScalarT x,
    const ScalarT y, const ScalarT z) {
    const ScalarT x2 = x * x;
    const ScalarT y2 = y * y;
    const ScalarT z2 = z * z;
    static if (is(scalar == float)) {
        alias _cos = cosf;
        alias _sin = sinf;
    } else {
        alias _cos = cos;
        alias _sin = sin;
    }
    auto const cosAngle = _cos(radianAngle);
    auto const sinAngle = _sin(radianAngle);
    auto const omc = 1.0f - cosAngle;

    // dfmt off
    return MatT(
        x2 * omc + cosAngle       ,   y * x * omc + z * sinAngle,   x * z * omc - y * sinAngle,   0,
        x * y * omc - z * sinAngle,   y2 * omc + cosAngle       ,   y * z * omc + x * sinAngle,   0,
        x * z * omc + y * sinAngle,   y * z * omc - x * sinAngle,   z2 * omc + cosAngle       ,   0,
        0                         ,   0                         ,   0                         ,   1
    );
    // dfmt on
}

alias createRotationMatrix4F = createRotationMatrixScalarT!(Matrix4F, float);
alias createRotationMatrix4D = createRotationMatrixScalarT!(Matrix4D, double);

version (DoublePrecision) {
    alias createRotationMatrix4 = createRotationMatrix4D;
} else {
    alias createRotationMatrix4 = createRotationMatrix4F;
}

/**
 * Creates a rotation matrix around the axis defined by a vector.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 *  axis = Vector that serves as the axis around which to rotate.
 */
MatT createRotationMatrixT(VecT, MatT)(const scalar radianAngle, const VecT axis) {
    return createRotationMatrixScalarT!MatT(radianAngle, axis.x, axis.y, axis.z);
}

alias createRotationMatrix4VF = createRotationMatrixT!(Vector3F, Matrix4F);
alias createRotationMatrix4VD = createRotationMatrixT!(Vector3D, Matrix4D);

version (DoublePrecision) {
    alias createRotationMatrix4V = createRotationMatrix4VD;
} else {
    alias createRotationMatrix4V = createRotationMatrix4VF;
}

/**
 * Creates a rotation matrix.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
MatT createRotationMatrixRadianT(MatT)(const scalar radianAngle) {
    static if (is(scalar == float)) {
        alias _cos = cosf;
        alias _sin = sinf;
    } else {
        alias _cos = cos;
        alias _sin = sin;
    }

    // dfmt off
    return MatT(
        _cos(radianAngle), -_sin(radianAngle), 0,
        _sin(radianAngle),  _cos(radianAngle), 0,
        0                ,  0                , 1
    );
    // dfmt on
}

alias createRotationRadianMatrix3F = createRotationMatrixRadianT!Matrix3F;
alias createRotationRadianMatrix3D = createRotationMatrixRadianT!Matrix3D;

version (DoublePrecision) {
    alias createRotationRadianMatrix3 = createRotationRadianMatrix3D;
} else {
    alias createRotationRadianMatrix3 = createRotationRadianMatrix3F;
}

/**
 * Creates a rotation matrix around the X-axis.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
MatT createXRotationMatrixT(MatT)(const scalar radianAngle) {
    // dfmt off
    return MatT(
        1,  0               , 0               , 0,
        0,  cos(radianAngle), sin(radianAngle), 0,
        0, -sin(radianAngle), cos(radianAngle), 0,
        0,  0               , 0               , 1
    );
    // dfmt on
}

alias createXRotationMatrix4F = createXRotationMatrixT!Matrix4F;
alias createXRotationMatrix4D = createXRotationMatrixT!Matrix4D;

version (DoublePrecision) {
    alias createXRotationMatrix = createXRotationMatrix4D;
} else {
    alias createXRotationMatrix = createXRotationMatrix4F;
}

/**
 * Creates a rotation matrix around the Y-axis.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
MatT createYRotationMatrixT(MatT)(const scalar radianAngle) {
    // dfmt off
    return MatT(
        cos(radianAngle), 0, -sin(radianAngle), 0,
        0               , 1,  0               , 0,
        sin(radianAngle), 0,  cos(radianAngle), 0,
        0               , 0,  0               , 1
    );
    // dfmt on
}

alias createYRotationMatrix4F = createYRotationMatrixT!Matrix4F;
alias createYRotationMatrix4D = createYRotationMatrixT!Matrix4D;

version (DoublePrecision) {
    alias createYRotationMatrix = createYRotationMatrix4D;
} else {
    alias createYRotationMatrix = createYRotationMatrix4F;
}

/**
 * Creates a rotation matrix around the Z-axis.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
MatT createZRotationMatrixT(MatT)(const scalar radianAngle) {
    // dfmt off
    return MatT(
        cos(radianAngle), -sin(radianAngle), 0, 0,
        sin(radianAngle),  cos(radianAngle), 0, 0,
        0               ,  0               , 1, 0,
        0               ,  0               , 0, 1
    );
    // dfmt on
}

alias createZRotationMatrix4F = createZRotationMatrixT!Matrix4F;
alias createZRotationMatrix4D = createZRotationMatrixT!Matrix4D;

version (DoublePrecision) {
    alias createZRotationMatrix = createZRotationMatrix4D;
} else {
    alias createZRotationMatrix = createZRotationMatrix4F;
}

/**
 * Creates a world transformation matrix that looks at a target vector.
 */
MatT createLookatMatrixT(VecT, UnitVecT, MatT)(const VecT eyePosition,
    const VecT targetPosition, const UnitVecT upVector) {

    auto const forwardVector = (targetPosition - eyePosition).normalize();
    auto const sideVector = forwardVector.cross(upVector.vector);
    auto const cameraBasedUpVector = sideVector.cross(forwardVector);

    // dfmt off
    return MatT(
         sideVector.x         ,  sideVector.y         ,  sideVector.z         , -eyePosition.x,
         cameraBasedUpVector.x,  cameraBasedUpVector.y,  cameraBasedUpVector.z, -eyePosition.y,
        -forwardVector.x      , -forwardVector.y      , -forwardVector.z      , -eyePosition.z,
         0                    ,  0                    ,  0                    ,  1
    );
    // dfmt on
}

alias createLookatMatrix4F = createLookatMatrixT!(Vector3F, UnitVector3F, Matrix4F);
alias createLookatMatrix4D = createLookatMatrixT!(Vector3D, UnitVector3D, Matrix4D);

version (DoublePrecision) {
    alias createLookatMatrix = createLookatMatrix4D;
} else {
    alias createLookatMatrix = createLookatMatrix4F;
}

/**
 * Creates a world transformation matrix that looks at the world with a specified pitch 
 * (up/down rotation) and yaw (left/right rotation).
 */
MatT createViewMatrixT(VecT, MatT)(VecT eyePosition, scalar pitchInRadian, scalar yawInRadian) {
    const scalar cosPitch = cos(pitchInRadian);
    const scalar sinPitch = sin(pitchInRadian);
    const scalar cosYaw = cos(yawInRadian);
    const scalar sinYaw = sin(yawInRadian);

    auto const sideVector = VecT(cosYaw, 0, -sinYaw);
    auto const upVector = VecT(sinYaw * sinPitch, cosPitch, cosYaw * sinPitch);
    auto const forwardVector = VecT(sinYaw * cosPitch, -sinPitch, cosPitch * cosYaw);

    // dfmt off
    return MatT(
        sideVector.x   , sideVector.y   , sideVector.z   , -sideVector.dot(eyePosition),
        upVector.x     , upVector.y     , upVector.z     , -upVector.dot(eyePosition),
        forwardVector.x, forwardVector.y, forwardVector.z, -forwardVector.dot(eyePosition),
        0              , 0              , 0              ,  1
    );
    // dfmt on
}

alias createViewMatrix4F = createViewMatrixT!(Vector3F, Matrix4F);
alias createViewMatrix4D = createViewMatrixT!(Vector3D, Matrix4D);

version (DoublePrecision) {
    alias createViewMatrix = createViewMatrix4D;
} else {
    alias createViewMatrix = createViewMatrix4F;
}

MatT createViewMatrixQT(VecT, QuatT, MatT)(VecT eyePosition, QuatT eyeOrientation) {
    return eyeOrientation.inverse.toRotationMatrix * (-eyePosition)
        .toTranslationMatrix4T!(VecT, MatT);
}

alias createViewMatrix4QF = createViewMatrixQT!(Vector3F, QuaternionF, Matrix4F);
alias createViewMatrix4QD = createViewMatrixQT!(Vector3D, QuaternionD, Matrix4D);

version (DoublePrecision) {
    alias createViewMatrixQ = createViewMatrix4QD;
} else {
    alias createViewMatrixQ = createViewMatrix4QF;
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
MatT createPerspectiveMatrixT(MatT)(scalar yfovRadian, scalar aspectRatio,
    scalar near, scalar far) {
    const scalar A = 1.0 / (aspectRatio * tan(0.5 * yfovRadian));
    const scalar B = 1.0 / (tan(0.5 * yfovRadian));
    const scalar C = far == 0 ? -1 : (far + near) / (near - far);
    const scalar D = far == 0 ? (-2 * near) : (2.0 * far * near) / (near - far);

    // dfmt off
    return MatT(
        A, 0,  0, 0,
        0, B,  0, 0,
        0, 0,  C, D,
        0, 0, -1, 0
    );
    // dfmt on
}

alias createPerspectiveMatrix4F = createPerspectiveMatrixT!Matrix4F;
alias createPerspectiveMatrix4D = createPerspectiveMatrixT!Matrix4D;

version (DoublePrecision) {
    alias createPerspectiveMatrix = createPerspectiveMatrix4D;
} else {
    alias createPerspectiveMatrix = createPerspectiveMatrix4F;
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
MatT createOrthographicMatrixT(MatT)(scalar left, scalar right, scalar bottom, scalar top, scalar near, scalar far) {
    return createOrthographicMatrixHT!MatT(right - left, top - bottom, near, far);
}

alias createOrthographicMatrix4F = createOrthographicMatrixT!Matrix4F;
alias createOrthographicMatrix4D = createOrthographicMatrixT!Matrix4D;

version (DoublePrecision) {
    alias createOrthographicMatrix = createOrthographicMatrix4D;
} else {
    alias createOrthographicMatrix = createOrthographicMatrix4F;
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
MatT createOrthographicMatrixHT(MatT)(scalar halfWidth, scalar halfHeight, scalar near, scalar far) {
    const scalar A = 1 / (halfWidth / 2);
    const scalar B = 1 / (halfHeight / 2);
    const scalar C = 2 / (near - far);
    const scalar D = (far + near) / (near - far);

    // dfmt off
    return MatT(
        A, 0 , 0, 0,
        0, B , 0, 0,
        0, 0 , C, D,
        0, 0 , 0, 1
    );
    // dfmt on
}

alias createOrthographicMatrix4HF = createOrthographicMatrixHT!Matrix4F;
alias createOrthographicMatrix4HD = createOrthographicMatrixHT!Matrix4D;

version (DoublePrecision) {
    alias createOrthographicMatrixH = createOrthographicMatrix4HD;
} else {
    alias createOrthographicMatrixH = createOrthographicMatrix4HF;
}

/**
 * Converts an angle in degrees to radians.
 */
T degreesToRadiansT(T)(T degrees) {
    return degrees * (PI / 180);
}

alias degreesToRadiansF = degreesToRadiansT!float;
alias degreesToRadiansD = degreesToRadiansT!double;

version (DoublePrecision) {
    alias degreesToRadians = degreesToRadiansD;
} else {
    alias degreesToRadians = degreesToRadiansF;
}

/**
 * Converts an angle in radians to degrees.
 */
T radiansToDegreesT(T)(T radians) {
    return radians * (180 / PI);
}

alias radiansToDegreesF = radiansToDegreesT!float;
alias radiansToDegreesD = radiansToDegreesT!double;

version (DoublePrecision) {
    alias radiansToDegrees = radiansToDegreesD;
} else {
    alias radiansToDegrees = radiansToDegreesF;
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

    // The arc functions are the platform's on native and the engine's own on
    // WebAssembly, so these are here to hold the two to the same answers.
    test("atan", {
        assert(approxEqual(atan(0.0), 0.0, 0.0001));
        assert(approxEqual(atan(0.1), 0.099668, 0.0001));
        assert(approxEqual(atan(0.5), 0.463647, 0.0001));
        assert(approxEqual(atan(1.0), 0.785398, 0.0001));
        assert(approxEqual(atan(2.0), 1.107148, 0.0001));
        assert(approxEqual(atan(100.0), 1.560796, 0.0001));

        assert(approxEqual(atan(-0.5), -0.463647, 0.0001));
        assert(approxEqual(atan(-1.0), -0.785398, 0.0001));
        assert(approxEqual(atan(-2.0), -1.107148, 0.0001));
    });

    test("atan2", {
        assert(approxEqual(atan2(0.0, 1.0), 0.0, 0.0001));
        assert(approxEqual(atan2(1.0, 1.0), 0.785398, 0.0001));
        assert(approxEqual(atan2(1.0, 0.0), 1.570796, 0.0001));
        assert(approxEqual(atan2(1.0, -1.0), 2.356194, 0.0001));
        assert(approxEqual(atan2(-1.0, -1.0), -2.356194, 0.0001));
        assert(approxEqual(atan2(-1.0, 1.0), -0.785398, 0.0001));

        // The two the look-around leans on: the height a direction reaches over
        // the height it holds up is the angle it is looking up by.
        assert(approxEqual(atan2(0.5, 0.866025), 0.523598, 0.0001));
        assert(approxEqual(atan2(-0.5, 0.866025), -0.523598, 0.0001));
    });

    test("asin", {
        assert(approxEqual(asin(0.0), 0.0, 0.0001));
        assert(approxEqual(asin(0.5), 0.523598, 0.0001));
        assert(approxEqual(asin(1.0), 1.570796, 0.0001));
        assert(approxEqual(asin(-0.5), -0.523598, 0.0001));
    });

    test("acos", {
        assert(approxEqual(acos(1.0), 0.0, 0.0001));
        assert(approxEqual(acos(0.5), 1.047197, 0.0001));
        assert(approxEqual(acos(0.0), 1.570796, 0.0001));
        assert(approxEqual(acos(-0.5), 2.094395, 0.0001));
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

    test("Multiply vectors with two components component-wise", {
        auto const vector1 = Vector2U(2, 8);
        auto const vector2 = Vector2U(3, 4);
        auto const multipliedVector = vector1 * vector2;
        assert(6 == multipliedVector.x);
        assert(32 == multipliedVector.y);
    });

    test("Divide vectors with two components component-wise", {
        auto const vector1 = Vector2U(6, 32);
        auto const vector2 = Vector2U(3, 4);
        auto const dividedVector = vector1 / vector2;
        assert(2 == dividedVector.x);
        assert(8 == dividedVector.y);
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

    test("Multiply vectors with three components component-wise", {
        auto const vector1 = Vector3U(2, 8, 4);
        auto const vector2 = Vector3U(3, 4, 5);
        auto const multipliedVector = vector1 * vector2;
        assert(6 == multipliedVector.x);
        assert(32 == multipliedVector.y);
        assert(20 == multipliedVector.z);
    });

    test("Component-wise multiplication is not the dot or cross product", {
        auto const vector1 = Vector3D(1, 2, 3);
        auto const vector2 = Vector3D(4, 5, 6);
        auto const hadamardProduct = vector1 * vector2;
        assert(Vector3D(4, 10, 18) == hadamardProduct);
        assert(32 == vector1.dot(vector2));
        assert(Vector3D(-3, 6, -3) == vector1.cross(vector2));
    });

    test("Divide vectors with three components component-wise", {
        auto const vector1 = Vector3U(6, 32, 20);
        auto const vector2 = Vector3U(3, 4, 5);
        auto const dividedVector = vector1 / vector2;
        assert(2 == dividedVector.x);
        assert(8 == dividedVector.y);
        assert(4 == dividedVector.z);
    });

    test("Component-wise division undoes component-wise multiplication", {
        auto const vector = Vector3D(1, 2, 3);
        auto const factor = Vector3D(4, 5, 6);
        assert(vector == vector * factor / factor);
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
        assert("(1.000000)" == VectorT!(double, 1)(1).toString());
        assert("(1.000000, 2.000000)" == Vector2D(1, 2).toString());
        assert("(1.000000, 2.000000, 3.000000)" == Vector3D(1, 2, 3).toString());
        assert("(5)" == VectorT!(int, 1)(5).toString());
        assert("(5, 6)" == Vector2I(5, 6).toString());
        assert("(5, 6, 7)" == Vector3I(5, 6, 7).toString());
        assert("(0.000000, 0.000000, 0.000000)" == Vector3D(0).toString());
        assert("(1.600000)" == VectorT!(double, 1)(1.6).toString());
        assert("(1.840000, 2.400000)" == Vector2D(1.84, 2.4).toString());
        assert("(1.300000, 2.750000, 3.782000)" == Vector3D(1.3, 2.75, 3.782).toString());
    });

    test("To hash", {
        auto const vector1Hash = Vector2D(1.2, 3.4).toHash;
        auto const vector2Hash = Vector2D(1.2, 3.4).toHash;
        auto const vector3Hash = Vector3U(1, 2, 3).toHash;
        auto const vector4Hash = VectorT!(ulong, 1)(7).toHash;
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
        auto matrix1 = MatrixT!(double, 4, 3)(0);
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
        auto const matrix = MatrixT!(double, 4, 1)(1, 2, 3, 4);
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
        auto const matrix1 = MatrixT!(double, 2, 3)(
            1, 2, 3,
            4, 5, 6
        );

        auto const matrix2 = MatrixT!(double, 3, 2)(
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
        auto const matrix = MatrixT!(double, 2, 3)(
            1, 2, 3,
            4, 5, 6
        );

        auto const expectedMatrix = MatrixT!(double, 3, 2)(
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
        auto const quaternionD = QuaternionD();
        assert(QuaternionD(1, 0, 0, 0) == quaternionD);

        auto const quaternionF = QuaternionF();
        assert(QuaternionF(1, 0, 0, 0) == quaternionF);

        auto const quaternion = Quaternion();
        assert(Quaternion(1, 0, 0, 0) == quaternion);

        auto const quaternion2D = QuaternionD(4, 1, 2, 3);
        assert(4 == quaternion2D.w);
        assert(1 == quaternion2D.x);
        assert(2 == quaternion2D.y);
        assert(3 == quaternion2D.z);

        auto const quaternion2F = QuaternionF(4, 1, 2, 3);
        assert(4 == quaternion2F.w);
        assert(1 == quaternion2F.x);
        assert(2 == quaternion2F.y);
        assert(3 == quaternion2F.z);

        auto const quaternion3D = QuaternionD(4, Vector3D(1, 2, 3));
        assert(4 == quaternion3D.w);
        assert(1 == quaternion3D.x);
        assert(2 == quaternion3D.y);
        assert(3 == quaternion3D.z);

        auto const quaternion3F = QuaternionF(4, Vector3F(1, 2, 3));
        assert(4 == quaternion3F.w);
        assert(1 == quaternion3F.x);
        assert(2 == quaternion3F.y);
        assert(3 == quaternion3F.z);
    });

    test("Create quaternions", {
        auto const quaternion1D = QuaternionD(1, 2, 3, 4);
        auto const quaternion2D = QuaternionD(5, 6, 7, 8);
        auto const expectedQuaternionD = QuaternionD(-60, 12, 30, 24);
        auto const actualQuaternionD = quaternion1D * quaternion2D;
        assert(expectedQuaternionD == actualQuaternionD);
        assert(quaternion1D * quaternion2D != quaternion2D * quaternion1D);

        auto const quaternion1F = QuaternionF(1, 2, 3, 4);
        auto const quaternion2F = QuaternionF(5, 6, 7, 8);
        auto const expectedQuaternionF = QuaternionF(-60, 12, 30, 24);
        auto const actualQuaternionF = quaternion1F * quaternion2F;
        assert(expectedQuaternionF == actualQuaternionF);
        assert(quaternion1F * quaternion2F != quaternion2F * quaternion1F);
    });

    test("Create from angle and axis vector", {
        auto const quaternionD = QuaternionD.createRotation(PI, Vector3D(1, 0, 0));
        assert(quaternionD.realPart.approxEqual(6.12303e-17));
        assert(quaternionD.imaginaryVector == Vector3D(1, 0, 0));

        auto const quaternionF = QuaternionF.createRotation(PI, Vector3F(1, 0, 0));
        assert(quaternionF.realPart.approxEqual(6.12303e-17, 0.0001));
        assert(quaternionF.imaginaryVector == Vector3F(1, 0, 0));
    });

    test("Convert to rotation matrix", {
        auto const quaternionD = QuaternionD(6.12303e-17, 1, 0, 0);
        auto const actualRotationMatrixD = quaternionD.toRotationMatrix();
        assert(actualRotationMatrixD.data.approxEquals([
                1, 0, 0, 0, 0, -1, -1.22461e-16, 0, 0, 1.22461e-16, -1, 0, 0, 0, 0,
                1
            ]));

        auto const quaternionF = QuaternionF(6.12303e-17, 1, 0, 0);
        auto const actualRotationMatrixF = quaternionF.toRotationMatrix();
        assert(actualRotationMatrixF.data.approxEquals([
                1.0f, 0.0f, 0.0f, 0.0f, 0.0f, -1.0f, -1.22461e-16f, 0.0f, 0.0f,
                1.22461e-16f, -1.0f, 0.0f, 0.0f, 0.0f, 0.0f,
                1.0f
            ]));
    });

    test("Convert to euler angles vector", {
        auto const quaternionD = QuaternionD.createRotation(PI, Vector3D(0, 1, 0));
        auto const expectedToEulerAnglesD = Vector3D(0, PI, 0);
        auto const actualEulerAnglesD = quaternionD.toEulerAngles();
        assert(expectedToEulerAnglesD == actualEulerAnglesD);

        auto const quaternion2D = QuaternionD.createRotation(PI, Vector3D(1, 0, 0));
        auto const expectedToEulerAngles2D = Vector3D(PI, 0, 0);
        auto const actualEulerAngles2D = quaternion2D.toEulerAngles();
        assert(expectedToEulerAngles2D == actualEulerAngles2D);

        // Float precision requires larger tolerance for near-singular cases
        auto const quaternionF = QuaternionF.createRotation(PI, Vector3F(0, 1, 0));
        auto const actualEulerAnglesF = quaternionF.toEulerAngles();
        assert(actualEulerAnglesF.x.approxEqual(0, 0.001));
        // atan2 can return PI or -PI for 180° rotation, both are equivalent
        assert(actualEulerAnglesF.y.approxEqual(PI, 0.001) || actualEulerAnglesF.y.approxEqual(-PI, 0.001));
        assert(actualEulerAnglesF.z.approxEqual(0, 0.001));

        auto const quaternion2F = QuaternionF.createRotation(PI, Vector3F(1, 0, 0));
        auto const actualEulerAngles2F = quaternion2F.toEulerAngles();
        // atan2 can return PI or -PI for 180° rotation, both are equivalent
        assert(actualEulerAngles2F.x.approxEqual(PI, 0.001) || actualEulerAngles2F.x.approxEqual(-PI, 0.001));
        assert(actualEulerAngles2F.y.approxEqual(0, 0.001));
        assert(actualEulerAngles2F.z.approxEqual(0, 0.001));
    });

    test("Angle", {
        auto const quaternionD = QuaternionD.createRotation(PI, Vector3D(0, 1, 0));
        assert(quaternionD.angle.approxEqual(PI));

        auto const quaternionF = QuaternionF.createRotation(PI, Vector3F(0, 1, 0));
        assert(quaternionF.angle.approxEqual(PI, 0.0001));
    });

    test("Axis when rotation is zero", {
        auto const quaternionD = QuaternionD.createRotation(0, Vector3D(0, 1, 0));
        assert(quaternionD.axis == Vector3D(0, 1, 0));

        auto const quaternionF = QuaternionF.createRotation(0, Vector3F(0, 1, 0));
        import retrograde.std.stdio : writeln;

        writeln(quaternionF.axis.x);
        writeln(quaternionF.axis.y);
        writeln(quaternionF.axis.z);
        assert(quaternionF.axis == Vector3F(0, 1, 0));
    });

    test("Axis when rotation is non-zero", {
        auto const quaternionD = QuaternionD.createRotation(PI, Vector3D(0, 0, 1));
        assert(quaternionD.axis == Vector3D(0, 0, 1));

        auto const quaternionF = QuaternionF.createRotation(PI, Vector3F(0, 0, 1));
        assert(quaternionF.axis == Vector3F(0, 0, 1));
    });

    test("Conjugate", {
        auto const quaternionD = QuaternionD(1, 2, 3, 4);
        assert(quaternionD.conjugate == QuaternionD(1, -2, -3, -4));

        auto const quaternionF = QuaternionF(1, 2, 3, 4);
        assert(quaternionF.conjugate == QuaternionF(1, -2, -3, -4));
    });

    test("Inverse", {
        auto const quaternionD = QuaternionD(1, 2, 3, 4);
        auto const inverseD = quaternionD.inverse;
        assert(inverseD.w.approxEqual(0.0333333, 0.01));
        assert(inverseD.x.approxEqual(-0.0666667, 0.01));
        assert(inverseD.y.approxEqual(-0.1, 0.1));
        assert(inverseD.z.approxEqual(-0.1333333, 0.01));

        auto const quaternionF = QuaternionF(1, 2, 3, 4);
        auto const inverseF = quaternionF.inverse;
        assert(inverseF.w.approxEqual(0.0333333, 0.01));
        assert(inverseF.x.approxEqual(-0.0666667, 0.01));
        assert(inverseF.y.approxEqual(-0.1, 0.1));
        assert(inverseF.z.approxEqual(-0.1333333, 0.01));
    });

    test("Dot product", {
        auto const quaternion1D = QuaternionD(1, 2, 3, 4);
        auto const quaternion2D = QuaternionD(5, 6, 7, 8);
        assert(quaternion1D.dot(quaternion2D) == 70);

        auto const quaternion1F = QuaternionF(1, 2, 3, 4);
        auto const quaternion2F = QuaternionF(5, 6, 7, 8);
        assert(quaternion1F.dot(quaternion2F) == 70);
    });

    test("Multiply", {
        auto const quaternion1D = QuaternionD(1, 2, 3, 4);
        auto const quaternion2D = QuaternionD(5, 6, 7, 8);
        assert(quaternion1D * quaternion2D == QuaternionD(-60, 12, 30, 24));

        auto const quaternion1F = QuaternionF(1, 2, 3, 4);
        auto const quaternion2F = QuaternionF(5, 6, 7, 8);
        assert(quaternion1F * quaternion2F == QuaternionF(-60, 12, 30, 24));
    });
}

void runMatrixUtilTests() {
    writeSection("-- Matrix util tests --");

    test("Create translation matrix from 2D vector", {
        auto const vectorD = Vector2D(25, 56);
        // dfmt off
        auto const expectedMatrixD = Matrix3D(
            1, 0, 25,
            0, 1, 56,
            0, 0, 1
        );
        // dfmt on
        auto const actualMatrixD = vectorD.toTranslationMatrix3D();
        assert(expectedMatrixD == actualMatrixD);

        auto const vectorF = Vector2F(25, 56);
        // dfmt off
        auto const expectedMatrixF = Matrix3F(
            1, 0, 25,
            0, 1, 56,
            0, 0, 1
        );
        // dfmt on
        auto const actualMatrixF = vectorF.toTranslationMatrix3F();
        assert(expectedMatrixF == actualMatrixF);
    });

    test("Create translation matrix from 3D vector", {
        auto const vectorD = Vector3D(2, 5, 6);
        // dfmt off
        auto const expectedMatrixD = Matrix4D(
            1, 0, 0, 2,
            0, 1, 0, 5,
            0, 0, 1, 6,
            0, 0, 0, 1
        );
        // dfmt on
        auto const actualMatrixD = vectorD.toTranslationMatrix4D();
        assert(expectedMatrixD == actualMatrixD);

        auto const vectorF = Vector3F(2, 5, 6);
        // dfmt off
        auto const expectedMatrixF = Matrix4F(
            1, 0, 0, 2,
            0, 1, 0, 5,
            0, 0, 1, 6,
            0, 0, 0, 1
        );
        // dfmt on
        auto const actualMatrixF = vectorF.toTranslationMatrix4F();
        assert(expectedMatrixF == actualMatrixF);
    });

    test("Create scaling matrix from 2D vector", {
        auto const vectorD = Vector2D(6, 12);
        // dfmt off
        auto const expectedMatrixD = Matrix3D(
            6, 0 , 0,
            0, 12, 0,
            0, 0 , 1
        );
        // dfmt on
        auto const actualMatrixD = vectorD.toScalingMatrix3D();
        assert(expectedMatrixD == actualMatrixD);

        auto const vectorF = Vector2F(6, 12);
        // dfmt off
        auto const expectedMatrixF = Matrix3F(
            6, 0 , 0,
            0, 12, 0,
            0, 0 , 1
        );
        // dfmt on
        auto const actualMatrixF = vectorF.toScalingMatrix3F();
        assert(expectedMatrixF == actualMatrixF);
    });

    test("Create scaling matrix from 3D vector", {
        auto const vectorD = Vector3D(1, 2, 5);
        // dfmt off
        auto const expectedMatrixD = Matrix4D(
            1, 0, 0, 0,
            0, 2, 0, 0,
            0, 0, 5, 0,
            0, 0, 0, 1
        );
        // dfmt on
        auto const actualMatrixD = vectorD.toScalingMatrix4D();
        assert(expectedMatrixD == actualMatrixD);

        auto const vectorF = Vector3F(1, 2, 5);
        // dfmt off
        auto const expectedMatrixF = Matrix4F(
            1, 0, 0, 0,
            0, 2, 0, 0,
            0, 0, 5, 0,
            0, 0, 0, 1
        );
        // dfmt on
        auto const actualMatrixF = vectorF.toScalingMatrix4F();
        assert(expectedMatrixF == actualMatrixF);
    });

    test("Create normal matrix from a rotation matrix", {
        // A rotation is its own inverse transpose, so it comes back out unchanged.
        auto const modelMatrixD = createRotationMatrix4D(PI / 4, 0, 1, 0);
        auto const expectedMatrixD = Matrix3D(
            modelMatrixD[0, 0], modelMatrixD[0, 1], modelMatrixD[0, 2],
            modelMatrixD[1, 0], modelMatrixD[1, 1], modelMatrixD[1, 2],
            modelMatrixD[2, 0], modelMatrixD[2, 1], modelMatrixD[2, 2]
        );
        auto const actualMatrixD = modelMatrixD.toNormalMatrixD();
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        auto const modelMatrixF = createRotationMatrix4F(PI / 4, 0, 1, 0);
        auto const expectedMatrixF = Matrix3F(
            modelMatrixF[0, 0], modelMatrixF[0, 1], modelMatrixF[0, 2],
            modelMatrixF[1, 0], modelMatrixF[1, 1], modelMatrixF[1, 2],
            modelMatrixF[2, 0], modelMatrixF[2, 1], modelMatrixF[2, 2]
        );
        auto const actualMatrixF = modelMatrixF.toNormalMatrixF();
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));
    });

    test("Create normal matrix from a uniform scaling matrix", {
        // dfmt off
        auto const expectedMatrixD = Matrix3D(
            0.5, 0  , 0,
            0  , 0.5, 0,
            0  , 0  , 0.5
        );
        // dfmt on
        auto const actualMatrixD = Vector3D(2, 2, 2).toScalingMatrix4D().toNormalMatrixD();
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));
    });

    test("Normal matrix keeps normals perpendicular under non-uniform scale", {
        // A surface whose tangent and normal stand perpendicular before the model matrix is
        // applied. They only stay that way when the normal is transformed by the normal matrix.
        auto const tangent = Vector3D(1, 1, 0);
        auto const normal = Vector3D(1, -1, 0);
        assert(tangent.dot(normal) == 0);

        auto const modelMatrix = Vector3D(2, 1, 1).toScalingMatrix4D();
        auto const transformedTangent4 = modelMatrix * Vector4D(tangent.x, tangent.y, tangent.z, 0);
        auto const transformedTangent = Vector3D(transformedTangent4.x, transformedTangent4.y,
            transformedTangent4.z);

        auto const modelTransformedNormal4 = modelMatrix * Vector4D(normal.x, normal.y, normal.z, 0);
        auto const modelTransformedNormal = Vector3D(modelTransformedNormal4.x,
            modelTransformedNormal4.y, modelTransformedNormal4.z);
        assert(!approxEqual(transformedTangent.dot(modelTransformedNormal), 0.0));

        auto const normalMatrix = modelMatrix.toNormalMatrixD();
        auto const transformedNormal = normalMatrix * normal;
        assert(approxEqual(transformedTangent.dot(transformedNormal), 0.0));
    });

    test("Create normal matrix from a model matrix that cannot be inverted", {
        // dfmt off
        auto const expectedMatrixD = Matrix3D(
            1, 0, 0,
            0, 1, 0,
            0, 0, 0
        );
        // dfmt on
        auto const actualMatrixD = Vector3D(1, 1, 0).toScalingMatrix4D().toNormalMatrixD();
        assert(expectedMatrixD == actualMatrixD);
    });

    test("Create 4D rotation matrix", {
        auto const expectedMatrixD = MatrixT!(double, 4u, 4u)(
            -1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1
        );
        auto actualMatrix1D = createRotationMatrix4D(PI, 0, 1, 0);
        assert(expectedMatrixD.data.approxEquals(actualMatrix1D.data));
        auto actualMatrix2D = createRotationMatrix4VD(PI, Vector3D(0, 1, 0));
        assert(expectedMatrixD.data.approxEquals(actualMatrix2D.data));
        assert(actualMatrix1D.data.approxEquals(actualMatrix2D.data));

        auto const expectedMatrixF = MatrixT!(float, 4u, 4u)(
            -1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1
        );
        auto actualMatrix1F = createRotationMatrix4F(PI, 0, 1, 0);
        assert(expectedMatrixF.data.approxEquals(actualMatrix1F.data));
        auto actualMatrix2F = createRotationMatrix4VF(PI, Vector3F(0, 1, 0));
        assert(expectedMatrixF.data.approxEquals(actualMatrix1F.data));
        assert(actualMatrix1F.data.approxEquals(actualMatrix2F.data));
    });

    test("Create 3D rotation matrix", {
        auto const expectedMatrixD = MatrixT!(double, 3u, 3u)(-0.989992, -0.14112, 0, 0.14112, -0.989992, 0, 0, 0, 1);
        auto actualMatrixD = createRotationRadianMatrix3D(3);
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        auto const expectedMatrixF = MatrixT!(float, 3u, 3u)(-0.989992, -0.14112, 0, 0.14112, -0.989992, 0, 0, 0, 1);
        auto actualMatrixF = createRotationRadianMatrix3F(3);
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));
    });

    test("Create axis-bound rotation matrices", {
        auto expectedMatrixD = MatrixT!(double, 4u, 4u)(1, 0, 0, 0, 0, -1, 1.22461e-16, 0, 0, -1.22461e-16, -1, 0, 0, 0, 0, 1);
        auto actualMatrixD = createXRotationMatrix4D(PI);
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        expectedMatrixD = MatrixT!(double, 4u, 4u)(-1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1);
        actualMatrixD = createYRotationMatrix4D(PI);
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        expectedMatrixD = MatrixT!(double, 4u, 4u)(-1, -1.22461e-16, 0, 0, 1.22461e-16, -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
        actualMatrixD = createZRotationMatrix4D(PI);
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        auto expectedMatrixF = MatrixT!(float, 4u, 4u)(1, 0, 0, 0, 0, -1, 1.22461e-16, 0, 0, -1.22461e-16, -1, 0, 0, 0, 0, 1);
        auto actualMatrixF = createXRotationMatrix4F(PI);
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));

        expectedMatrixF = MatrixT!(float, 4u, 4u)(-1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1);
        actualMatrixF = createYRotationMatrix4F(PI);
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));

        expectedMatrixF = MatrixT!(float, 4u, 4u)(-1, -1.22461e-16, 0, 0, 1.22461e-16, -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1);
        actualMatrixF = createZRotationMatrix4F(PI);
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));
    });

    test("Create look-at matrix", {
        auto const expectedMatrixD = MatrixT!(double, 4u, 4u)(0, 0, 1, -0, 0, 1, 0, -1, -1, -0, -0, -0, 0, 0, 0, 1);
        auto actualMatrixD = createLookatMatrix4D(Vector3D(0, 1, 0), Vector3D(1,
            1, 0), UnitVector3D(0, 1, 0));
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        auto const expectedMatrixF = MatrixT!(float, 4u, 4u)(0, 0, 1, -0, 0, 1, 0, -1, -1, -0, -0, -0, 0, 0, 0, 1);
        auto actualMatrixF = createLookatMatrix4F(Vector3F(0, 1, 0), Vector3F(1,
            1, 0), UnitVector3F(0, 1, 0));
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));
    });

    test("Create view matrix", {
        auto const expectedMatrixD = MatrixT!(double, 4u, 4u)(0.540302, 0, -0.841471, -0.540302, 0.708073, 0.540302, 0.454649, -1.24838, 0.454649, -0.841471, 0.291927, 0.386822, 0, 0, 0, 1);
        auto actualMatrixD = createViewMatrix4D(Vector3D(1, 1, 0), 1, 1);
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        auto const expectedMatrixF = MatrixT!(float, 4u, 4u)(0.540302, 0, -0.841471, -0.540302, 0.708073, 0.540302, 0.454649, -1.24838, 0.454649, -0.841471, 0.291927, 0.386822, 0, 0, 0, 1);
        auto actualMatrixF = createViewMatrix4F(Vector3F(1, 1, 0), 1, 1);
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));
    });

    test("Create perspective matrix", {
        auto const expectedMatrixD = MatrixT!(double, 4u, 4u)(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1.0002, -0.20002, 0, 0, -1, 0);
        auto actualMatrixD = createPerspectiveMatrix4D(degreesToRadiansD(90), 1920 / 1080, 0.1, 1000);
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        auto const expectedMatrixF = MatrixT!(float, 4u, 4u)(1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1.0002, -0.20002, 0, 0, -1, 0);
        auto actualMatrixF = createPerspectiveMatrix4F(degreesToRadiansF(90), 1920 / 1080, 0.1, 1000);
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));
    });

    test("Create orthographic matrix", {
        auto const expectedMatrixD = MatrixT!(double, 4u, 4u)(0.2, 0, 0, 0, 0, 0.2, 0, 0, 0, 0, -0.2, -0, 0, 0, 0, 1);
        auto actualMatrixD = createOrthographicMatrix4D(-5, 5, -5, 5, -5, 5);
        assert(expectedMatrixD.data.approxEquals(actualMatrixD.data));

        auto const expectedMatrixF = MatrixT!(float, 4u, 4u)(0.2, 0, 0, 0, 0, 0.2, 0, 0, 0, 0, -0.2, -0, 0, 0, 0, 1);
        auto actualMatrixF = createOrthographicMatrix4F(-5, 5, -5, 5, -5, 5);
        assert(expectedMatrixF.data.approxEquals(actualMatrixF.data));
    });
}

void runMiscUtilTests() {
    writeSection("-- Misc util tests --");

    test("Convert degrees to radians", {
        assert(PI.approxEqual(degreesToRadiansD(180)));
        assert(0.0.approxEqual(degreesToRadiansD(0)));
        assert((2 * PI).approxEqual(degreesToRadiansD(360)));

        assert(PI.approxEqual(degreesToRadiansF(180), 0.0001));
        assert(0f.approxEqual(degreesToRadiansF(0)));
        assert((2 * PI).approxEqual(degreesToRadiansF(360), 0.0001));
    });

    test("Convert radians to degrees", {
        assert(180 == radiansToDegreesD(PI));
        assert(0 == radiansToDegreesD(0));
        assert(360 == radiansToDegreesD(2 * PI));

        assert(180.0f.approxEqual(radiansToDegreesF(PI), 0.0001));
        assert(0 == radiansToDegreesF(0));
        assert(360.0f.approxEqual(radiansToDegreesF(2 * PI), 0.0001));
    });
}
