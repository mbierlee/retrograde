/**
 * Retrograde Engine
 *
 * Authors:
 *  Mike Bierlee, m.bierlee@lostmoment.com
 * Copyright: 2014-2020 Mike Bierlee
 * License:
 *  This software is licensed under the terms of the MIT license.
 *  The full terms of the license can be found in the LICENSE.txt file.
 */

import retrograde.math;
import retrograde.entity;
import retrograde.option;

import dunit;

import std.conv;
import std.format;
import std.math;

class MathTest {
    mixin UnitTest;

    private const auto relaxedTolerance = 2 * 1.11e-16;

    @Test
    public void testRadiansToDegrees() {
        assertEquals(180, radiansToDegrees(PI));
        assertEquals(0, radiansToDegrees(0));
        assertEquals(360, radiansToDegrees(2 * PI));
    }

    @Test
    public void testDegreesToRadians() {
        assertEquals(PI.to!string, degreesToRadians(180).to!string);
        assertEquals(0.to!string, degreesToRadians(0).to!string);
        assertEquals((2 * PI).to!string, degreesToRadians(360).to!string);
    }

    @Test
    public void testClamp() {
        assertEquals(5, clamp(5, -100, 100));
        assertEquals(-100, clamp(-101, -100, 100));
        assertEquals(100, clamp(102, -100, 100));

        assertEquals(102, clamp(102, Some!double(-100)));
        assertEquals(-101, clamp(-101, None!double(), Some!double(100)));

        assertEquals(56444, 56444.clamp());
    }

    @Test
    public void testWrapAngle() {
        assertTrue(equals(PI_2, wrapAngle(2 * PI + PI_2), relaxedTolerance));
        assertTrue(equals(PI, wrapAngle(-PI), relaxedTolerance));
        assertTrue(equals(PI, wrapAngle(PI), relaxedTolerance));
        assertTrue(equals(PI, wrapAngle(-(2 * PI) - PI), relaxedTolerance));
    }

    @Test
    public void testRadiansToUnitVector() {
        auto actualVector = radiansToUnitVector(-PI_2);
        assertTrue(equals(actualVector.x, 0));
        assertEquals(-1, actualVector.y);

        actualVector = radiansToUnitVector(PI);
        assertEquals(-1, actualVector.x);
        assertTrue(equals(actualVector.y, 0, relaxedTolerance));
    }

    @Test
    public void testDeltaAngle() {
        assertEquals(0.1, deltaAngle(0.1, 0.2));

        assertEquals(0.1, deltaAngle(0.1, 0.2 + TwoPI));
        assertEquals(0.1, deltaAngle(0.1, 0.2 + TwoPI));
        assertEquals(0.1, deltaAngle(0.1, 0.2 - TwoPI));
        assertEquals(0.1, deltaAngle(0.1 + TwoPI, 0.2));
        assertEquals(0.1, deltaAngle(0.1 - TwoPI, 0.2));

        assertEquals(-0.1, deltaAngle(0.2, 0.1));

        assertEquals(-0.1, deltaAngle(0.2, 0.1 - TwoPI));
        assertEquals(-0.1, deltaAngle(0.2, 0.1 + TwoPI));
        assertEquals(-0.1, deltaAngle(0.2 + TwoPI, 0.1));
        assertEquals(-0.1, deltaAngle(0.2 - TwoPI, 0.1));

        assertEquals(0.2, deltaAngle(TwoPI - 0.1, 0.1));
        assertEquals(-0.2, deltaAngle(0.1, TwoPI - 0.1));
    }

    @Test
    public void testMod() {
        assertTrue(equals(mod(-1, 16), 15));
        assertTrue(equals(-1 % 16, -1));
    }
}

class VectorTest {
    mixin UnitTest;

    @Test
    public void testCreateVector2() {
        auto vector = Vector2U(1, 2);

        assertEquals(1, vector.x);
        assertEquals(2, vector.y);
    }

    @Test
    public void testNegateVector2() {
        auto vector = Vector2U(1, 2);
        auto negatedVector = -vector;

        assertEquals(-1, negatedVector.x);
        assertEquals(-2, negatedVector.y);
    }

    @Test
    public void testAddVector2() {
        auto vector1 = Vector2U(1, 2);
        auto vector2 = Vector2U(4, 8);

        auto addedVector = vector1 + vector2;

        assertEquals(5, addedVector.x);
        assertEquals(10, addedVector.y);
    }

    @Test
    public void testSubstractVector2() {
        auto vector1 = Vector2U(2, 8);
        auto vector2 = Vector2U(1, 4);

        auto subbedVector = vector1 - vector2;

        assertEquals(1, subbedVector.x);
        assertEquals(4, subbedVector.y);
    }

    @Test
    public void testMultiplyVector2ByScalar() {
        auto vector = Vector2U(2, 8);

        auto multipliedVector = vector * 2;

        assertEquals(4, multipliedVector.x);
        assertEquals(16, multipliedVector.y);
    }

    @Test
    public void testMultiplyVector2ByLhsScalar() {
        auto vector = Vector2U(2, 8);

        auto multipliedVector = 2 * vector;

        assertEquals(4, multipliedVector.x);
        assertEquals(16, multipliedVector.y);
    }

    @Test
    public void testMagnitudeOfVector2() {
        auto vector = Vector2U(5, 6);

        assertEquals("7.81025", to!string(vector.magnitude));
    }

    @Test
    public void testComparisonVector2() {
        auto vector1 = Vector2U(5, 6);
        auto vector2 = Vector2U(5, 6);

        assertEquals(vector1, vector2);
    }

    @Test
    public void testCastVector2() {
        auto vector = cast(Vector2U) Vector2D(1.5, 6);
    }

    @Test
    public void testCreateVector3() {
        auto vector = Vector3U(1, 2, 3);

        assertEquals(1, vector.x);
        assertEquals(2, vector.y);
        assertEquals(3, vector.z);
    }

    @Test
    public void testNegateVector3() {
        auto vector = Vector3U(1, 2, 3);
        auto negatedVector = -vector;

        assertEquals(-1, negatedVector.x);
        assertEquals(-2, negatedVector.y);
        assertEquals(-3, negatedVector.z);
    }

    @Test
    public void testAddVector3() {
        auto vector1 = Vector3U(1, 2, 3);
        auto vector2 = Vector3U(4, 8, 2);

        auto addedVector = vector1 + vector2;

        assertEquals(5, addedVector.x);
        assertEquals(10, addedVector.y);
        assertEquals(5, addedVector.z);
    }

    @Test
    public void testSubstractVector3() {
        auto vector1 = Vector3U(2, 8, 7);
        auto vector2 = Vector3U(1, 4, 5);

        auto subbedVector = vector1 - vector2;

        assertEquals(1, subbedVector.x);
        assertEquals(4, subbedVector.y);
        assertEquals(2, subbedVector.z);
    }

    @Test
    public void testMultiplyVector3ByScalar() {
        auto vector = Vector3U(2, 8, 4);

        auto multipliedVector = vector * 2;

        assertEquals(4, multipliedVector.x);
        assertEquals(16, multipliedVector.y);
        assertEquals(8, multipliedVector.z);
    }

    @Test
    public void testMultiplyVector3ByLhsScalar() {
        auto vector = Vector3U(2, 8, 4);

        auto multipliedVector = 2 * vector;

        assertEquals(4, multipliedVector.x);
        assertEquals(16, multipliedVector.y);
        assertEquals(8, multipliedVector.z);
    }

    @Test
    public void testMagnitudeOfVector3() {
        auto vector = Vector3U(5, 6, 8);
        auto expectedMagnitude = "11.1803";

        assertEquals(expectedMagnitude, to!string(vector.magnitude));
        assertEquals(expectedMagnitude, to!string(vector.length));
    }

    @Test
    public void testComparisonVector3() {
        auto vector1 = Vector3U(5, 6, 7);
        auto vector2 = Vector3U(5, 6, 7);

        assertEquals(vector1, vector2);
    }

    @Test
    public void testCastVector3() {
        auto vector = cast(Vector3U) Vector3D(1.5, 6, 9.88);
    }

    @Test
    public void testCreateBySettingAllComponents() {
        auto vector = Vector3U(5);

        assertEquals(5, vector.x);
        assertEquals(5, vector.y);
        assertEquals(5, vector.z);
    }

    @Test
    public void testUnitVector() {
        auto vector = Vector2D(10, 6);
        auto normalizedVector = vector.normalize();

        assertTrue(normalizedVector.magnitude > 0.9 && normalizedVector.magnitude <= 1.0);
    }

    @Test
    public void testUnitVectorWithMagnitudeBelowOne() {
        auto vector = Vector2D(0.2, 0.2);
        auto normalizedVector = vector.normalize();

        assertTrue(normalizedVector.magnitude > 0.9 && normalizedVector.magnitude <= 1.0);
    }

    @Test
    public void testUnitZeroLengthVector() {
        auto vector = Vector2D(0);
        auto normalizedVector = vector.normalize();
        assertEquals(0, normalizedVector.magnitude);
    }

    @Test
    public void testNormalizeVector() {
        auto vector = Vector2D(12, 7).normalize();

        assertTrue(vector.magnitude > 0.9 && vector.magnitude <= 1.0);
    }

    @Test
    public void testCalculateAngle() {
        auto vector = Vector2D(1, 0);
        assertEquals(0, vector.angle);
    }

    @Test
    public void testVector4D() {
        auto vector = Vector4D(1, 2, 3, 4);

        assertEquals(1, vector.x);
        assertEquals(2, vector.y);
        assertEquals(3, vector.z);
        assertEquals(4, vector.w);
    }

    @Test
    public void testDotProduct() {
        auto vector1 = Vector3D(1, 2, 3);
        auto vector2 = Vector3D(4, 5, 6);

        auto dotProduct = vector1.dot(vector2);
        assertEquals(32, dotProduct);

        vector1 = Vector3D(77, 88, 99);
        vector2 = Vector3D(5, 3, 2);

        dotProduct = vector1.dot(vector2);
        assertEquals(847, dotProduct);
    }

    @Test
    public void testCrossProductVector3() {
        auto vector1 = Vector3D(3, 4, 5);
        auto vector2 = Vector3D(7, 8, 9);
        auto expectedCrossProduct = Vector3D(-4, 8, -4);

        auto actualCrossProduct = vector1.cross(vector2);

        assertEquals(expectedCrossProduct, actualCrossProduct);
    }

    @Test
    public void testReflect() {
        auto vector = Vector3D(6, 2, 3);
        auto normal = Vector3D(0, 1, 0);
        auto expectedVector = Vector3D(6, -2, 3);

        auto actualVector = vector.reflect(normal);
        assertEquals(expectedVector, actualVector);
    }

    @Test
    public void testRefract() {
        auto vector = Vector3D(1, -1, 0);
        auto normal = Vector3D(0, 1, 0);
        auto expectedVector = Vector3D(0.707107, -0.707107, 0);

        auto actualVector = vector.refract(1, normal);
        assertEquals(to!string(expectedVector), to!string(actualVector));
    }

    @Test
    public void testCreateVectorWithExtraDimension() {
        auto originalVector = Vector2D(1, 2);
        auto expectedExpandedVector = Vector3D(1, 2, 3);
        auto actualExpandedVector = Vector3D(originalVector, 3);
        assertEquals(expectedExpandedVector, actualExpandedVector);
    }

    @Test
    public void testDowngrade() {
        auto originalVector = Vector3D(1, 2, 3);
        auto expectedVector = Vector2D(1, 2);
        auto actualVector = originalVector.downgrade();
        assertEquals(expectedVector, actualVector);
    }

    @Test
    public void testToString() {
        assertEquals("(1)", Vector!(double, 1)(1).toString());
        assertEquals("(1, 2)", Vector2D(1, 2).toString());
        assertEquals("(1, 2, 3)", Vector3D(1, 2, 3).toString());
        assertEquals("(5)", Vector!(int, 1)(5).toString());
        assertEquals("(5, 6)", Vector2I(5, 6).toString());
        assertEquals("(5, 6, 7)", Vector3I(5, 6, 7).toString());
        assertEquals("(0, 0, 0)", Vector3D(0).toString());

        assertEquals("(1.6)", Vector!(double, 1)(1.6).toString());
        assertEquals("(1.84, 2.4)", Vector2D(1.84, 2.4).toString());
        assertEquals("(1.3, 2.75, 3.782)", Vector3D(1.3, 2.75, 3.782).toString());
    }
}

class UnitVectorTest {
    mixin UnitTest;

    @Test
    public void testCreateUnitVector() {
        auto unitVector = UnitVector2D(Vector2D(0, 2));
        unitVector = UnitVector2D(0, 2);
        assertEquals(Vector2D(0, 1), unitVector.vector);
    }
}

class RectangleTest {
    mixin UnitTest;

    @Test
    public void testCreateRectangle() {
        auto rectangle1 = RectangleU(1, 2, 13, 14);
        auto rectangle2 = RectangleU(Vector2U(5, 6), 18, 19);

        assertEquals(1, rectangle1.x);
        assertEquals(2, rectangle1.y);
        assertEquals(13, rectangle1.width);
        assertEquals(14, rectangle1.height);
        assertEquals(Vector2U(1, 2), rectangle1.position);

        assertEquals(5, rectangle2.x);
        assertEquals(6, rectangle2.y);
        assertEquals(18, rectangle2.width);
        assertEquals(19, rectangle2.height);
        assertEquals(Vector2U(5, 6), rectangle2.position);
    }

    @Test
    public void testComparison() {
        auto rectangle1 = RectangleU(1, 2, 13, 14);
        auto rectangle2 = RectangleU(1, 2, 13, 14);

        assertEquals(rectangle1, rectangle2);
    }

    @Test
    public void testCast() {
        auto rectangle1 = RectangleU(1, 2, 13, 14);
        auto rectangle2 = RectangleI(1, 2, 13, 14);

        assertEquals(rectangle2, cast(RectangleI) rectangle1);
    }
}

class RelativePositionProcessorTest {
    mixin UnitTest;

    @Test
    public void testUpdatePosition() {
        auto entityOne = new Entity();
        entityOne.id = 1;
        entityOne.addComponent(new Position2DComponent(2, 2));
        entityOne.finalize();
        auto entityTwo = new Entity();
        entityTwo.parent = entityOne;
        entityTwo.id = 2;
        entityTwo.addComponent(new RelativePosition2DComponent(2, 2));
        auto childPositionComponent = new Position2DComponent(0, 0);
        entityTwo.addComponent(childPositionComponent);
        entityTwo.finalize();
        auto processor = new RelativePositionProcessor();
        processor.addEntity(entityOne);
        processor.addEntity(entityTwo);

        processor.update();

        assertEquals(Vector2D(4, 4), childPositionComponent.position);
    }

    @Test
    public void testUpdatePositionWithComplexHierarchy() {
        auto entityOne = new Entity();
        auto entityTwo = new Entity();
        auto entityThree = new Entity();
        auto entityFour = new Entity();

        entityOne.id = 1;
        entityTwo.id = 2;
        entityThree.id = 3;
        entityFour.id = 4;

        entityOne.addComponent(new Position2DComponent(2, 2));
        auto positionComponentOfTwo = new Position2DComponent(0, 0);
        entityTwo.addComponent(positionComponentOfTwo);
        entityTwo.addComponent(new RelativePosition2DComponent(2, 2));
        auto positionComponentOfThree = new Position2DComponent(0, 0);
        entityThree.addComponent(positionComponentOfThree);
        entityThree.addComponent(new RelativePosition2DComponent(-1, 3));
        auto positionComponentOfFour = new Position2DComponent(0, 0);
        entityFour.addComponent(positionComponentOfFour);
        entityFour.addComponent(new RelativePosition2DComponent(10, 25));

        entityOne.finalize();
        entityTwo.finalize();
        entityThree.finalize();
        entityFour.finalize();

        entityTwo.parent = entityOne;
        entityThree.parent = entityTwo;
        entityFour.parent = entityTwo;

        auto processor = new RelativePositionProcessor();
        processor.addEntity(entityOne);
        processor.addEntity(entityTwo);
        processor.addEntity(entityThree);
        processor.addEntity(entityFour);

        processor.update();

        assertEquals(Vector2D(4, 4), positionComponentOfTwo.position);
        assertEquals(Vector2D(3, 7), positionComponentOfThree.position);
        assertEquals(Vector2D(14, 29), positionComponentOfFour.position);
    }

    @Test
    public void testUpdatePositionOfEntityWithParentWithOnlyARelativePosition() {
        auto entityOne = new Entity();
        entityOne.id = 1;
        entityOne.addComponent(new RelativePosition2DComponent(5, 6));
        entityOne.finalize();
        auto entityTwo = new Entity();
        entityTwo.parent = entityOne;
        entityTwo.id = 2;
        auto positionComponentOfChild = new Position2DComponent(0, 0);
        entityTwo.addComponent(positionComponentOfChild);
        entityTwo.addComponent(new RelativePosition2DComponent(1, 4));
        entityTwo.finalize();
        auto processor = new RelativePositionProcessor();
        processor.addEntity(entityOne);
        processor.addEntity(entityTwo);

        processor.update();

        assertEquals(Vector2D(1, 4), positionComponentOfChild.position);
    }

    @Test
    public void testUpdatePositionOfEntityWithParentWithoutPosition() {
        auto entityOne = new Entity();
        entityOne.id = 1;
        entityOne.finalize();
        auto entityTwo = new Entity();
        entityTwo.parent = entityOne;
        entityTwo.id = 2;
        auto positionComponentOfTwo = new Position2DComponent(0, 0);
        entityTwo.addComponent(positionComponentOfTwo);
        entityTwo.addComponent(new RelativePosition2DComponent(8, 9));
        entityTwo.finalize();
        auto processor = new RelativePositionProcessor();
        processor.addEntity(entityOne);
        processor.addEntity(entityTwo);

        processor.update();

        assertEquals(Vector2D(8, 9), positionComponentOfTwo.position);
    }

    @Test
    public void testUpdatePositionOfEntityWithoutParent() {
        auto entity = new Entity();
        entity.id = 1;
        auto positionComponent = new Position2DComponent(0, 0);
        entity.addComponent(positionComponent);
        entity.addComponent(new RelativePosition2DComponent(8, 9));
        entity.finalize();

        auto processor = new RelativePositionProcessor();
        processor.addEntity(entity);

        processor.update();

        assertEquals(Vector2D(0, 0), positionComponent.position);
    }
}

class MatrixTest {
    mixin UnitTest;

    @Test
    public void testCreateAndUseMatrix() {
        auto matrix1 = Matrix!(double, 4, 3)(0);
        assertEquals(0, matrix1[0, 0]);

        matrix1[0, 2] = 2;
        assertEquals(2, matrix1[0, 2]);

        auto matrix2 = Matrix4D(0);
        assertEquals(0, matrix2[0, 0]);

        matrix2[3, 3] = 6;
        assertEquals(6, matrix2[3, 3]);

        auto matrix3 = Matrix2D(3);
        assertEquals(3, matrix3[0, 0]);
        assertEquals(3, matrix3[0, 1]);
        assertEquals(3, matrix3[1, 0]);
        assertEquals(3, matrix3[1, 1]);
    }

    @Test
    public void testMatrixByDataConstructor() {
        auto matrix = Matrix2D(
            1, 2,
            3, 4
        );
        assertEquals(1, matrix[0, 0]);
        assertEquals(2, matrix[0, 1]);
        assertEquals(3, matrix[1, 0]);
        assertEquals(4, matrix[1, 1]);
    }

    @Test
    public void testFourByOneMatrixByDataConstructor() {
        auto matrix = Matrix!(double, 4, 1)(1, 2, 3, 4);
        assertEquals(1, matrix[0, 0]);
        assertEquals(2, matrix[1, 0]);
        assertEquals(3, matrix[2, 0]);
        assertEquals(4, matrix[3, 0]);
    }

    @Test
    public void testGetIdentityMatrix() {
        auto expectedMatrix = Matrix4D(
            1, 0, 0, 0,
            0, 1, 0, 0,
            0, 0, 1, 0,
            0, 0, 0, 1
        );

        auto identityMatrix = Matrix4D.identity;
        identityMatrix = Matrix4D.identity;
        assertEquals(expectedMatrix, identityMatrix);
    }

    @Test
    public void testMultiplyMatrixByVector() {
        auto matrix = Matrix4D(
            1, 0, 1, 0,
            2, 1, 0, 0,
            0, 0, 1, 3,
            0, 4, 0, 1
        );

        auto vector = Vector4D(1, 2, 3, 4);
        auto expectedVector = Vector4D(4, 4, 15, 12);

        auto actualVector = matrix * vector;
        assertEquals(expectedVector, actualVector);
    }

    @Test
    public void testMultiplyIdentityMatrixByVector() {
        auto matrix = Matrix4D.identity;
        auto vector = Vector4D(1, 4, 6, 7);

        auto actualVector = matrix * vector;
        assertEquals(vector, actualVector);
    }

    @Test
    public void test3DVectorToTranslationMatrix() {
        auto vector = Vector3D(2, 5, 6);
        auto expectedMatrix = Matrix4D(
            1, 0, 0, 2,
            0, 1, 0, 5,
            0, 0, 1, 6,
            0, 0, 0, 1
        );

        auto actualMatrix = vector.toTranslationMatrix();
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void test2DVectorToTranslationMatrix() {
        auto vector = Vector2D(25, 56);
        auto expectedMatrix = Matrix3D(
            1, 0, 25,
            0, 1, 56,
            0, 0, 1
        );

        auto actualMatrix = vector.toTranslationMatrix();
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void test3DVectorToScalingMatrix() {
        auto vector = Vector3D(1, 2, 5);
        auto expectedMatrix = Matrix4D(
            1, 0, 0, 0,
            0, 2, 0, 0,
            0, 0, 5, 0,
            0, 0, 0, 1
        );

        auto actualMatrix = vector.toScalingMatrix();
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void test2DVectorToScalingMatrix() {
        auto vector = Vector2D(6, 12);
        auto expectedMatrix = Matrix3D(
            6, 0 , 0,
            0, 12, 0,
            0, 0 , 1
        );

        auto actualMatrix = vector.toScalingMatrix();
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void testCreateAxisBoundRotationMatrices() {
        auto expectedMatrix = "Matrix!(double, 4u, 4u)([1, 0, 0, 0, 0, -1, 1.22461e-16, 0, 0, -1.22461e-16, -1, 0, 0, 0, 0, 1])";
        auto actualMatrix = createXRotationMatrix(PI);
        assertEquals(expectedMatrix, to!string(actualMatrix));

        expectedMatrix = "Matrix!(double, 4u, 4u)([-1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1])";
        actualMatrix = createYRotationMatrix(PI);
        assertEquals(expectedMatrix, to!string(actualMatrix));

        expectedMatrix = "Matrix!(double, 4u, 4u)([-1, -1.22461e-16, 0, 0, 1.22461e-16, -1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 1])";
        actualMatrix = createZRotationMatrix(PI);
        assertEquals(expectedMatrix, to!string(actualMatrix));
    }

    @Test
    public void testCreate4DRotationMatrix() {
        auto expectedMatrix = "Matrix!(double, 4u, 4u)([-1, 0, -1.22461e-16, 0, 0, 1, 0, 0, 1.22461e-16, 0, -1, 0, 0, 0, 0, 1])";

        auto actualMatrix1 = createRotationMatrix(PI, 0, 1, 0);
        assertEquals(expectedMatrix, to!string(actualMatrix1));

        auto actualMatrix2 = createRotationMatrix(PI, Vector3D(0, 1, 0));
        assertEquals(expectedMatrix, to!string(actualMatrix2));

        assertEquals(actualMatrix1, actualMatrix2);
    }

    @Test
    public void testCreate3DRotationMatrix() {
        auto expectedMatrix = "Matrix!(double, 3u, 3u)([-0.989992, -0.14112, 0, 0.14112, -0.989992, 0, 0, 0, 1])";
        auto actualMatrix = createRotationMatrix(3);
        assertEquals(expectedMatrix, to!string(actualMatrix));
    }

    @Test
    public void testCreateLookatMatrix() {
        auto expectedMatrix = "Matrix!(double, 4u, 4u)([0, 0, 1, -0, 0, 1, 0, -1, -1, -0, -0, -0, 0, 0, 0, 1])";
        auto actualMatrix = createLookatMatrix(Vector3D(0, 1, 0), Vector3D(1, 1, 0), UnitVector3D(0, 1, 0));
        assertEquals(expectedMatrix, to!string(actualMatrix));
    }

    @Test
    public void testCreatePerspectiveMatrix() {
        auto expectedMatrix = "Matrix!(double, 4u, 4u)([1, 0, 0, 0, 0, 1, 0, 0, 0, 0, -1.0002, -0.20002, 0, 0, -1, 0])";
        auto actualMatrix = createPerspectiveMatrix(90, 1920 / 1080, 0.1, 1000);
        assertEquals(expectedMatrix, to!string(actualMatrix));
    }

    @Test
    public void testMultiplyMatrixByScalar() {
        auto matrix = Matrix2D(
            1,  4,
            0, -9
        );
        auto expectedMatrix = Matrix2D(
            2,  8,
            0, -18
        );

        auto actualMatrix = matrix * 2;
        assertEquals(expectedMatrix, actualMatrix);

        actualMatrix = 2 * matrix;
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void testTransposeMatrix() {
        auto matrix = Matrix!(double, 2, 3)(
            1, 2, 3,
            4, 5, 6
        );

        auto expectedMatrix = Matrix!(double, 3, 2)(
            1, 4,
            2, 5,
            3, 6
        );

        auto actualMatrix = matrix.transpose();
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void testGetRowVector() {
        auto matrix = Matrix2D(
            3, 5,
            8, 7
        );

        auto expectedVector = Vector2D(3, 5);

        auto actualVector = matrix.getRowVector(0);
        assertEquals(expectedVector, actualVector);
    }

    @Test
    public void testMultiplyMatrixByMatrix() {
        auto matrix1 = Matrix!(double, 2, 3)(
            1, 2, 3,
            4, 5, 6
        );
        auto matrix2 = Matrix!(double, 3, 2)(
            7 , 8,
            9 , 10,
            11, 12
        );
        auto expectedMatrix = Matrix2D(
            58 , 64,
            139, 154
        );

        auto actualMatrix = matrix1 * matrix2;
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void testMatrixAddition() {
        auto matrix1 = Matrix2D(
            1, 2,
            3, 4
        );

        auto matrix2 = Matrix2D(
            5, 6,
            7, 8
        );

        auto expectedMatrix = Matrix2D(
            6 , 8,
            10, 12
        );

        auto actualMatrix = matrix1 + matrix2;
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void testMatrixSubtraction() {
        auto matrix1 = Matrix2D(
            8, 7,
            6, 5
        );

        auto matrix2 = Matrix2D(
            1, 2,
            3, 4
        );

        auto expectedMatrix = Matrix2D(
            7, 5,
            3, 1
        );

        auto actualMatrix = matrix1 - matrix2;
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void testMatrixNegatation() {
        auto matrix = Matrix2D(
            1 , -3,
            -6,  8
        );

        auto expectedMatrix = Matrix2D(
            -1, 3,
            6, -8
        );

        auto actualMatrix = -matrix;
        assertEquals(expectedMatrix, actualMatrix);
    }

    @Test
    public void testAssignIndex() {
        auto actualMatrix = Matrix2D(0);
        auto expectedMatrix = Matrix2D(
            0, 0,
            6, 0
        );

        actualMatrix[2] = 6;
        assertEquals(expectedMatrix, actualMatrix);
    }
}

class QuaternionTest {
    mixin UnitTest;

    @Test
    public void testCreateQuaternion() {
        auto quaternion = QuaternionD();
        assertEquals(QuaternionD(1, 0, 0, 0), quaternion);

        quaternion = QuaternionD(4, 1, 2, 3);
        assertEquals(4, quaternion.w);
        assertEquals(1, quaternion.x);
        assertEquals(2, quaternion.y);
        assertEquals(3, quaternion.z);
    }

    @Test
    public void testMultiplyQuaternion() {
        auto quaternion1 = QuaternionD(1, 2, 3, 4);
        auto quaternion2 = QuaternionD(5, 6, 7, 8);
        auto expectedQuaternion = QuaternionD(-60, 12, 30, 24);

        auto actualQuaternion = quaternion1 * quaternion2;
        assertEquals(expectedQuaternion, actualQuaternion);

        assertTrue(quaternion1 * quaternion2 != quaternion2 * quaternion1);
    }

    @Test
    public void testCreateRotation() {
        auto expectedQuaternion = "Quaternion!double(6.12303e-17, (1, 0, 0))";
        auto actualQuaternion = QuaternionD.createRotation(PI, Vector3D(1, 0, 0));
        assertEquals(expectedQuaternion, actualQuaternion.to!string);
    }

    @Test
    public void testToRotationMatrix() {
        auto quaternion = QuaternionD(6.12303e-17, 1, 0, 0);
        auto actualRotationMatrix = quaternion.toRotationMatrix();
        auto expectedRotationMatrix = "Matrix!(double, 4u, 4u)([1, 0, 0, 0, 0, -1, 1.22461e-16, 0, 0, -1.22461e-16, -1, 0, 0, 0, 0, 1])";
        assertEquals(expectedRotationMatrix, actualRotationMatrix.to!string);
    }

    @Test
    public void testToEulerAngles() {
        auto quaternion = QuaternionD.createRotation(PI, Vector3D(0, 1, 0));
        auto expectedToEulerAngles = Vector3D(0, PI, 0);
        auto actualEulerAngles = quaternion.toEulerAngles();
        assertEquals(expectedToEulerAngles, actualEulerAngles);

        quaternion = QuaternionD.createRotation(PI, Vector3D(1, 0, 0));
        expectedToEulerAngles = Vector3D(0, 0, PI);
        actualEulerAngles = quaternion.toEulerAngles();
        assertEquals(expectedToEulerAngles, actualEulerAngles);
    }
}

class EqualsTest {
    mixin UnitTest;

    @Test
    public void equalsTest() {
        auto inaccurateDouble = 0.9;
        assertFalse(inaccurateDouble == 1);
        assertTrue(equals(inaccurateDouble, 1, 0.1));
        assertFalse(equals(2, 1, 0.1));
    }

}

class RelativeOrientationProcessorTest {
    mixin UnitTest;

    @Test
    public void testUpdate() {
        auto parentEntity = new Entity();
        parentEntity.id = 1;
        parentEntity.addComponent(new OrientationR2Component(1));
        parentEntity.finalize();

        auto entity = new Entity();
        entity.id = 2;
        entity.addComponent!OrientationR2Component;
        entity.addComponent(new RelativeOrientationR2Component(1));
        entity.finalize();
        entity.parent = parentEntity;

        auto processor = new RelativeOrientationProcessor();
        processor.addEntity(entity);

        processor.update();

        assertEquals(2, entity.getFromComponent!OrientationR2Component(c => c.angle));
    }

    @Test
    public void testUpdateWithoutParent() {
        auto entity = new Entity();
        entity.id = 2;
        entity.addComponent!OrientationR2Component;
        entity.addComponent(new RelativeOrientationR2Component(1));
        entity.finalize();

        auto processor = new RelativeOrientationProcessor();
        processor.addEntity(entity);

        processor.update();

        import std.stdio;
        stdout.flush();

        assertEquals(0, entity.getFromComponent!OrientationR2Component(c => c.angle));
    }

    @Test
    public void testUpdateWithParentWithoutOrientation() {
        auto parentEntity = new Entity();
        parentEntity.id = 1;
        parentEntity.finalize();

        auto entity = new Entity();
        entity.id = 2;
        entity.addComponent!OrientationR2Component;
        entity.addComponent(new RelativeOrientationR2Component(1));
        entity.finalize();
        entity.parent = parentEntity;

        auto processor = new RelativeOrientationProcessor();
        processor.addEntity(entity);

        processor.update();

        assertEquals(1, entity.getFromComponent!OrientationR2Component(c => c.angle));
    }

    @Test
    public void testUpdateWithParentWithRelativeOrientationOnly() {
        auto parentEntity = new Entity();
        parentEntity.id = 1;
        parentEntity.addComponent(new RelativeOrientationR2Component(1));
        parentEntity.finalize();

        auto entity = new Entity();
        entity.id = 2;
        entity.addComponent!OrientationR2Component;
        entity.addComponent(new RelativeOrientationR2Component(1));
        entity.finalize();
        entity.parent = parentEntity;

        auto processor = new RelativeOrientationProcessor();
        processor.addEntity(parentEntity);
        processor.addEntity(entity);
        processor.update();

        assertEquals(1, entity.getFromComponent!OrientationR2Component(c => c.angle));
    }

    @Test
    public void testUpdateWithParentWithRelativeOrientation() {
        auto parentEntity = new Entity();
        parentEntity.id = 1;
        parentEntity.addComponent(new OrientationR2Component(2));
        parentEntity.addComponent!RelativeOrientationR2Component;
        parentEntity.finalize();

        auto entity = new Entity();
        entity.id = 2;
        entity.addComponent!OrientationR2Component;
        entity.addComponent(new RelativeOrientationR2Component(1));
        entity.finalize();
        entity.parent = parentEntity;

        auto processor = new RelativeOrientationProcessor();
        processor.addEntity(parentEntity);
        processor.addEntity(entity);
        processor.update();

        assertEquals(3, entity.getFromComponent!OrientationR2Component(c => c.angle));
    }
}
