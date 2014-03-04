#include <gtest/gtest.h>
#include <gmock/gmock.h>

#include <Engine/EntityComponents/CollisionObjectEntityComponent.h>

namespace RetrogradeTest { namespace EntityComponents {

TEST(CollisionObjectEntityComponentTest, testComponentFamilyType) {
	std::shared_ptr<Engine::Framework::IPhysicsService> physicsService;
	Engine::EntityComponents::CollisionObjectEntityComponent collisionObjectEntityComponent(physicsService);
	EXPECT_STREQ("CollisionObjectEntityComponent", Engine::EntityComponents::CollisionObjectEntityComponent::componentType().c_str());
	EXPECT_STREQ("CollisionObjectEntityComponent", Engine::EntityComponents::CollisionObjectEntityComponent::familyType().c_str());
	EXPECT_STREQ("CollisionObjectEntityComponent", collisionObjectEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("CollisionObjectEntityComponent", collisionObjectEntityComponent.getFamilyType().c_str());
}

}}
