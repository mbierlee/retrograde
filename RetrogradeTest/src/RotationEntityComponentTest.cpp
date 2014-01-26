#include <gtest/gtest.h>

#include <Engine/EntityComponents/RotationEntityComponent.h>
#include <vector3d.h>
#include <quaternion.h>

TEST(RotationEntityComponentTest, testSetTroughConstructor) {
	Engine::EntityComponents::RotationEntityComponent rotationEntityComponentEuler(irr::core::vector3df(1.f, 0.733f, 1.2f));
	EXPECT_EQ(irr::core::vector3df(1.f, 0.733f, 1.2f), rotationEntityComponentEuler.getEulerRotation());
	Engine::EntityComponents::RotationEntityComponent rotationEntityComponentQuaternion(irr::core::quaternion(4.f, 6.f, 2.f, 8.f));
	EXPECT_EQ(irr::core::quaternion(4.f, 6.f, 2.f, 8.f), rotationEntityComponentQuaternion.getRotation());
}

TEST(RotationEntityComponentTest, testSetGetQuaternion) {
	Engine::EntityComponents::RotationEntityComponent rotationEntityComponent;
	EXPECT_EQ(irr::core::quaternion(), rotationEntityComponent.getRotation());
	rotationEntityComponent.setRotation(irr::core::quaternion(1.2f, 0.73f, 0.8f));
	EXPECT_EQ(irr::core::quaternion(1.2f, 0.73f, 0.8f), rotationEntityComponent.getRotation());
}

TEST(RotationEntityComponentTest, testSetGetEuler) {
	Engine::EntityComponents::RotationEntityComponent rotationEntityComponent;
	EXPECT_EQ(irr::core::vector3df(), rotationEntityComponent.getEulerRotation());
	rotationEntityComponent.setEulerRotation(irr::core::vector3df(1.f, 0.5f, 1.1f));
	EXPECT_EQ(irr::core::vector3df(1.f, 0.5f, 1.1f), rotationEntityComponent.getEulerRotation());
}

TEST(RotationEntityComponentTest, testComponentFamilyType) {
	Engine::EntityComponents::RotationEntityComponent rotationEntityComponent;
	EXPECT_STREQ("RotationEntityComponent", Engine::EntityComponents::RotationEntityComponent::componentType().c_str());
	EXPECT_STREQ("RotationEntityComponent", Engine::EntityComponents::RotationEntityComponent::familyType().c_str());
	EXPECT_STREQ("RotationEntityComponent", rotationEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("RotationEntityComponent", rotationEntityComponent.getFamilyType().c_str());
}