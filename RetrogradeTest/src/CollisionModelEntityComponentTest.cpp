#include <gtest/gtest.h>

#include <Engine/EntityComponents/CollisionModelEntityComponent.h>
#include <Bullet/BulletCollision/CollisionShapes/btSphereShape.h>

TEST(CollisionModelEntityComponentTest, testSetTroughConstructor) {
	auto shape = std::make_shared<btSphereShape>(btScalar(5.));
	Engine::EntityComponents::CollisionModelEntityComponent collisionModelEntityComponent(shape);
	EXPECT_EQ(shape, collisionModelEntityComponent.getCollisionShape());
}

TEST(CollisionModelEntityComponentTest, testComponentFamilyType) {
	auto shape = std::shared_ptr<btSphereShape>();
	Engine::EntityComponents::CollisionModelEntityComponent collisionModelEntityComponent(shape);
	EXPECT_STREQ("CollisionModelEntityComponent", Engine::EntityComponents::CollisionModelEntityComponent::componentType().c_str());
	EXPECT_STREQ("CollisionModelEntityComponent", Engine::EntityComponents::CollisionModelEntityComponent::familyType().c_str());
	EXPECT_STREQ("CollisionModelEntityComponent", collisionModelEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("CollisionModelEntityComponent", collisionModelEntityComponent.getFamilyType().c_str());
}