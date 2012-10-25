#include "CameraEntityComponent.h"

#include "Engine/EntityComponents/PositionEntityComponent.h"
#include "Engine/EntityComponents/RotationEntityComponent.h"

Engine::EntityComponents::CameraEntityComponent::CameraEntityComponent( irr::scene::ICameraSceneNode* cameraSceneNode )
	: cameraSceneNode(cameraSceneNode)
{
}

const irr::core::stringc Engine::EntityComponents::CameraEntityComponent::getComponentType() const
{
	return componentType();
}

const irr::core::stringc Engine::EntityComponents::CameraEntityComponent::getFamilyType() const
{
	return familyType();
}

void Engine::EntityComponents::CameraEntityComponent::update( Engine::Framework::IEntity* entity, irr::u32 frameTime, irr::u32 lastFrameTime )
{
	if (cameraSceneNode) {
		auto positionComponent = 
			std::static_pointer_cast<Engine::EntityComponents::PositionEntityComponent>(
			entity->getComponent(Engine::EntityComponents::PositionEntityComponent::familyType()));

		if (positionComponent && positionComponent->getPosition() != cameraSceneNode->getPosition()) {
			cameraSceneNode->setPosition(positionComponent->getPosition());
		}

		auto rotationComponent = 
			std::static_pointer_cast<Engine::EntityComponents::RotationEntityComponent>(
			entity->getComponent(Engine::EntityComponents::RotationEntityComponent::familyType()));

		if (rotationComponent && rotationComponent->getRotation() != cameraSceneNode->getRotation()) {
			cameraSceneNode->setRotation(rotationComponent->getRotation());
		}
	}
}

const irr::core::stringc Engine::EntityComponents::CameraEntityComponent::componentType()
{
	return "CameraEntityComponent";
}

const irr::core::stringc Engine::EntityComponents::CameraEntityComponent::familyType()
{
	return "CameraEntityComponent";
}
