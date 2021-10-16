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

import std.math : sqrt, atan2, PI, cos, sin, tan, asin;
import std.conv : to;
import std.string : join;

import retrograde.core.functional : map;

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
        public @property scalar magnitude() const {
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
            hash *= components[i] * i + 1;
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
        string[] componentStrings;

        static foreach (i; 0 .. N) {
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
    public @property VectorType vector() const {
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

    public alias _T = T;
    public alias _Rows = Rows;
    public alias _Columns = Columns;
    public alias _VectorType = Vector!(T, Rows);

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
        public static @property Matrix identity() {
            return identityMatrix;
        }

        static this() {
            static foreach (row; 0 .. Rows) {
                static foreach (column; 0 .. Columns) {
                    identityMatrix[row, column] = column == row ? 1 : 0;
                }
            }
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

        //TODO: This looks like it could use some improvement. Certainly less allocation!
        Matrix!(T, Rows, OtherColumns) resultMatrix;
        auto transposedRhs = rhs.transpose();
        Vector!(T, Columns)[OtherColumns] columnCache;

        static foreach (thisRow; 0 .. Rows) {
            {
                auto rowVector = getRowVector(thisRow);
                static foreach (otherColumn; 0 .. OtherColumns) {
                    if (thisRow == 0) {
                        columnCache[otherColumn] = transposedRhs.getRowVector(otherColumn);
                    }

                    resultMatrix[thisRow, otherColumn] = rowVector.dot(columnCache[otherColumn]);
                }
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

    /**
     * Returns a copy of this matrix whjere all rows and columns are flipped.
     */
    Matrix!(T, Columns, Rows) transpose() const {
        auto transposedData = getTransposedDataArray();
        return Matrix!(T, Columns, Rows)(transposedData);
    }

    /**
     * Returns a certain row of this matix as vector.
     */
    Vector!(T, Columns) getRowVector(const size_t row) const {
        return Vector!(T, Columns)(data[row * Columns .. (row * Columns) + Columns]);
    }

    /**
     * Returns the values of this matrix as continuous array.
     *
     * The array is row-major.
     */
    public CastType[Rows * Columns] getDataArray(CastType = T)() const {
        static if (is(CastType == T)) {
            return data;
        } else {
            return data.map((T v) => cast(CastType) v);
        }
    }

    /**
     * Returns the values of this matrix as continuous array, but transposed.
     *
     * This essentially turns the array into a column-major array.
     */
    public CastType[Rows * Columns] getTransposedDataArray(CastType = T)() const {
        CastType[Rows * Columns] transposedData;
        static foreach (row; 0 .. Rows) {
            static foreach (column; 0 .. Columns) {
                transposedData[column * Rows + row] = cast(CastType) data[row * Columns + column];
            }
        }

        return transposedData;
    }
}

alias Matrix4D = Matrix!(double, 4, 4);
alias Matrix3D = Matrix!(double, 3, 3);
alias Matrix2D = Matrix!(double, 2, 2);

/**
 * Creates a translation matrix from a 2D vector.
 */
public Matrix3D toTranslationMatrix(const Vector2D vector) {
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
public Matrix4D toTranslationMatrix(const Vector3D vector) {
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
 * Creates a scaling matrix from a 2D scaling vector.
 */
public Matrix3D toScalingMatrix(const Vector2D scalingVector) {
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
public Matrix4D toScalingMatrix(const Vector3D scalingVector) {
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
public Matrix4D createRotationMatrix(const scalar radianAngle, const double x,
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
public Matrix4D createRotationMatrix(const scalar radianAngle, const Vector3D axis) {
    return createRotationMatrix(radianAngle, axis.x, axis.y, axis.z);
}

/**
 * Creates a rotation matrix.
 *
 * Params:
 *  radianAngle = Amount of rotation in radian.
 */
public Matrix3D createRotationMatrix(const scalar radianAngle) {
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
public Matrix4D createXRotationMatrix(const scalar radianAngle) {
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
public Matrix4D createYRotationMatrix(const scalar radianAngle) {
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
public Matrix4D createZRotationMatrix(const scalar radianAngle) {
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
public Matrix4D createLookatMatrix(const Vector3D eyePosition,
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
public Matrix4D createViewMatrix(Vector3D eyePosition, scalar pitchInRadian, scalar yawInRadian) {
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

/**
 * Creates a perspective projection matrix.
 */
public Matrix4D createPerspectiveMatrix(scalar fovyDegrees, scalar aspectRatio,
        scalar near, scalar far) {
    const scalar q = 1.0 / tan(degreesToRadians(0.5 * fovyDegrees));
    const scalar A = q / aspectRatio;
    const scalar B = (near + far) / (near - far);
    const scalar C = (2.0 * near * far) / (near - far);

    // dfmt off
    return Matrix4D(
        A, 0,  0, 0,
        0, q,  0, 0,
        0, 0,  B, C,
        0, 0, -1, 0
    );
    // dfmt on
}

/**
 * Converts an angle in degrees to radians.
 */
public double degreesToRadians(double degrees) {
    return degrees * (PI / 180);
}

/**
 * Converts an angle in radians to degrees.
 */
public double radiansToDegrees(double radians) {
    return radians * (180 / PI);
}

/**
 * A complex mathematical number typically used for rotation.
 * Quaternions prevent gimbal lock.
 */
struct Quaternion(T) {
    private T realPart = 1;
    private VectorType imaginaryVector = VectorType(0);

    public alias _T = T;
    public alias VectorType = Vector!(T, 3);

    /**
     * The real number component.
     */
    public @property T r() const {
        return realPart;
    }

    /**
     * The x component of the vector of imaginary numbers (a.k.a. bi).
     */
    public @property T x() const {
        return imaginaryVector.x;
    }

    /**
     * The y component of the vector of imaginary numbers (a.k.a. cj).
     */
    public @property T y() const {
        return imaginaryVector.y;
    }

    /**
     * The z component of the vector of imaginary numbers (a.k.a. dk).
     */
    public @property T z() const {
        return imaginaryVector.z;
    }

    /**
     * Construct a quaternion from a real number and the products of real and imaginary numbers.
     * Params:
     *  r = The real number component (a).
     *  x = The product of b * i.
     *  y = The product of c * j.
     *  z = The product of d * k.
     */
    this(T r, T x, T y, T z) {
        realPart = r;
        imaginaryVector = VectorType(x, y, z);
    }

    /**
     * Construct a quaternion from a real number and an imaginary vector.
     * Params:
     *  r = The real number component (a).
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
    public static Quaternion createRotation(double radianAngle, const Vector3D axis) {
        return Quaternion(cos(radianAngle / 2), axis.x * sin(radianAngle / 2),
                axis.y * sin(radianAngle / 2), axis.z * sin(radianAngle / 2));
    }

    /**
     * Multiple two quaternions.
     */
    Quaternion opBinary(string op)(const Quaternion rhs) const if (op == "*") {
        return Quaternion(r * rhs.r - x * rhs.x - y * rhs.y - z * rhs.z,
                r * rhs.x + x * rhs.r + y * rhs.z - z * rhs.y,
                r * rhs.y - x * rhs.z + y * rhs.r + z * rhs.x,
                r * rhs.z + x * rhs.y - y * rhs.x + z * rhs.r);
    }

    /**
     * Convert quaterion to a four-dimensional rotation matrix.
     */
    public Matrix4D toRotationMatrix() const {
        //TODO: Check if correct for row-major matrix
        return Matrix4D(r * r + x * x - y * y - z * z, 2 * x * y - 2 * r * z,
                2 * x * z + 2 * r * y, 0, 2 * x * y + 2 * r * z,
                r * r - x * x + y * y - z * z, 2 * y * z + 2 * r * x, 0,
                2 * x * z - 2 * r * y, 2 * y * z - 2 * r * x, r * r - x * x - y * y + z * z,
                0, 0, 0, 0, 1);
    }

    /**
     * Convert quaterion to a vector of euler angles.
     */
    public Vector3D toEulerAngles() const {
        auto q = this;

        auto sqw = q.r * q.r;
        auto sqx = q.x * q.x;
        auto sqy = q.y * q.y;
        auto sqz = q.z * q.z;

        auto unit = sqx + sqy + sqz + sqw;
        auto poleTest = q.x * q.y + q.z * q.r;

        if (poleTest > 0.499 * unit) {
            auto yaw = 2 * atan2(q.x, q.r);
            auto pitch = PI / 2;
            return Vector3D(pitch, yaw, 0);
        }

        if (poleTest < -0.499 * unit) {
            auto yaw = -2 * atan2(q.x, q.r);
            auto pitch = -PI / 2;
            return Vector3D(pitch, yaw, 0);
        }

        auto yaw = atan2(2 * q.y * q.r - 2 * q.x * q.z, sqx - sqy - sqz + sqw);
        auto pitch = asin(2 * poleTest / unit);
        auto roll = atan2(2 * q.x * q.r - 2 * q.y * q.z, -sqx + sqy - sqz + sqw);

        return Vector3D(pitch, yaw, roll);
    }
}

alias QuaternionD = Quaternion!double;

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
        auto const multipliedVector = vector * 2;

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

// Matrix tests
version (unittest) {
    @("Create and use matrix")
    unittest {
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
    }

    @("Create matix by row/column values")
    unittest {
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
    }

    @("Create 4x1 matrix")
    unittest {
        auto const matrix = Matrix!(double, 4, 1)(1, 2, 3, 4);
        assert(1 == matrix[0, 0]);
        assert(2 == matrix[1, 0]);
        assert(3 == matrix[2, 0]);
        assert(4 == matrix[3, 0]);
    }

    @("Identity matrix")
    unittest {
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
    }

    @("Multiply matrix by vector")
    unittest {
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
    }

    @("Multiply identity matrix by vector")
    unittest {
        auto const matrix = Matrix4D.identity;
        auto const vector = Vector4D(1, 4, 6, 7);
        auto const actualVector = matrix * vector;

        assert(vector == actualVector);
    }

    @("Multiply matrices")
    unittest {
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
    }

    @("Multiply matrices of different dimensions")
    unittest {
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

        auto const actualMatrix = matrix1 * matrix2;
        assert(expectedMatrix == actualMatrix);
    }

    @("Multiply matrix by scalar")
    unittest {
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
    }

    @("Transpose matrix")
    unittest {
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
    }

    @("Get row vector matrix")
    unittest {
        // dfmt off
        auto const matrix = Matrix2D(
            3, 5,
            8, 7
        );
        // dfmt on

        auto const expectedVector = Vector2D(3, 5);
        auto const actualVector = matrix.getRowVector(0);

        assert(expectedVector == actualVector);
    }

    @("Matrix addition")
    unittest {
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
    }

    @("Matrix subtraction")
    unittest {
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
    }

    @("Matrix negation")
    unittest {
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
    }

    @("Assign value via index")
    unittest {
        auto actualMatrix = Matrix2D(0);
        // dfmt off
        auto const expectedMatrix = Matrix2D(
            0, 0,
            6, 0
        );
        // dfmt on

        actualMatrix[2] = 6;
        assert(expectedMatrix == actualMatrix);
    }

    @("Get data array")
    unittest {
        // dfmt off
        auto const matrix = Matrix2D(
            1, 2, 
            3, 4
        );
        // dfmt on

        const double[4] expectedArray = [1, 2, 3, 4];
        const double[4] actualArray = matrix.getDataArray();

        assert(expectedArray == actualArray);
    }

    @("Get casted data array")
    unittest {
        // dfmt off
        auto const matrix = Matrix2D(
            1, 2, 
            3, 4
        );
        // dfmt on

        const float[4] expectedArray = [1, 2, 3, 4];
        const float[4] actualArray = matrix.getDataArray!float;

        assert(expectedArray == actualArray);
    }

    @("Get transposed data array")
    unittest {
        // dfmt off
        auto const matrix = Matrix2D(
            1, 2, 
            3, 4
        );
        // dfmt on

        const double[4] expectedArray = [1, 3, 2, 4];
        const double[4] actualArray = matrix.getTransposedDataArray();

        assert(expectedArray == actualArray);
    }

    @("Get casted, transposed data array")
    unittest {
        // dfmt off
        auto const matrix = Matrix2D(
            1, 2, 
            3, 4
        );
        // dfmt on

        const float[4] expectedArray = [1, 3, 2, 4];
        const float[4] actualArray = matrix.getTransposedDataArray!float;

        assert(expectedArray == actualArray);
    }
}

// Matrix utils tests
version (unittest) {

    @("Create translation matrix from 2D vector")
    unittest {
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
    }

    @("Create translation matrix from 3D vector")
    unittest {
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
    }

    @("Create scaling matrix from 2D vector")
    unittest {
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
    }

    @("Create scaling matrix from 3D vector")
    unittest {
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
    }

    @("Create 4D rotation matrix")
    unittest {
        auto const expectedMatrix = "Matrix!(double, 4u, 4u)([-1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1])";

        auto actualMatrix1 = createRotationMatrix(PI, 0, 1, 0);
        assert(expectedMatrix == to!string(actualMatrix1));

        auto actualMatrix2 = createRotationMatrix(PI, Vector3D(0, 1, 0));
        assert(expectedMatrix == to!string(actualMatrix2));

        assert(actualMatrix1 == actualMatrix2);
    }

    @("Create 3D rotation matrix")
    unittest {
        auto const expectedMatrix = "Matrix!(double, 3u, 3u)([-0.989992, -0.14112, 0, 0.14112, -0.989992, 0, 0, 0, 1])";
        auto actualMatrix = createRotationMatrix(3);
        assert(expectedMatrix == to!string(actualMatrix));
    }

    @("Create axis-bound rotation matrices")
    unittest {
        auto expectedMatrix = "Matrix!(double, 4u, 4u)([1, 0, 0, 0, 0, -1, 1.22461e-16, 0, 0, -1.22461e-16, -1, 0, 0, 0, 0, 1])";
        auto actualMatrix = createXRotationMatrix(PI);
        assert(expectedMatrix == to!string(actualMatrix));

        expectedMatrix = "Matrix!(double, 4u, 4u)([-1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1])";
        actualMatrix = createYRotationMatrix(PI);
        assert(expectedMatrix == to!string(actualMatrix));

        expectedMatrix = "Matrix!(double, 4u, 4u)([-1, -1.22461e-16, 0, 0, 1.22461e-16, -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])";
        actualMatrix = createZRotationMatrix(PI);
        assert(expectedMatrix == to!string(actualMatrix));
    }

    @("Create look-at matrix")
    unittest {
        auto const expectedMatrix = "Matrix!(double, 4u, 4u)([0, 0, 1, -0, 0, 1, 0, -1, -1, -0, -0, -0, 0, 0, 0, 1])";
        auto actualMatrix = createLookatMatrix(Vector3D(0, 1, 0), Vector3D(1,
                1, 0), UnitVector3D(0, 1, 0));
        assert(expectedMatrix == to!string(actualMatrix));
    }

    @("Create view matrix")
    unittest {
        auto const expectedMatrix = "Matrix!(double, 4u, 4u)([0.540302, 0, -0.841471, -0.540302, 0.708073, 0.540302, 0.454649, -1.24838, 0.454649, -0.841471, 0.291927, 0.386822, 0, 0, 0, 1])";
        auto actualMatrix = createViewMatrix(Vector3D(1, 1, 0), 1, 1);
        assert(expectedMatrix == to!string(actualMatrix));
    }

    @("Create perspective matrix")
    unittest {
        auto const expectedMatrix = "Matrix!(double, 4u, 4u)([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1.0002, -0.20002, 0, 0, -1, 0])";
        auto actualMatrix = createPerspectiveMatrix(90, 1920 / 1080, 0.1, 1000);
        assert(expectedMatrix == to!string(actualMatrix));
    }

    @("Convert degrees to radians")
    unittest {
        assert(PI.to!string == degreesToRadians(180).to!string);
        assert(0.to!string == degreesToRadians(0).to!string);
        assert((2 * PI).to!string == degreesToRadians(360).to!string);
    }

    @("Convert radians to degrees")
    unittest {
        assert(180 == radiansToDegrees(PI));
        assert(0 == radiansToDegrees(0));
        assert(360 == radiansToDegrees(2 * PI));
    }
}

// Quaternion tests
version (unittest) {

    @("Create quaternion")
    unittest {
        auto const quaternion = QuaternionD();
        assert(QuaternionD(1, 0, 0, 0) == quaternion);

        auto const quaternion2 = QuaternionD(4, 1, 2, 3);
        assert(4 == quaternion2.r);
        assert(1 == quaternion2.x);
        assert(2 == quaternion2.y);
        assert(3 == quaternion2.z);

        auto const quaternion3 = QuaternionD(4, Vector3D(1, 2, 3));
        assert(4 == quaternion3.r);
        assert(1 == quaternion3.x);
        assert(2 == quaternion3.y);
        assert(3 == quaternion3.z);
    }

    @("Create quaternions")
    unittest {
        auto const quaternion1 = QuaternionD(1, 2, 3, 4);
        auto const quaternion2 = QuaternionD(5, 6, 7, 8);
        auto const expectedQuaternion = QuaternionD(-60, 12, 30, 24);
        auto const actualQuaternion = quaternion1 * quaternion2;

        assert(expectedQuaternion == actualQuaternion);
        assert(quaternion1 * quaternion2 != quaternion2 * quaternion1);
    }

    @("Create from angle and axis vector")
    unittest {
        auto const expectedQuaternion = "const(Quaternion!double)(6.12303e-17, (1, 0, 0))";
        auto const actualQuaternion = QuaternionD.createRotation(PI, Vector3D(1, 0, 0));
        assert(expectedQuaternion == actualQuaternion.to!string);
    }

    @("Convert to rotation matrix")
    unittest {
        auto const quaternion = QuaternionD(6.12303e-17, 1, 0, 0);
        auto const expectedRotationMatrix = "const(Matrix!(double, 4u, 4u))([1, 0, 0, 0, 0, -1, 1.22461e-16, 0, 0, -1.22461e-16, -1, 0, 0, 0, 0, 1])";
        auto const actualRotationMatrix = quaternion.toRotationMatrix();
        assert(expectedRotationMatrix == actualRotationMatrix.to!string);
    }

    @("Convert to euler angles vector")
    unittest {
        auto const quaternion = QuaternionD.createRotation(PI, Vector3D(0, 1, 0));
        auto const expectedToEulerAngles = Vector3D(0, PI, 0);
        auto const actualEulerAngles = quaternion.toEulerAngles();
        assert(expectedToEulerAngles == actualEulerAngles);

        auto const quaternion2 = QuaternionD.createRotation(PI, Vector3D(1, 0, 0));
        auto const expectedToEulerAngles2 = Vector3D(0, 0, PI);
        auto const actualEulerAngles2 = quaternion2.toEulerAngles();
        assert(expectedToEulerAngles2 == actualEulerAngles2);
    }
}
