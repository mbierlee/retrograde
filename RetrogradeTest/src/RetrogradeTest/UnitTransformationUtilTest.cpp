#include <Engine/UnitTransformationUtil.h>

#include <gtest/gtest.h>
#include <gmock/gmock.h>

namespace RetrogradeTest {

TEST(UnitTransformationUtilTest, testTransformIrrVector) {
	btScalar xComponent = 2.;
	btScalar yComponent = 3.;
	btScalar zComponent = 4.;

	btVector3 transformedVector = Engine::transformIrrVector(irr::core::vector3df(xComponent, yComponent, zComponent));

	ASSERT_EQ(xComponent, transformedVector.getX());
	ASSERT_EQ(yComponent, transformedVector.getY());
	ASSERT_EQ(zComponent, transformedVector.getZ());
}

TEST(UnitTransformationUtilTest, testTransformBulletVector) {
	btScalar xComponent = 6.;
	btScalar yComponent = 7.;
	btScalar zComponent = 8.;

	irr::core::vector3df transformedVector = Engine::transformBulletVector(btVector3(xComponent, yComponent, zComponent));

	ASSERT_EQ(xComponent, transformedVector.X);
	ASSERT_EQ(yComponent, transformedVector.Y);
	ASSERT_EQ(zComponent, transformedVector.Z);
}

TEST(UnitTransformationUtilTest, testTransformIrrQuarternion) {
	btScalar xComponent = 6.;
	btScalar yComponent = 7.;
	btScalar zComponent = 8.;
	btScalar wComponent = 9.;

	btQuaternion transformedQuarternion = Engine::transformIrrQuaternion(irr::core::quaternion(xComponent, yComponent, zComponent, wComponent));

	ASSERT_EQ(xComponent, transformedQuarternion.getX());
	ASSERT_EQ(yComponent, transformedQuarternion.getY());
	ASSERT_EQ(zComponent, transformedQuarternion.getZ());
	ASSERT_EQ(wComponent, transformedQuarternion.getW());
}

TEST(UnitTransformationUtilTest, testTransformBulletQuarternion) {
	btScalar xComponent = 2.;
	btScalar yComponent = 3.;
	btScalar zComponent = 4.;
	btScalar wComponent = 5.;

	irr::core::quaternion transformedQuarternion = Engine::transformBulletQuaternion(btQuaternion(xComponent, yComponent, zComponent, wComponent));

	ASSERT_EQ(xComponent, transformedQuarternion.X);
	ASSERT_EQ(yComponent, transformedQuarternion.Y);
	ASSERT_EQ(zComponent, transformedQuarternion.Z);
	ASSERT_EQ(wComponent, transformedQuarternion.W);
}

TEST(UnitTransformationUtilTest, testVecRadToDeg) {
	irr::core::vector3df transformedVector = Engine::vecRadToDeg(irr::core::vector3df(0.1f, 0.5f, 1.f));

	ASSERT_NEAR(5.72958f, (float)transformedVector.X, 0.1);
	ASSERT_NEAR(28.64789f, (float)transformedVector.Y, 0.1);
	ASSERT_NEAR(57.29578f, (float)transformedVector.Z, 0.1);
}

TEST(UnitTransformationUtilTest, testVecDegToRad) {
	irr::core::vector3df transformedVector = Engine::vecDegToRad(irr::core::vector3df(30.f, 180.f, 15.f));

	ASSERT_NEAR(0.523598776f, (float)transformedVector.X, 0.1);
	ASSERT_NEAR(3.14159265f, (float)transformedVector.Y, 0.1);
	ASSERT_NEAR(0.261799388f, (float)transformedVector.Z, 0.1);
}

TEST(UnitTransformationUtilTest, testTransformBulletColor) {
	btScalar red = 3.f;
	btScalar green = 5.f;
	btScalar blue = 7.f;

	irr::video::SColorf transformedColor = Engine::transformBulletColor(btVector3(red, green, blue));

	ASSERT_EQ(red, transformedColor.getRed());
	ASSERT_EQ(green, transformedColor.getGreen());
	ASSERT_EQ(blue, transformedColor.getBlue());
}

TEST(UnitTransformationUtilTest, testMakePhysicsToWorldsizeVectorWithSeparateComponents) {
	btScalar x = 2;
	btScalar y = 6;
	btScalar z = 9;

	irr::core::vector3df transformedVector = Engine::makePhysicsToWorldsizeVector(x, y, z);

	ASSERT_EQ(x * Engine::visualWorldSize, transformedVector.X);
	ASSERT_EQ(y * Engine::visualWorldSize, transformedVector.Y);
	ASSERT_EQ(z * Engine::visualWorldSize, transformedVector.Z);
}

TEST(UnitTransformationUtilTest, testMakePhysicsToWorldsizeVectorWithIrrVector) {
	btScalar x = 2;
	btScalar y = 6;
	btScalar z = 9;

	irr::core::vector3df transformedVector = Engine::makePhysicsToWorldsizeVector(irr::core::vector3df(x, y, z));

	ASSERT_EQ(x * Engine::visualWorldSize, transformedVector.X);
	ASSERT_EQ(y * Engine::visualWorldSize, transformedVector.Y);
	ASSERT_EQ(z * Engine::visualWorldSize, transformedVector.Z);
}

TEST(UnitTransformationUtilTest, testMakePhysicsToWorldsizeVectorWithBulletVector) {
	btScalar x = 2;
	btScalar y = 6;
	btScalar z = 9;

	irr::core::vector3df transformedVector = Engine::makePhysicsToWorldsizeVector(btVector3(x, y, z));

	ASSERT_EQ(x * Engine::visualWorldSize, transformedVector.X);
	ASSERT_EQ(y * Engine::visualWorldSize, transformedVector.Y);
	ASSERT_EQ(z * Engine::visualWorldSize, transformedVector.Z);
}

}
