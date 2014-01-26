#include <gtest/gtest.h>

#include <Engine/EntityComponents/CollisionGroupEntityComponent.h>

TEST(CollisionGroupEntityComponentTest, testSetTroughConstructor) {
	Engine::EntityComponents::CollisionGroupEntityComponent collisionGroupEntityComponent(456);
	EXPECT_EQ(456, collisionGroupEntityComponent.getGroup());
}

TEST(CollisionGroupEntityComponentTest, testComponentFamilyType) {
	Engine::EntityComponents::CollisionGroupEntityComponent collisionGroupEntityComponent(0);
	EXPECT_STREQ("CollisionGroupEntityComponent", Engine::EntityComponents::CollisionGroupEntityComponent::componentType().c_str());
	EXPECT_STREQ("CollisionGroupEntityComponent", Engine::EntityComponents::CollisionGroupEntityComponent::familyType().c_str());
	EXPECT_STREQ("CollisionGroupEntityComponent", collisionGroupEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("CollisionGroupEntityComponent", collisionGroupEntityComponent.getFamilyType().c_str());
}