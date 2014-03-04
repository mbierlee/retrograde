#include <gtest/gtest.h>

#include <Engine/EntityComponents/InertiaEntityComponent.h>

#include <vector3d.h>

namespace RetrogradeTest { namespace EntityComponents {

TEST(InertiaEntityComponentTest, testComponentFamilyType) {
	Engine::EntityComponents::InertiaEntityComponent inertiaEntityComponent;
	EXPECT_STREQ("InertiaEntityComponent", Engine::EntityComponents::InertiaEntityComponent::componentType().c_str());
	EXPECT_STREQ("InertiaEntityComponent", Engine::EntityComponents::InertiaEntityComponent::familyType().c_str());
	EXPECT_STREQ("InertiaEntityComponent", inertiaEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("InertiaEntityComponent", inertiaEntityComponent.getFamilyType().c_str());
}

TEST(InertiaEntityComponentTest, testSetTroughConstructor) {
	Engine::EntityComponents::InertiaEntityComponent inertiaEntityComponent(irr::core::vector3df(1.2f, 3.5f, 6.f));
	EXPECT_EQ(irr::core::vector3df(1.2f, 3.5f, 6.f), inertiaEntityComponent.getIntertia());
}

TEST(InertiaEntityComponentTest, testGetSet) {
	Engine::EntityComponents::InertiaEntityComponent inertiaEntityComponent;
	EXPECT_EQ(irr::core::vector3df(0.f), inertiaEntityComponent.getIntertia());
	inertiaEntityComponent.setInertia(irr::core::vector3df(9.34f, 8.44f, 10.f));
	EXPECT_EQ(irr::core::vector3df(9.34f, 8.44f, 10.f), inertiaEntityComponent.getIntertia());
}

}}
