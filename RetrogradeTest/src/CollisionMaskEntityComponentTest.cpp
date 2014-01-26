#include <gtest/gtest.h>

#include <Engine/EntityComponents/CollisionMaskEntityComponent.h>

TEST(CollisionMaskEntityComponentTest, testSetTroughConstructor) {
	Engine::EntityComponents::CollisionMaskEntityComponent collisionMaskEntityComponent(897);
	EXPECT_EQ(897, collisionMaskEntityComponent.getMask());
}

TEST(CollisionMaskEntityComponentTest, testComponentFamilyType) {
	Engine::EntityComponents::CollisionMaskEntityComponent collisionGroupEntityComponent(0);
	EXPECT_STREQ("CollisionMaskEntityComponent", Engine::EntityComponents::CollisionMaskEntityComponent::componentType().c_str());
	EXPECT_STREQ("CollisionMaskEntityComponent", Engine::EntityComponents::CollisionMaskEntityComponent::familyType().c_str());
	EXPECT_STREQ("CollisionMaskEntityComponent", collisionGroupEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("CollisionMaskEntityComponent", collisionGroupEntityComponent.getFamilyType().c_str());
}