#include <gtest/gtest.h>

#include <Engine/EntityComponents/PositionEntityComponent.h>
#include <vector3d.h>

TEST(PositionEntityComponentTest, testSetTroughConstructor) {
	Engine::EntityComponents::PositionEntityComponent positionComponent(irr::core::vector3df(1.f,2.f,3.f));
	EXPECT_EQ(irr::core::vector3df(1.f, 2.f, 3.f), positionComponent.getPosition());
}

TEST(PositionEntityComponentTest, testSetGet) {
	Engine::EntityComponents::PositionEntityComponent positionComponent;
	EXPECT_EQ(irr::core::vector3df(0.f), positionComponent.getPosition());
	positionComponent.setPosition(irr::core::vector3df(4.5f, 6.8f, 99.31f));
	EXPECT_EQ(irr::core::vector3df(4.5f, 6.8f, 99.31f), positionComponent.getPosition());
}

TEST(PositionEntityComponentTest, testComponentFamilyType) {
	Engine::EntityComponents::PositionEntityComponent positionComponent;
	EXPECT_STREQ("PositionEntityComponent", Engine::EntityComponents::PositionEntityComponent::componentType().c_str());
	EXPECT_STREQ("PositionEntityComponent", Engine::EntityComponents::PositionEntityComponent::familyType().c_str());
	EXPECT_STREQ("PositionEntityComponent", positionComponent.getComponentType().c_str());
	EXPECT_STREQ("PositionEntityComponent", positionComponent.getFamilyType().c_str());
}