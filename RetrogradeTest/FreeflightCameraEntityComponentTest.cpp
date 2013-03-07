#include <gtest/gtest.h>

#include <Engine/EntityComponents/FreeflightCameraEntityComponent.h>

TEST(FreeflightCameraEntityComponentTest, testComponentFamilyType) {
	Engine::EntityComponents::FreeflightCameraEntityComponent freeflightCameraEntityComponent(nullptr);
	EXPECT_STREQ("FreeflightCameraEntityComponent", Engine::EntityComponents::FreeflightCameraEntityComponent::componentType().c_str());
	EXPECT_STREQ("CameraEntityComponent", Engine::EntityComponents::FreeflightCameraEntityComponent::familyType().c_str());
	EXPECT_STREQ("FreeflightCameraEntityComponent", freeflightCameraEntityComponent.getComponentType().c_str());
	EXPECT_STREQ("CameraEntityComponent", freeflightCameraEntityComponent.getFamilyType().c_str());
}