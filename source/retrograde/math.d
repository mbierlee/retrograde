/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2017 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

module retrograde.math;

import retrograde.entity;
import retrograde.option;
import retrograde.stringid;

import std.conv;
import std.math;
import std.range;

enum real TwoPI = (2 * PI);

const UnitVector3D standardUpVector = UnitVector3D(0, 1, 0);
const UnitVector3D standardSideVector = UnitVector3D(1, 0, 0);

class Position2IComponent : EntityComponent {
	mixin EntityComponentIdentity!"Position2IComponent";

	private Vector2I _position;

	public @property position() {
		return _position;
	}

	public @property position(Vector2I newPosition) {
		_position = newPosition;
	}

	this() {
		this(Vector2I(0, 0));
	}

	this(int x, int y) {
		this(Vector2I(x, y));
	}

	this(Vector2I position) {
		this.position = position;
	}
}

class Position2DComponent : EntityComponent, Snapshotable {
	mixin EntityComponentIdentity!"Position2DComponent";

	private Vector2D _position;

	public @property position() {
		return _position;
	}

	public @property position(Vector2D newPosition) {
		_position = newPosition;
	}

	this() {
		this(Vector2D(0, 0));
	}

	this(int x, int y) {
		this(Vector2D(x, y));
	}

	this(Vector2D position) {
		this.position = position;
	}

	public string[string] getSnapshotData() {
		return [
			"position": _position.toString()
		];
	}
}

class Position3DComponent : EntityComponent {
	mixin EntityComponentIdentity!"Position3DComponent";

	public Vector3D position;

	this() {
		this(Vector3D(0));
	}

	this(Vector3D position) {
		this.position = position;
	}
}

class OrientationR2Component : EntityComponent, Snapshotable {
	mixin EntityComponentIdentity!"OrientationR2Component";

	private double _angle;

	public @property double angle() {
		return _angle;
	}

	public @property void angle(double angle) {
		this._angle = wrapAngle(angle);
	}

	this() {
		this(0);
	}

	this(double angleInRadian) {
		angle = angleInRadian;
	}

	public string[string] getSnapshotData() {
		return [
			"angle": to!string(angle)
		];
	}
}

class OrientationR3Component : EntityComponent {
	mixin EntityComponentIdentity!"OrientationR3Component";

	public QuaternionD orientation;

	this() {
		this(QuaternionD.nullRotation);
	}

	this (QuaternionD orientation) {
		this.orientation = orientation;
	}
}

class Scale3DComponent : EntityComponent {
	mixin EntityComponentIdentity!"Scale3DComponent";

	public Vector3D scale;

	this() {
		this(Vector3D(1));
	}

	this (Vector3D scale) {
		this.scale = scale;
	}
}

class RelativePosition2DComponent : EntityComponent, Snapshotable {
	mixin EntityComponentIdentity!"RelativePosition2DComponent";

	public Vector2D relativePosition;

	this() {
		this(Vector2D(0, 0));
	}

	this(int x, int y) {
		this(Vector2D(x, y));
	}

	this(Vector2D relativePosition) {
		this.relativePosition = relativePosition;
	}

	public override string[string] getSnapshotData() {
		return [
			"relative-position": relativePosition.toString()
		];
	}
}

class RelativePositionProcessor : EntityProcessor {
	private HierarchialEntityCollection hierarchialEntities = new HierarchialEntityCollection();

	public override bool acceptsEntity(Entity entity) {
		return entity.hasComponent!RelativePosition2DComponent
			&& entity.hasComponent!Position2DComponent;
	}

	protected override void processAcceptedEntity(Entity entity) {
		hierarchialEntities.addEntity(entity);
	}

	protected override void processRemovedEntity(Entity entity) {
		hierarchialEntities.removeEntity(entity.id);
	}

	public override void update() {
		hierarchialEntities.updateHierarchy();
		hierarchialEntities.forEachChild((entity) {
			auto parentPosition = Vector2D(0);
			double parentOrientation = 0;
			if (entity.parent !is null) {
				parentPosition = entity.parent.getFromComponent!Position2DComponent(component => component.position, Vector2D(0));
				parentOrientation = entity.parent.getFromComponent!OrientationR2Component(component => component.angle, 0);
			}

			auto relativePosition = entity.getFromComponent!RelativePosition2DComponent(c => c.relativePosition);
			entity.withComponent!Position2DComponent((component) {
				auto transformVector = parentPosition.toTranslationMatrix() * createRotationMatrix(parentOrientation) * Vector3D(relativePosition, 1);
				component.position = transformVector.downgrade();
			});
		});
	}
}

class RelativeOrientationR2Component : EntityComponent, Snapshotable {
	mixin EntityComponentIdentity!"RelativeOrientationR2Component";

	private double _relativeAngle;

	public @property double relativeAngle() {
		return _relativeAngle;
	}

	public @property void relativeAngle(double relativeAngle) {
		this._relativeAngle = wrapAngle(relativeAngle);
	}

	this() {
		this(0);
	}

	this(scalar relativeAngle) {
		this.relativeAngle = relativeAngle;
	}

	public override string[string] getSnapshotData() {
		return [
			"relative-angle": to!string(relativeAngle)
		];
	}
}

class RelativeOrientationProcessor : EntityProcessor {
	private HierarchialEntityCollection hierarchialEntities = new HierarchialEntityCollection();

	public override bool acceptsEntity(Entity entity) {
		return entity.hasComponent!OrientationR2Component
			&& entity.hasComponent!RelativeOrientationR2Component;
	}

	protected override void processAcceptedEntity(Entity entity) {
		hierarchialEntities.addEntity(entity);
	}

	protected override void processRemovedEntity(Entity entity) {
		hierarchialEntities.removeEntity(entity.id);
	}

	public override void update() {
		hierarchialEntities.updateHierarchy();
		hierarchialEntities.forEachChild((entity) {
			scalar parentAngle = 0;
			if (entity.parent !is null) {
				parentAngle = entity.parent.getFromComponent!OrientationR2Component(c => c.angle, 0);
			}

			auto relativeAngle = entity.getFromComponent!RelativeOrientationR2Component(c => c.relativeAngle);
			entity.withComponent!OrientationR2Component((c) {
				c.angle = parentAngle + relativeAngle;
			});
		});
	}
}

alias scalar = double;

struct Vector(T, uint N) if (N > 0) {
	private T[N] components;

	public alias _N = N;
	public alias _T = T;

	public @property const T x() {
		return components[0];
	}

	public @property x(T x) {
		components[0] = x;
	}

	static if (N >= 2) {
		public @property const T y() {
			return components[1];
		}

		public @property y(T y) {
			components[1] = y;
		}
	}

	static if (N >= 3) {
		public @property const T z() {
			return components[2];
		}

		public @property z(T z) {
			components[2] = z;
		}
	}

	static if (N >= 4) {
		public @property const T w() {
			return components[3];
		}

		public @property w(T w) {
			components[3] = w;
		}
	}

	static if (N >= 2) {
		public Vector normalize() {
			auto currentMagnitude = magnitude;
			if (currentMagnitude == 0) {
				return Vector(0);
			}

			if (currentMagnitude == 1) {
				return this;
			}

			Vector normalizedVector;
			foreach (i ; 0 .. N) {
				normalizedVector[i] = cast(T) (this[i] / currentMagnitude);
			}
			return normalizedVector;
		}
	}

	this(T val) {
		this.components[0 .. N] = val;
	}

	this(T[] components...) {
		assert(components.length == N, "Cannot initialize a vector with a different amount of components than available.");
		this.components = components;
	}

	static if (N >= 2) {
		this(Vector!(T, N-1) smallerVector, T extraComponent) {
			this.components = smallerVector.components ~ [extraComponent];
		}
	}

	static if (N >= 2) {
		alias length = magnitude;

		public @property scalar magnitude() {
			scalar powSum = 0;
			foreach(component ; components) {
				powSum += component * component;
			}

			return sqrt(powSum);
		}
	}

	public void round() {
		foreach (i, component; components) {
			components[i] = cast(T) std.math.round(component);
		}
	}

	static if (N == 2) {
		public @property scalar angle() {
			auto angle = atan2(cast(scalar) y, cast(scalar) x);
			if (angle < 0) {
				angle = (2*PI) + angle;
			}
			return angle;
		}
	}

	Vector opUnary(string s)() if (s == "-") {
		return this * -1;
	}

	Vector opBinary(string op)(Vector rhs) if (rhs._N == N && (op == "+" || op == "-"))  {
		Vector vec;
		foreach(i ; 0..N) {
			mixin("vec[i] = cast(T) (components[i] " ~ op ~ " rhs[i]);");
		}

		return vec;
	}

	Vector opBinary(string op)(scalar rhs) if (op == "*" || op == "/") {
		Vector vec;
		foreach(i ; 0..N) {
			mixin("vec[i] = cast(T) (components[i] " ~ op ~ " rhs);");
		}

		return vec;
	}

	Vector opBinaryRight(string op)(scalar lhs) if (op == "*") {
		return this * lhs;
	}

	bool opEquals()(auto ref const Vector other) const if (other._N == N) {
		foreach(i ; 0 .. N) {
			if (this[i] != other[i]) {
				return false;
			}
		}
		return true;
	}

	T dot()(Vector other) if (other._N == N) {
		T dotProduct = 0;
		foreach (i ; 0..N) {
			dotProduct += this[i] * other[i];
		}
		return dotProduct;
	}

	Vector cross()(Vector other) if (N == 3 && other._N == N) {
		return Vector(
			(this.y * other.z) - (this.z * other.y),
			(this.z * other.x) - (this.x * other.z),
			(this.x * other.y) - (this.y * other.x)
		);
	}

	Vector reflect()(Vector normal) if (N >= 2 && normal._N == N) {
		normal = normal.normalize();
		return this - ((2 * normal).dot(this) * normal);
	}

	Vector refract()(T refractionIndex, Vector normal) if (N >= 2 && normal._N == N) {
		auto normalizedThis = this.normalize();
		normal = normal.normalize();

		auto dotProduct = normal.dot(normalizedThis);
		auto k = 1 - (refractionIndex * refractionIndex) * (1 - (dotProduct * dotProduct));
		if (k < 0) {
			return Vector(0);
		}

		return refractionIndex * normalizedThis - (refractionIndex * normal.dot(normalizedThis) + sqrt(k)) * normal;
	}

	TargetVectorType opCast(TargetVectorType)() if(TargetVectorType._N == N) {
		auto resultVector = TargetVectorType();
		foreach(i ; 0 .. N) {
			resultVector[i] = cast(TargetVectorType._T) this[i];
		}
		return resultVector;
	}

	T opIndex(size_t index) const {
		return components[index];
	}

	T opIndexAssign(T value, size_t index) {
		return components[index] = value;
	}

	string toString() {
		string[] componentStrings;

		foreach(i ; 0 .. N) {
			componentStrings ~= to!string(this[i]);
		}

		return "(" ~ componentStrings.join(", ") ~ ")";
	}

	static if (N >= 2) {
		public Vector!(T, N-1) downgrade() {
			return Vector!(T, N-1)(this.components[0..$-1]);
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

struct UnitVector(VectorType) {
	private VectorType _vector;

	this(VectorType vector) {
		this._vector = vector.normalize();
	}

	this(VectorType._T[] components...) {
		assert(components.length == VectorType._N, "Cannot initialize a unit vector with a different amount of components than its vector type has.");
		this(VectorType(components));
	}

	public const @property VectorType vector() {
		return _vector;
	}
}

alias UnitVector2D = UnitVector!Vector2D;
alias UnitVector2F = UnitVector!Vector2F;

alias UnitVector3D = UnitVector!Vector3D;
alias UnitVector3F = UnitVector!Vector3F;

alias UnitVector4D = UnitVector!Vector4D;

struct Rectangle(T) {
	public Vector!(T, 2) position;
	private Vector!(T, 2) size;

	alias _T = T;

	public this(T x, T y, T width, T height) {
		position.x = x;
		position.y = y;
		size.x = width;
		size.y = height;
	}

	public this(Vector!(T, 2) position, T width, T height) {
		this.position = position;
		size.x = width;
		size.y = height;
	}

	public @property const T x() {
		return position.x;
	}

	public @property void x(T x) {
		position.x = x;
	}

	public @property const T y() {
		return position.y;
	}

	public @property void y(T y) {
		position.y = y;
	}

	public @property const T width() {
		return size.x;
	}

	public @property void width(T width) {
		size.x = width;
	}

	public @property const T height() {
		return size.y;
	}

	public @property void height(T height) {
		size.y = height;
	}

	TargetRectangleType opCast(TargetRectangleType)() {
		auto resultRectangle = TargetRectangleType();

		resultRectangle.position = cast(Vector!(TargetRectangleType._T, 2)) position;
		resultRectangle.width = cast(TargetRectangleType._T) width;
		resultRectangle.height = cast(TargetRectangleType._T) height;

		return resultRectangle;
	}

}

alias RectangleI = Rectangle!int;
alias RectangleU = Rectangle!uint;
alias RectangleL = Rectangle!long;
alias RectangleUL = Rectangle!ulong;
alias RectangleF = Rectangle!float;
alias RectangleD = Rectangle!double;

struct Matrix(T, uint Rows, uint Columns) if (Rows > 0 && Columns > 0) {
	private T[Columns * Rows] data;

	public alias _T = T;
	public alias _Rows = Rows;
	public alias _Columns = Columns;
	public alias _VectorType = Vector!(T, Rows);

	static if (Rows == Columns) {
		private static Matrix identityMatrix;

		public static @property Matrix identity() {
			return identityMatrix;
		}

		static this() {
			foreach (row ; 0 .. Rows) {
				foreach (column ; 0 .. Columns) {
					identityMatrix[row, column] = column == row ? 1 : 0;
				}
			}
		}
	}

	this(T initialValue) {
		data[0 .. data.length] = initialValue;
	}

	this(T[] initialValues...) {
		assert(initialValues.length == data.length, "Cannot initialize a matrix with a different size of data than available.");
		data = initialValues;
	}

	T opIndex(size_t row, size_t column) const {
		return data[row * Columns + column];
	}

	T opIndex(size_t index) const {
		return data[index];
	}

	T opIndexAssign(T value, size_t row, size_t column) {
		return data[row * Columns + column] = value;
	}

	T opIndexAssign(T value, size_t index) {
		return data[index] = value;
	}

	Matrix opUnary(string s)() if (s == "-") {
		return this * -1;
	}

	_VectorType opBinary(string op)(_VectorType rhs) if (op == "*") {
		_VectorType vector = _VectorType(0);
		foreach (row ; 0 .. Rows) {
			foreach (column ; 0 .. Columns) {
				vector[row] = vector[row] + this[row, column] * rhs[column];
			}
		}

		return vector;
	}

	Matrix opBinary(string op)(scalar rhs) if (op == "*") {
		Matrix matrix;
		foreach(index ; 0 .. data.length) {
			matrix[index] = this[index] * rhs;
		}
		return matrix;
	}

	Matrix opBinaryRight(string op)(scalar lhs) if (op == "*") {
		return this * lhs;
	}

	Matrix!(T, Rows, OtherColumns) opBinary(string op, uint OtherRows, uint OtherColumns)(Matrix!(T, OtherRows, OtherColumns) rhs) if (op == "*" && Columns == OtherRows) {
		Matrix!(T, Rows, OtherColumns) resultMatrix;
		auto transposedRhs = rhs.transpose();
		Vector!(T, Columns)[OtherColumns] columnCache;
		foreach(thisRow ; 0 .. Rows) {
			auto rowVector = getRowVector(thisRow);
			foreach(otherColumn ; 0 .. OtherColumns) {
				if (thisRow == 0) {
					columnCache[otherColumn] = transposedRhs.getRowVector(otherColumn);
				}

				resultMatrix[thisRow, otherColumn] = rowVector.dot(columnCache[otherColumn]);
			}
		}

		return resultMatrix;
	}

	Matrix opBinary(string op)(Matrix rhs) if ((op == "+" || op == "-") && Columns == rhs._Columns && Rows == rhs._Rows) {
		Matrix resultMatrix;
		foreach (index; 0 .. data.length) {
			mixin("resultMatrix[index] = this[index] " ~ op ~ " rhs[index];");
		}
		return resultMatrix;
	}

	Matrix!(T, Columns, Rows) transpose() {
		Matrix!(T, Columns, Rows) resultMatrix;
		foreach(row ; 0 .. Rows) {
			foreach(column ; 0 .. Columns) {
				resultMatrix[column, row] = this[row, column];
			}
		}

		return resultMatrix;
	}

	Vector!(T, Columns) getRowVector(size_t row) {
		return Vector!(T, Columns)(data[row * Columns .. (row * Columns) + Columns]);
	}
}

alias Matrix4D = Matrix!(double, 4, 4);
alias Matrix3D = Matrix!(double, 3, 3);
alias Matrix2D = Matrix!(double, 2, 2);

public Matrix3D toTranslationMatrix(Vector2D vector) {
	return Matrix3D(
		1, 0, vector.x,
		0, 1, vector.y,
		0, 0, 1
	);
}

public Matrix4D toTranslationMatrix(Vector3D vector) {
	return Matrix4D(
		1, 0, 0, vector.x,
		0, 1, 0, vector.y,
		0, 0, 1, vector.z,
		0, 0, 0, 1
	);
}

public Matrix3D toScalingMatrix(Vector2D scalingVector) {
	return Matrix3D(
		scalingVector.x, 0              , 0,
		0              , scalingVector.y, 0,
		0              , 0              , 1
	);
}

public Matrix4D toScalingMatrix(Vector3D scalingVector) {
	return Matrix4D(
		scalingVector.x, 0                 , 0              , 0,
		0              , scalingVector.y   , 0              , 0,
		0              , 0                 , scalingVector.z, 0,
		0              , 0                 , 0              , 1
	);
}

public Matrix4D createRotationMatrix(scalar radianAngle, double x, double y, double z) {
	double x2 = x * x;
	double y2 = y * y;
	double z2 = z * z;
	auto cosAngle = cos(radianAngle);
	auto sinAngle = sin(radianAngle);
	auto omc = 1.0f - cosAngle;

	return Matrix4D(
		x2 * omc + cosAngle       , y * x * omc + z * sinAngle, x * z * omc - y * sinAngle, 0,
		x * y * omc - z * sinAngle, y2 * omc + cosAngle       , y * z * omc + x * sinAngle, 0,
		x * z * omc + y * sinAngle, y * z * omc - x * sinAngle, z2 * omc + cosAngle       , 0,
		0                         , 0                         , 0                         , 1
	);
}

public Matrix3D createRotationMatrix(scalar radianAngle) {
	return Matrix3D(
		cos(radianAngle) , -sin(radianAngle), 0,
		sin(radianAngle), cos(radianAngle), 0,
		0                , 0               , 1
	);
}

public Matrix4D createRotationMatrix(scalar radianAngle, Vector3D axis) {
	return createRotationMatrix(radianAngle, axis.x, axis.y, axis.z);
}

public Matrix4D createXRotationMatrix(double radianAngle) {
	return Matrix4D(
		1, 0                , 0               , 0,
		0, cos(radianAngle) , sin(radianAngle), 0,
		0, -sin(radianAngle), cos(radianAngle), 0,
		0, 0                , 0               , 1
	);
}

public Matrix4D createYRotationMatrix(double radianAngle) {
	return Matrix4D(
		cos(radianAngle), 0, -sin(radianAngle), 0,
		0               , 1, 0                , 0,
		sin(radianAngle), 0, cos(radianAngle) , 0,
		0               , 0, 0                , 1
	);
}

public Matrix4D createZRotationMatrix(double radianAngle) {
	return Matrix4D(
		cos(radianAngle), -sin(radianAngle), 0, 0,
		sin(radianAngle), cos(radianAngle) , 0, 0,
		0               , 0                , 1, 0,
		0               , 0                , 0, 1
	);
}

public Matrix4D createLookatMatrix(Vector3D eyePosition, Vector3D targetPosition, UnitVector3D upVector) {
	auto forwardVector = (targetPosition - eyePosition).normalize();
	auto sideVector = forwardVector.cross(upVector.vector);
	auto cameraBasedUpVector = sideVector.cross(forwardVector);
	return Matrix4D(
		sideVector.x         , sideVector.y         , sideVector.z         , -eyePosition.x,
		cameraBasedUpVector.x, cameraBasedUpVector.y, cameraBasedUpVector.z, -eyePosition.y,
		-forwardVector.x     , -forwardVector.y     , -forwardVector.z     , -eyePosition.z,
		0                    , 0                    , 0                    , 1
	);
}

public Matrix4D createFirstPersonViewMatrix(Vector3D eyePosition, double pitchInRadian, double yawInRadian) {
	double cosPitch = cos(pitchInRadian);
	double sinPitch = sin(pitchInRadian);
	double cosYaw = cos(yawInRadian);
	double sinYaw = sin(yawInRadian);

	auto sideVector = Vector3D(cosYaw, 0, -sinYaw);
	auto upVector = Vector3D(sinYaw * sinPitch, cosPitch, cosYaw * sinPitch);
	auto forwardVector = Vector3D(sinYaw * cosPitch, -sinPitch, cosPitch * cosYaw);

	return Matrix4D(
		sideVector.x   , sideVector.y   , sideVector.z   , -sideVector.dot(eyePosition),
		upVector.x     , upVector.y     , upVector.z     , -upVector.dot(eyePosition),
		forwardVector.x, forwardVector.y, forwardVector.z, -forwardVector.dot(eyePosition),
		0              , 0              , 0              , 1
	);
}

public Matrix4D createPerspectiveMatrix(double fovyDegrees, double aspectRatio, double near, double far) {
	double q = 1.0 / tan(degreesToRadians(0.5 * fovyDegrees));
	double A = q / aspectRatio;
	double B = (near + far) / (near - far);
	double C = (2.0 * near * far) / (near - far);

	return Matrix4D(
		A, 0, 0 , 0,
		0, q, 0 , 0,
		0, 0, B , C,
		0, 0, -1, 0
	);
}

struct Quaternion(T) {
	private T realPart = 1;
	VectorType imaginaryVector = VectorType(0);

	public alias _T = T;
	public alias VectorType = Vector!(T, 3);

	public @property T w() {
		return realPart;
	}

	public @property T x() {
		return imaginaryVector.x;
	}

	public @property T y() {
		return imaginaryVector.y;
	}

	public @property T z() {
		return imaginaryVector.z;
	}

	public static const Quaternion nullRotation;

	static this() {
		nullRotation = Quaternion.createRotation(0, standardUpVector.vector);
	}

	this(T w, T x, T y, T z) {
		realPart = w;
		imaginaryVector = VectorType(x, y, z);
	}

	public static Quaternion createRotation(double radianAngle, Vector3D axis) {
		return Quaternion(
			cos(radianAngle/2),
			axis.x * sin(radianAngle/2),
			axis.y * sin(radianAngle/2),
			axis.z * sin(radianAngle/2)
		);
	}

	Quaternion opBinary(string op)(Quaternion rhs) if (op == "*") {
		return Quaternion(
			w * rhs.w - x * rhs.x - y * rhs.y - z * rhs.z,
			w * rhs.x + x * rhs.w + y * rhs.z - z * rhs.y,
			w * rhs.y - x * rhs.z + y * rhs.w + z * rhs.x,
			w * rhs.z + x * rhs.y - y * rhs.x + z * rhs.w
		);
	}

	public Matrix4D toRotationMatrix() {
		//TODO: Check if correct for row-major matrix
		return Matrix4D(
			w * w + x * x - y * y - z * z, 2 * x * y - 2 * w * z        , 2 * x * z + 2 * w * y        , 0,
			2 * x * y + 2 * w * z        , w * w - x * x + y * y - z * z, 2 * y * z + 2 * w * x        , 0,
			2 * x * z - 2 * w * y        , 2 * y * z - 2 * w * x        , w * w - x * x - y * y + z * z, 0,
			0                            , 0                            , 0                            , 1
		);
	}

	public Vector3D toEulerAngles() {
		auto q = this;

		auto sqw = q.w * q.w;
		auto sqx = q.x * q.x;
		auto sqy = q.y * q.y;
		auto sqz = q.z * q.z;

		auto unit = sqx + sqy + sqz + sqw;
		auto poleTest = q.x * q.y + q.z * q.w;

		if (poleTest > 0.499 * unit) {
			auto yaw = 2 * atan2(q.x, q.w);
			auto pitch = PI/2;
			return Vector3D(pitch, yaw, 0);
		}

		if (poleTest < -0.499 * unit) {
			auto yaw = -2 * atan2(q.x, q.w);
			auto pitch = - PI/2;
			auto bank = 0;
			return Vector3D(pitch, yaw, 0);
		}

		auto yaw = atan2(2 * q.y * q.w - 2 * q.x * q.z, sqx - sqy - sqz + sqw);
		auto pitch = asin(2 * poleTest / unit);
		auto roll = atan2(2 * q.x * q.w - 2 * q.y * q.z, -sqx + sqy - sqz + sqw);

		return Vector3D(pitch, yaw, roll);
	}
}

alias QuaternionD = Quaternion!double;

public double radiansToDegrees(double radians) {
	return radians * (180 / PI);
}

public double degreesToRadians(double degrees) {
	return degrees * (PI / 180);
}

public Vector2D radiansToUnitVector(double radians) {
	return Vector2D(cos(radians), sin(radians));
}

public double clamp(double value, double min, double max) {
	return clamp(value, Some!double(min), Some!double(max));
}

public double clamp(double value, Option!double min = None!double(), Option!double max = None!double()) {
	if (!min.isEmpty() && value <= min.get()) {
		return min.get();
	}

	if (!max.isEmpty() && value >= max.get()) {
		return max.get();
	}

	return value;
}

public double wrapAngle(double angle) {
	if (angle > TwoPI || angle < 0) {
		auto result  = angle % TwoPI;
		if (result < 0) result = TwoPI - -result;
		return result;
	}

	return angle;
}

public double deltaAngle(double sourceAngle, double targetAngle) {
	auto delta = targetAngle - sourceAngle;
	return mod(delta + PI, TwoPI) - PI;
}

public double mod(double a, double n) {
	return (a % n + n) % n;
}

public bool equals(double a, double b, double tolerance = 1.11e-16) {
	double lowerBound = b - tolerance;
	double upperBound = b + tolerance;
	return a >= lowerBound && a <= upperBound;
}
