#include <gtest/gtest.h>

#include <Engine/EntityComponents/HeadRotationEntityComponent.h>
#include <Engine/EntityComponents/RotationEntityComponent.h>
#include <Engine/UnitTransformationUtil.h>
#include <Engine/Entity.h>

#include <quaternion.h>

TEST(HeadRotationEntityComponentTest, testComponentFamilyType) {
	Engine::EntityComponents::HeadRotationEntityComponent headRotationEntityComponent;
	EXPECT_STREQ("HeadRotationEntityComponent", Engine::EntityComponents::HeadRotationEntityComponent::componentType().c_str());
	EXPECT_STREQ("HeadRotationEntityComponent", Engine::EntityComponents::HeadRotationEntityComponent::familyType().c_str());
	EXPECT_STREQ("HeadRotationEntityComponent", headRotationEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("HeadRotationEntityComponent", headRotationEntityComponent.getFamilyType().c_str());
}

TEST(HeadRotationEntityComponentTest, testSetTroughConstructor) {
	Engine::EntityComponents::HeadRotationEntityComponent headRotationEntityComponent(irr::core::quaternion(1.f, 2.f, 3.f, 4.f));
	EXPECT_EQ(irr::core::quaternion(1.f, 2.f, 3.f, 4.f), headRotationEntityComponent.getRotation());
}